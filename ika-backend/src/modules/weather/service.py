"""Lógica de clima, caché (RN-03), alertas y recomendaciones.

* RN-03: ningún dato climático con más de ``CLIMA_VIGENCIA_HORAS`` (6 h) se sirve
  como vigente. ``get_fresh_snapshot`` es el único punto que lo garantiza.
* Para no consultar al proveedor una vez por atractivo, las coordenadas se agrupan
  en celdas de ~11 km (1 decimal): una consulta alimenta a todos los atractivos de la celda.
"""
import asyncio
import logging
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timedelta
from uuid import UUID

from sqlalchemy import and_, delete, desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from src.core.config import configuracion
from src.modules.catalog import repository as catalog_repo
from src.modules.catalog.exceptions import AttractionNotFoundException, InvalidCategoryFilterException
from src.modules.catalog.models import Attraction, Category
from src.modules.weather.ai_recommender import (
    ResultadoRecomendacion,
    detectar_alertas,
    generar_recomendacion,
    nivel_desde_puntaje,
    redactar_con_gemini,
)
from src.modules.weather.exceptions import (
    StaleWeatherDataException,
    WeatherProviderUnavailableException,
)
from src.modules.weather.models import (
    AIRecommendation,
    AlertSeverity,
    WeatherAlert,
    WeatherSnapshot,
)
from src.modules.weather.provider import NOMBRE_FUENTE, DatosClima, obtener_clima
from src.modules.weather.schemas import (
    AIRecommendationResponse,
    ForecastDay,
    ForecastHour,
    RefreshSummary,
    WeatherAlertCreate,
    WeatherCurrentResponse,
    WeatherForecastResponse,
    WeatherSummary,
)
from src.redis_client import cache_guardar_json, cache_obtener_json
from src.shared.utils import utc_ahora

logger = logging.getLogger(__name__)

TTL_PRONOSTICO_SEGUNDOS = 3600
ZONA_REGION = "Ica"
_bloqueos: dict[str, asyncio.Lock] = defaultdict(asyncio.Lock)


# ======================================================================
# Objetivos de consulta (región o atractivo)
# ======================================================================
@dataclass
class _Objetivo:
    attraction_id: UUID | None
    nombre: str
    zona: str
    latitud: float
    longitud: float


def _objetivo_region() -> _Objetivo:
    return _Objetivo(
        attraction_id=None,
        nombre="Región Ica",
        zona=ZONA_REGION,
        latitud=configuracion.CLIMA_LATITUD_REGION,
        longitud=configuracion.CLIMA_LONGITUD_REGION,
    )


def _objetivo_de(atractivo: Attraction) -> _Objetivo:
    return _Objetivo(
        attraction_id=atractivo.id,
        nombre=atractivo.name,
        zona=atractivo.district,
        latitud=atractivo.latitude,
        longitud=atractivo.longitude,
    )


async def _resolver_objetivo(db: AsyncSession, attraction_id: UUID | None) -> _Objetivo:
    if attraction_id is None:
        return _objetivo_region()
    atractivo = await catalog_repo.obtener_atractivo_por_id(db, attraction_id)
    if atractivo is None:
        raise AttractionNotFoundException()
    return _objetivo_de(atractivo)


def _clave_celda(o: _Objetivo) -> tuple[float, float]:
    return round(o.latitud, 1), round(o.longitud, 1)


def _clave_cache(attraction_id: UUID | None) -> str:
    return f"clima:pronostico:{attraction_id or 'region'}"


# ======================================================================
# Pronóstico (caché Redis)
# ======================================================================
def _a_pronostico(o: _Objetivo, datos: DatosClima, ahora: datetime) -> WeatherForecastResponse:
    return WeatherForecastResponse(
        attraction_id=o.attraction_id,
        location=o.nombre,
        generated_at=ahora,
        hourly=[ForecastHour(**vars(h)) for h in datos.horas],
        daily=[ForecastDay(**vars(d)) for d in datos.dias],
    )


async def get_forecast(db: AsyncSession, attraction_id: UUID | None) -> WeatherForecastResponse:
    objetivo = await _resolver_objetivo(db, attraction_id)
    clave = _clave_cache(attraction_id)
    en_cache = await cache_obtener_json(clave)
    if en_cache is not None:
        return WeatherForecastResponse.model_validate(en_cache)
    datos = await obtener_clima(objetivo.latitud, objetivo.longitud)
    respuesta = _a_pronostico(objetivo, datos, utc_ahora())
    await cache_guardar_json(clave, respuesta.model_dump(mode="json"), TTL_PRONOSTICO_SEGUNDOS)
    return respuesta


# ======================================================================
# Snapshots (RN-03)
# ======================================================================
def _limite_vigencia() -> datetime:
    return utc_ahora() - timedelta(hours=configuracion.CLIMA_VIGENCIA_HORAS)


async def _ultimo_snapshot(
    db: AsyncSession, attraction_id: UUID | None, desde: datetime | None = None
) -> WeatherSnapshot | None:
    condicion = (
        WeatherSnapshot.attraction_id.is_(None)
        if attraction_id is None
        else WeatherSnapshot.attraction_id == attraction_id
    )
    consulta = select(WeatherSnapshot).where(condicion)
    if desde is not None:
        consulta = consulta.where(WeatherSnapshot.fetched_at >= desde)
    resultado = await db.execute(consulta.order_by(desc(WeatherSnapshot.fetched_at)).limit(1))
    return resultado.scalar_one_or_none()


async def _actualizar_alertas(
    db: AsyncSession, zona: str, snap: WeatherSnapshot, ahora: datetime
) -> None:
    for alerta in detectar_alertas(
        temperatura=snap.temperature,
        uv=snap.uv_index,
        viento=snap.wind_speed,
        precipitacion=snap.precipitation,
    ):
        existente = (
            await db.execute(
                select(WeatherAlert).where(
                    WeatherAlert.zone == zona,
                    WeatherAlert.code == alerta.code,
                    WeatherAlert.ends_at >= ahora,
                )
            )
        ).scalars().first()
        fin = ahora + timedelta(hours=configuracion.CLIMA_VIGENCIA_HORAS)
        if existente:  # se extiende en vez de duplicar
            existente.message = alerta.message
            existente.severity = AlertSeverity(alerta.severity)
            existente.ends_at = fin
        else:
            db.add(
                WeatherAlert(
                    zone=zona, code=alerta.code, severity=AlertSeverity(alerta.severity),
                    message=alerta.message, starts_at=ahora, ends_at=fin,
                )
            )


async def _refrescar_objetivos(
    db: AsyncSession, objetivos: list[_Objetivo]
) -> tuple[list[WeatherSnapshot], int]:
    """Crea snapshots nuevos. Devuelve (snapshots, objetivos_fallidos)."""
    celdas: dict[tuple[float, float], list[_Objetivo]] = {}
    for o in objetivos:
        celdas.setdefault(_clave_celda(o), []).append(o)

    snapshots: list[WeatherSnapshot] = []
    fallidos = 0
    ultimo_error: WeatherProviderUnavailableException | None = None
    for grupo in celdas.values():
        base = grupo[0]
        try:
            datos = await obtener_clima(base.latitud, base.longitud)
        except WeatherProviderUnavailableException as exc:
            fallidos += len(grupo)
            ultimo_error = exc
            continue
        ahora = utc_ahora()
        actual = datos.actual
        for o in grupo:
            snap = WeatherSnapshot(
                attraction_id=o.attraction_id,
                temperature=actual.temperature,
                uv_index=actual.uv_index,
                wind_speed=actual.wind_speed,
                humidity=actual.humidity,
                precipitation=actual.precipitation,
                condition=actual.condition,
                fetched_at=ahora,
                source=NOMBRE_FUENTE,
            )
            db.add(snap)
            snapshots.append(snap)
            await _actualizar_alertas(db, o.zona, snap, ahora)
            await cache_guardar_json(
                _clave_cache(o.attraction_id),
                _a_pronostico(o, datos, ahora).model_dump(mode="json"),
                TTL_PRONOSTICO_SEGUNDOS,
            )
    if not snapshots:
        await db.rollback()
        raise ultimo_error or WeatherProviderUnavailableException()
    await db.commit()
    return snapshots, fallidos


async def get_fresh_snapshot(db: AsyncSession, attraction_id: UUID | None = None) -> WeatherSnapshot:
    """RN-03: devuelve un snapshot de ≤ 6 h; si está vencido refresca de forma síncrona."""
    limite = _limite_vigencia()
    ultimo = await _ultimo_snapshot(db, attraction_id)
    if ultimo is not None and ultimo.fetched_at >= limite:
        return ultimo

    objetivo = await _resolver_objetivo(db, attraction_id)
    async with _bloqueos[str(attraction_id or "region")]:
        # Otro request pudo refrescar mientras esperábamos el bloqueo.
        reciente = await _ultimo_snapshot(db, attraction_id, desde=_limite_vigencia())
        if reciente is not None:
            return reciente
        try:
            creados, _ = await _refrescar_objetivos(db, [objetivo])
        except WeatherProviderUnavailableException as exc:
            if ultimo is not None:
                raise StaleWeatherDataException(
                    f"El último dato climático tiene más de {configuracion.CLIMA_VIGENCIA_HORAS} h "
                    "y no se pudo actualizar."
                ) from exc
            raise
        return creados[0]


async def get_current_weather(db: AsyncSession, attraction_id: UUID | None) -> WeatherCurrentResponse:
    objetivo = await _resolver_objetivo(db, attraction_id)
    snap = await get_fresh_snapshot(db, attraction_id)
    respuesta = WeatherCurrentResponse.model_validate(snap)
    respuesta.location = objetivo.nombre
    return respuesta


# ======================================================================
# Recomendaciones
# ======================================================================
def _calcular(atractivo: Attraction, snap: WeatherSnapshot) -> ResultadoRecomendacion:
    return generar_recomendacion(
        nombre_atractivo=atractivo.name,
        slugs_categorias=[c.slug for c in atractivo.categories],
        temperatura=snap.temperature,
        uv=snap.uv_index,
        viento=snap.wind_speed,
        precipitacion=snap.precipitation,
    )


async def _recomendacion_existente(
    db: AsyncSession, attraction_id: UUID, snapshot_id: UUID
) -> AIRecommendation | None:
    resultado = await db.execute(
        select(AIRecommendation)
        .where(
            AIRecommendation.attraction_id == attraction_id,
            AIRecommendation.weather_snapshot_id == snapshot_id,
        )
        .order_by(desc(AIRecommendation.generated_at))
        .limit(1)
    )
    return resultado.scalar_one_or_none()


async def _obtener_o_generar(
    db: AsyncSession, atractivo: Attraction, snap: WeatherSnapshot, *, usar_gemini: bool
) -> AIRecommendation:
    """Una recomendación por (atractivo, snapshot): evita recalcular y duplicar filas."""
    existente = await _recomendacion_existente(db, atractivo.id, snap.id)
    if existente is not None:
        return existente
    resultado = _calcular(atractivo, snap)
    texto, fuente = resultado.texto, "reglas"
    if usar_gemini:
        redactado = await redactar_con_gemini(
            nombre_atractivo=atractivo.name, resultado=resultado, temperatura=snap.temperature,
            uv=snap.uv_index, viento=snap.wind_speed, condicion=snap.condition,
        )
        if redactado:
            texto, fuente = redactado, "gemini"
    rec = AIRecommendation(
        attraction_id=atractivo.id, weather_snapshot_id=snap.id,
        recommendation_text=texto, score=resultado.score, text_source=fuente,
        generated_at=utc_ahora(),
    )
    db.add(rec)
    await db.flush()
    return rec


def _a_respuesta(atractivo: Attraction, snap: WeatherSnapshot, rec: AIRecommendation) -> AIRecommendationResponse:
    return AIRecommendationResponse(
        attraction_id=atractivo.id,
        attraction_name=atractivo.name,
        recommendation_text=rec.recommendation_text,
        score=rec.score,
        level=nivel_desde_puntaje(rec.score),
        text_source=rec.text_source,
        generated_at=rec.generated_at,
        weather=WeatherSummary(
            temperature=snap.temperature, uv_index=snap.uv_index, wind_speed=snap.wind_speed,
            condition=snap.condition, fetched_at=snap.fetched_at,
        ),
    )


async def get_recommendation_for_attraction(
    db: AsyncSession, attraction_id: UUID
) -> AIRecommendationResponse:
    atractivo = await catalog_repo.obtener_atractivo_por_id(db, attraction_id)
    if atractivo is None:
        raise AttractionNotFoundException()
    snap = await get_fresh_snapshot(db, attraction_id)
    rec = await _obtener_o_generar(db, atractivo, snap, usar_gemini=bool(configuracion.GEMINI_API_KEY))
    await db.commit()
    return _a_respuesta(atractivo, snap, rec)


async def _atractivos_activos(db: AsyncSession, category_slug: str | None = None) -> list[Attraction]:
    consulta = (
        select(Attraction)
        .where(Attraction.is_active.is_(True))
        .options(selectinload(Attraction.categories))
        .order_by(Attraction.name)
    )
    if category_slug:
        consulta = consulta.where(Attraction.categories.any(Category.slug == category_slug))
    return list((await db.execute(consulta)).scalars().all())


async def _snapshots_vigentes(
    db: AsyncSession, ids: list[UUID]
) -> dict[UUID, WeatherSnapshot]:
    if not ids:
        return {}
    ultimo = (
        select(WeatherSnapshot.attraction_id, func.max(WeatherSnapshot.fetched_at).label("maximo"))
        .where(WeatherSnapshot.attraction_id.in_(ids), WeatherSnapshot.fetched_at >= _limite_vigencia())
        .group_by(WeatherSnapshot.attraction_id)
        .subquery()
    )
    filas = await db.execute(
        select(WeatherSnapshot).join(
            ultimo,
            and_(
                WeatherSnapshot.attraction_id == ultimo.c.attraction_id,
                WeatherSnapshot.fetched_at == ultimo.c.maximo,
            ),
        )
    )
    return {s.attraction_id: s for s in filas.scalars().all() if s.attraction_id}


async def get_ranked_recommendations(
    db: AsyncSession, *, category_slug: str | None, limit: int
) -> list[AIRecommendationResponse]:
    """Atractivos ordenados por conveniencia climática ahora mismo."""
    if category_slug and await catalog_repo.obtener_categoria_por_slug(db, category_slug) is None:
        raise InvalidCategoryFilterException(f"La categoría '{category_slug}' no existe.")
    atractivos = await _atractivos_activos(db, category_slug)
    if not atractivos:
        return []

    snaps = await _snapshots_vigentes(db, [a.id for a in atractivos])
    faltantes = [a for a in atractivos if a.id not in snaps]
    if faltantes:
        # RN-03: refresco síncrono de lo vencido; si falla todo, se propaga la excepción.
        creados, _ = await _refrescar_objetivos(db, [_objetivo_de(a) for a in faltantes])
        snaps.update({s.attraction_id: s for s in creados if s.attraction_id})

    respuestas = []
    for atractivo in atractivos:
        snap = snaps.get(atractivo.id)
        if snap is None:
            continue
        rec = await _obtener_o_generar(db, atractivo, snap, usar_gemini=False)
        respuestas.append(_a_respuesta(atractivo, snap, rec))
    await db.commit()
    respuestas.sort(key=lambda r: (-r.score, r.attraction_name))
    return respuestas[:limit]


# ======================================================================
# Alertas
# ======================================================================
_ORDEN_SEVERIDAD = {AlertSeverity.high: 0, AlertSeverity.medium: 1, AlertSeverity.low: 2}


async def get_active_alerts(db: AsyncSession, zone: str | None = None) -> list[WeatherAlert]:
    ahora = utc_ahora()
    consulta = select(WeatherAlert).where(WeatherAlert.starts_at <= ahora, WeatherAlert.ends_at >= ahora)
    if zone:
        consulta = consulta.where(func.lower(WeatherAlert.zone) == zone.strip().lower())
    alertas = list((await db.execute(consulta)).scalars().all())
    return sorted(alertas, key=lambda a: (_ORDEN_SEVERIDAD[a.severity], a.ends_at))


async def create_manual_alert(db: AsyncSession, data: WeatherAlertCreate) -> WeatherAlert:
    ahora = utc_ahora()
    alerta = WeatherAlert(
        zone=data.zone.strip(), code="manual", severity=data.severity, message=data.message,
        starts_at=ahora, ends_at=ahora + timedelta(hours=data.duration_hours),
    )
    db.add(alerta)
    await db.commit()
    await db.refresh(alerta)
    return alerta


# ======================================================================
# Refresco masivo (Celery Beat / endpoint admin)
# ======================================================================
async def refresh_weather_cache(db: AsyncSession) -> RefreshSummary:
    """Actualiza clima de la región y de todos los atractivos activos y precalcula recomendaciones."""
    atractivos = await _atractivos_activos(db)
    objetivos = [_objetivo_region(), *[_objetivo_de(a) for a in atractivos]]
    snapshots, fallidos = await _refrescar_objetivos(db, objetivos)
    por_atractivo = {s.attraction_id: s for s in snapshots if s.attraction_id}

    pendientes = [(a, por_atractivo[a.id]) for a in atractivos if a.id in por_atractivo]
    resultados = [(a, s, _calcular(a, s)) for a, s in pendientes]

    textos: list[str | None] = [None] * len(resultados)
    if configuracion.GEMINI_API_KEY and resultados:
        semaforo = asyncio.Semaphore(3)  # respeta límites de la API de Gemini

        async def _redactar(a: Attraction, s: WeatherSnapshot, r: ResultadoRecomendacion) -> str | None:
            async with semaforo:
                return await redactar_con_gemini(
                    nombre_atractivo=a.name, resultado=r, temperatura=s.temperature,
                    uv=s.uv_index, viento=s.wind_speed, condicion=s.condition,
                )

        textos = list(await asyncio.gather(*(_redactar(a, s, r) for a, s, r in resultados)))

    con_gemini = 0
    for (a, s, r), texto in zip(resultados, textos):
        if texto:
            con_gemini += 1
        db.add(
            AIRecommendation(
                attraction_id=a.id, weather_snapshot_id=s.id,
                recommendation_text=texto or r.texto, score=r.score,
                text_source="gemini" if texto else "reglas", generated_at=utc_ahora(),
            )
        )
    await db.commit()
    logger.info("Clima actualizado: %s snapshots, %s fallidos", len(snapshots), fallidos)
    return RefreshSummary(
        snapshots_creados=len(snapshots), zonas_fallidas=fallidos,
        recomendaciones_generadas=len(resultados), texto_con_gemini=con_gemini,
    )


async def purge_old_weather_data(db: AsyncSession, days: int = 14) -> dict[str, int]:
    """Elimina snapshots (y sus recomendaciones por CASCADE) y alertas vencidas antiguas."""
    corte = utc_ahora() - timedelta(days=days)
    snaps = await db.execute(delete(WeatherSnapshot).where(WeatherSnapshot.fetched_at < corte))
    alertas = await db.execute(delete(WeatherAlert).where(WeatherAlert.ends_at < corte))
    await db.commit()
    return {"snapshots_eliminados": snaps.rowcount or 0, "alertas_eliminadas": alertas.rowcount or 0}
