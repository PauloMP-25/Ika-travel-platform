"""Capa de orquestación del módulo weather.

Implementa el Patrón Aggregator: dispara consultas concurrentes a los
proveedores configurados, colecta las respuestas válidas (tolerando fallos
parciales), y calcula un consenso/promedio para entregar un dato altamente
preciso y resiliente.
"""

import asyncio
import logging
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from src.core.config import configuracion
from src.modules.catalog.models import Attraction
from src.modules.weather import ai_recommender, provider
from src.modules.weather.adapters import (
    AdaptadorClimaBase,
    AdaptadorOpenMeteo,
    AdaptadorOpenWeatherMap,
    AdaptadorWeatherAPI,
)
from src.modules.weather.constants import DESTINOS_ICA, normalizar_nombre_destino
from src.modules.weather.exceptions import (
    AtractivoSinClimaException,
    DatosClimaDesactualizadosException,
    DestinoNoEncontradoException,
    TodosLosProveedoresFallaronException,
)
from src.modules.weather.models import (
    AIRecommendation,
    SeveridadAlerta,
    WeatherAlert,
    WeatherSnapshot,
)
from src.modules.weather.schemas import (
    ClimaActual,
    ClimaActualResponse,
    PronosticoResponse,
    RecomendacionResponse,
)
from src.redis_client import cache_guardar_json, cache_obtener_json

logger = logging.getLogger(__name__)


class AgregadorClima:
    """Orquestador que implementa el Patrón Aggregator.

    Recibe una lista de adaptadores por inyección de dependencias,
    los llama en paralelo y promedia los resultados válidos.
    """

    def __init__(self, adaptadores: list[AdaptadorClimaBase]):
        self.adaptadores = adaptadores

    async def obtener_consenso(self, latitud: float, longitud: float) -> ClimaActual:
        """Lanza todas las peticiones en paralelo y devuelve el promedio."""
        tareas = [
            adaptador.obtener_clima_actual(latitud, longitud)
            for adaptador in self.adaptadores
        ]

        # return_exceptions=True permite que si una API falla, las otras sigan
        resultados = await asyncio.gather(*tareas, return_exceptions=True)

        exitosos: list[ClimaActual] = []
        nombres_fallidos: list[str] = []
        nombres_exitosos: list[str] = []

        for i, resultado in enumerate(resultados):
            nombre_api = self.adaptadores[i].nombre_proveedor
            if isinstance(resultado, Exception):
                logger.warning("Fallo en proveedor %s: %s", nombre_api, resultado)
                nombres_fallidos.append(nombre_api)
            else:
                exitosos.append(resultado)
                nombres_exitosos.append(nombre_api)

        if not exitosos:
            raise TodosLosProveedoresFallaronException([])

        logger.info(
            "Consenso de clima obtenido de %d proveedor(es): %s",
            len(exitosos),
            ", ".join(nombres_exitosos),
        )
        return self._promediar_resultados(exitosos, nombres_exitosos)

    def _promediar_resultados(
        self, resultados: list[ClimaActual], nombres: list[str]
    ) -> ClimaActual:
        n = len(resultados)

        def prom(lista: list[float]) -> float:
            return sum(lista) / n

        # Para las ráfagas que pueden ser None en algunas APIs, filtramos los Nones
        rafagas_validas = [r.rafagas_viento for r in resultados if r.rafagas_viento is not None]
        promedio_rafagas = sum(rafagas_validas) / len(rafagas_validas) if rafagas_validas else None

        # Para el UV, filtramos los 0.0 que vienen de OWM (no tienen el dato, no es UV real de 0)
        uvs_validos = [r.indice_uv for r in resultados if r.indice_uv > 0]
        promedio_uv = sum(uvs_validos) / len(uvs_validos) if uvs_validos else 0.0

        return ClimaActual(
            temperatura_actual=round(prom([r.temperatura_actual for r in resultados]), 1),
            sensacion_termica=round(prom([r.sensacion_termica for r in resultados]), 1),
            probabilidad_precipitacion=round(
                prom([r.probabilidad_precipitacion for r in resultados]), 1
            ),
            humedad=round(prom([r.humedad for r in resultados]), 1),
            velocidad_viento=round(prom([r.velocidad_viento for r in resultados]), 1),
            rafagas_viento=round(promedio_rafagas, 1) if promedio_rafagas is not None else None,
            indice_uv=round(promedio_uv, 1),
            descripcion_clima=resultados[0].descripcion_clima,
            visibilidad=round(prom([r.visibilidad for r in resultados]), 1),
            hora_amanecer=resultados[0].hora_amanecer,
            hora_atardecer=resultados[0].hora_atardecer,
            fecha_hora_pronostico=datetime.now(tz=timezone.utc),
            origen_api=f"Consenso ({n} APIs): {', '.join(nombres)}",
        )


# Instancia global — los adaptadores se inyectan aquí (Inversión de Dependencias)
agregador_clima = AgregadorClima(
    adaptadores=[
        AdaptadorOpenWeatherMap(),
        AdaptadorWeatherAPI(),
        AdaptadorOpenMeteo(),
    ]
)


def resolver_coordenadas_destino(destino: str) -> tuple[float, float]:
    """Convierte el nombre de un destino turístico a sus coordenadas."""
    clave = normalizar_nombre_destino(destino)
    if clave not in DESTINOS_ICA:
        raise DestinoNoEncontradoException(destino)
    return DESTINOS_ICA[clave]


# ======================================================================
# Ubicaciones y caché (RN-03)
# ======================================================================
@dataclass(frozen=True)
class Ubicacion:
    """Punto del que se consulta el clima: atractivo, destino conocido o región."""

    clave: str  # clave de caché
    nombre: str
    latitud: float
    longitud: float
    atractivo_id: UUID | None = None


def _vigencia() -> timedelta:
    return timedelta(hours=configuracion.CLIMA_VIGENCIA_HORAS)


def ubicacion_region() -> Ubicacion:
    return Ubicacion(
        clave="region",
        nombre="Ica",
        latitud=configuracion.CLIMA_LATITUD_REGION,
        longitud=configuracion.CLIMA_LONGITUD_REGION,
    )


def ubicacion_de_atractivo(atractivo: Attraction) -> Ubicacion:
    return Ubicacion(
        clave=str(atractivo.id),
        nombre=atractivo.name,
        latitud=atractivo.latitude,
        longitud=atractivo.longitude,
        atractivo_id=atractivo.id,
    )


async def resolver_ubicacion(
    db: AsyncSession, *, atractivo_id: UUID | None = None, destino: str | None = None
) -> Ubicacion:
    """Prioridad: `attraction_id` > `destino` > región por defecto."""
    if atractivo_id is not None:
        resultado = await db.execute(
            select(Attraction).where(Attraction.id == atractivo_id, Attraction.is_active.is_(True))
        )
        atractivo = resultado.scalar_one_or_none()
        if atractivo is None:
            raise AtractivoSinClimaException()
        return ubicacion_de_atractivo(atractivo)
    if destino:
        latitud, longitud = resolver_coordenadas_destino(destino)
        return Ubicacion(
            clave=f"destino:{normalizar_nombre_destino(destino)}",
            nombre=destino,
            latitud=latitud,
            longitud=longitud,
        )
    return ubicacion_region()


def _clave_cache(prefijo: str, ubicacion: Ubicacion) -> str:
    return f"weather:{prefijo}:{ubicacion.clave}"


async def _ultimo_snapshot_vigente(
    db: AsyncSession, ubicacion: Ubicacion
) -> WeatherSnapshot | None:
    """Último snapshot guardado hace menos de `CLIMA_VIGENCIA_HORAS` (RN-03)."""
    limite = datetime.now(tz=timezone.utc) - _vigencia()
    consulta = select(WeatherSnapshot).where(WeatherSnapshot.creado_en >= limite)
    if ubicacion.atractivo_id is not None:
        consulta = consulta.where(WeatherSnapshot.atractivo_id == ubicacion.atractivo_id)
    else:
        consulta = consulta.where(
            WeatherSnapshot.atractivo_id.is_(None), WeatherSnapshot.destino == ubicacion.nombre
        )
    resultado = await db.execute(consulta.order_by(WeatherSnapshot.creado_en.desc()).limit(1))
    return resultado.scalar_one_or_none()


def _a_respuesta(snapshot: WeatherSnapshot, *, en_cache: bool) -> ClimaActualResponse:
    respuesta = ClimaActualResponse.model_validate(snapshot)
    return respuesta.model_copy(update={"is_cached": en_cache})


async def _guardar_en_redis(ubicacion: Ubicacion, respuesta: ClimaActualResponse) -> None:
    await cache_guardar_json(
        _clave_cache("current", ubicacion),
        respuesta.model_dump(mode="json"),
        int(_vigencia().total_seconds()),
    )


async def get_fresh_snapshot(
    db: AsyncSession,
    ubicacion: Ubicacion,
    *,
    forzar_refresco: bool = False,
    agregador: AgregadorClima | None = None,
) -> ClimaActualResponse:
    """RN-03: nunca devuelve un dato de clima con más de 6 horas.

    Cache-aside: Redis -> último snapshot vigente de BD -> refresco contra los
    proveedores. Si el refresco falla no se sirve información vencida: se lanza
    `DatosClimaDesactualizadosException` (HTTP 503). La regla vive solo aquí.
    """
    if not forzar_refresco:
        en_redis = await cache_obtener_json(_clave_cache("current", ubicacion))
        if en_redis is not None:
            try:
                return ClimaActualResponse(**{**en_redis, "is_cached": True})
            except ValueError:
                logger.warning("Entrada de caché inválida para %s; se ignora.", ubicacion.clave)

        snapshot = await _ultimo_snapshot_vigente(db, ubicacion)
        if snapshot is not None:
            respuesta = _a_respuesta(snapshot, en_cache=True)
            await _guardar_en_redis(ubicacion, respuesta)
            return respuesta

    agregador = agregador or agregador_clima
    try:
        clima = await agregador.obtener_consenso(ubicacion.latitud, ubicacion.longitud)
    except TodosLosProveedoresFallaronException as exc:
        raise DatosClimaDesactualizadosException() from exc

    snapshot = WeatherSnapshot(
        destino=ubicacion.nombre, atractivo_id=ubicacion.atractivo_id, **clima.model_dump()
    )
    db.add(snapshot)
    await db.commit()
    await db.refresh(snapshot)
    respuesta = _a_respuesta(snapshot, en_cache=False)
    await _guardar_en_redis(ubicacion, respuesta)
    return respuesta


async def obtener_clima_actual(
    db: AsyncSession, *, atractivo_id: UUID | None = None, destino: str | None = None
) -> ClimaActualResponse:
    ubicacion = await resolver_ubicacion(db, atractivo_id=atractivo_id, destino=destino)
    return await get_fresh_snapshot(db, ubicacion)


# ======================================================================
# Pronóstico
# ======================================================================
TTL_PRONOSTICO_SEGUNDOS = 3 * 60 * 60


async def obtener_pronostico(
    db: AsyncSession,
    *,
    atractivo_id: UUID | None = None,
    destino: str | None = None,
    dias: int = 3,
) -> PronosticoResponse:
    ubicacion = await resolver_ubicacion(db, atractivo_id=atractivo_id, destino=destino)
    clave = _clave_cache("forecast", ubicacion)
    en_redis = await cache_obtener_json(clave)
    if en_redis is not None:
        completo = PronosticoResponse(**en_redis)
    else:
        datos = await provider.obtener_clima(ubicacion.latitud, ubicacion.longitud)
        completo = PronosticoResponse(
            destino=ubicacion.nombre,
            atractivo_id=ubicacion.atractivo_id,
            horas=[vars(h) for h in datos.horas],
            dias=[vars(d) for d in datos.dias],
        )
        await cache_guardar_json(clave, completo.model_dump(mode="json"), TTL_PRONOSTICO_SEGUNDOS)
    return completo.model_copy(update={"dias": completo.dias[:dias]})


# ======================================================================
# Recomendaciones y alertas
# ======================================================================
async def _atractivos_activos(db: AsyncSession) -> list[Attraction]:
    resultado = await db.execute(
        select(Attraction).where(Attraction.is_active.is_(True)).options(selectinload(Attraction.categories))
    )
    return list(resultado.scalars().unique().all())


def _recomendar(
    atractivo: Attraction, clima: ClimaActualResponse, preferencias: list[str] | None = None
) -> ai_recommender.ResultadoRecomendacion:
    return ai_recommender.generar_recomendacion(
        nombre_atractivo=atractivo.name,
        slugs_categorias=[c.slug for c in atractivo.categories],
        temperatura=clima.temperatura_actual,
        uv=clima.indice_uv,
        viento=clima.velocidad_viento,
        precipitacion=clima.probabilidad_precipitacion / 100.0 * 3.0,
        preferencias_usuario=preferencias,
    )


def _a_recomendacion_response(
    atractivo: Attraction, resultado: ai_recommender.ResultadoRecomendacion, texto: str | None = None
) -> RecomendacionResponse:
    return RecomendacionResponse(
        atractivo_id=atractivo.id,
        atractivo_nombre=atractivo.name,
        score=resultado.score,
        nivel=resultado.nivel,
        recommendation_text=texto or resultado.texto,
        consejos=resultado.consejos,
        generated_at=datetime.now(tz=timezone.utc),
    )


async def listar_recomendaciones(
    db: AsyncSession, preferencias_usuario: list[str] | None = None
) -> list[RecomendacionResponse]:
    """Atractivos activos ordenados por `score` descendente (modulado por preferencias de Ica)."""
    recomendaciones: list[RecomendacionResponse] = []
    for atractivo in await _atractivos_activos(db):
        clima = await get_fresh_snapshot(db, ubicacion_de_atractivo(atractivo))
        recomendaciones.append(
            _a_recomendacion_response(
                atractivo, _recomendar(atractivo, clima, preferencias=preferencias_usuario)
            )
        )
    return sorted(recomendaciones, key=lambda r: r.score, reverse=True)


async def recomendacion_del_dia(
    db: AsyncSession, preferencias_usuario: list[str] | None = None, idioma: str = "es"
) -> RecomendacionResponse | None:
    """Top 1; redactado por Gemini con personalización y fallback determinista."""
    ranking = await listar_recomendaciones(db, preferencias_usuario=preferencias_usuario)
    if not ranking:
        return None
    mejor = ranking[0]
    atractivo = next(a for a in await _atractivos_activos(db) if a.id == mejor.atractivo_id)
    clima = await get_fresh_snapshot(db, ubicacion_de_atractivo(atractivo))
    resultado = _recomendar(atractivo, clima, preferencias=preferencias_usuario)
    texto = await ai_recommender.redactar_con_gemini(
        nombre_atractivo=atractivo.name,
        resultado=resultado,
        temperatura=clima.temperatura_actual,
        uv=clima.indice_uv,
        viento=clima.velocidad_viento,
        condicion=clima.descripcion_clima,
        preferencias_usuario=preferencias_usuario,
        idioma=idioma,
    )
    return _a_recomendacion_response(atractivo, resultado, texto)


async def listar_alertas_activas(db: AsyncSession) -> list[WeatherAlert]:
    ahora = datetime.now(tz=timezone.utc)
    resultado = await db.execute(
        select(WeatherAlert).where(WeatherAlert.ends_at > ahora).order_by(WeatherAlert.starts_at.desc())
    )
    return list(resultado.scalars().all())


async def regenerar_alertas_region(db: AsyncSession, clima: ClimaActualResponse) -> int:
    """Reemplaza las alertas activas de la región según el clima actual."""
    region = ubicacion_region().nombre
    await db.execute(delete(WeatherAlert).where(WeatherAlert.zone == region))
    ahora = datetime.now(tz=timezone.utc)
    detectadas = ai_recommender.detectar_alertas(
        temperatura=clima.temperatura_actual,
        uv=clima.indice_uv,
        viento=clima.velocidad_viento,
        precipitacion=clima.probabilidad_precipitacion / 100.0 * 3.0,
    )
    for alerta in detectadas:
        db.add(
            WeatherAlert(
                zone=region,
                code=alerta.code,
                severity=SeveridadAlerta(alerta.severity),
                message=alerta.message,
                starts_at=ahora,
                ends_at=ahora + _vigencia(),
            )
        )
    await db.commit()
    return len(detectadas)


async def refrescar_todo(db: AsyncSession) -> dict[str, int]:
    """Tarea de Celery Beat: refresca clima, alertas y recomendaciones persistidas."""
    clima_region = await get_fresh_snapshot(db, ubicacion_region(), forzar_refresco=True)
    alertas = await regenerar_alertas_region(db, clima_region)

    generadas = 0
    for atractivo in await _atractivos_activos(db):
        clima = await get_fresh_snapshot(db, ubicacion_de_atractivo(atractivo), forzar_refresco=True)
        resultado = _recomendar(atractivo, clima)
        texto = await ai_recommender.redactar_con_gemini(
            nombre_atractivo=atractivo.name,
            resultado=resultado,
            temperatura=clima.temperatura_actual,
            uv=clima.indice_uv,
            viento=clima.velocidad_viento,
            condicion=clima.descripcion_clima,
        )
        snapshot_id = (
            await db.execute(
                select(WeatherSnapshot.id)
                .where(WeatherSnapshot.atractivo_id == atractivo.id)
                .order_by(WeatherSnapshot.creado_en.desc())
                .limit(1)
            )
        ).scalar_one()
        db.add(
            AIRecommendation(
                atractivo_id=atractivo.id,
                weather_snapshot_id=snapshot_id,
                recommendation_text=texto or resultado.texto,
                score=resultado.score,
                nivel=resultado.nivel,
            )
        )
        generadas += 1
    await db.commit()
    return {"alertas": alertas, "recomendaciones": generadas}


async def purgar_antiguos(db: AsyncSession, *, dias: int = 7) -> int:
    """Elimina snapshots viejos (las recomendaciones asociadas caen por CASCADE) y alertas vencidas."""
    limite = datetime.now(tz=timezone.utc) - timedelta(days=dias)
    resultado = await db.execute(delete(WeatherSnapshot).where(WeatherSnapshot.creado_en < limite))
    await db.execute(delete(WeatherAlert).where(WeatherAlert.ends_at < limite))
    await db.commit()
    return resultado.rowcount or 0

