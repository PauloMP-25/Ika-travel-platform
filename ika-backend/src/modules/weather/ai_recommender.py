"""Motor de recomendación basado en clima y preferencias del turista.

Dos capas:

1. **Scoring por reglas (puro, determinista, sin red ni BD):** cruza temperatura,
   viento, UV y precipitación con el *perfil* de la actividad (aventura en desierto,
   cultural, gastronómica, naturaleza marina, arqueología) y las preferencias del
   turista (RF-01 / OE4), devolviendo un puntaje 0–1 con su explicación.
2. **Redacción con Gemini (opcional):** si ``GEMINI_API_KEY`` está configurada, la IA
   generativa redacta el mensaje al turista a partir de los datos reales y sus intereses.
   El puntaje NUNCA lo decide la IA generativa; si Gemini falla se usa el texto por plantilla.
"""
import logging
from dataclasses import dataclass, field

import httpx

from src.core.config import configuracion

logger = logging.getLogger(__name__)


# ======================================================================
# Perfiles de actividad oficiales de la Región Ica (PERTUR / PROMPERÚ)
# ======================================================================
@dataclass(frozen=True)
class PerfilActividad:
    nombre: str
    codigo_categoria: str  # mapea con CategoriaTuristicaIca
    palabras_clave: tuple[str, ...]  # coinciden con slugs de categoría o nombre del atractivo
    sensibilidad: float  # 0–1: cuánto influye el clima en la experiencia
    temp_ideal: tuple[float, float]  # °C
    viento_ideal: float  # km/h hasta los que no molesta
    viento_maximo: float  # km/h a partir de los cuales es inviable
    uv_ideal: float
    sensible_lluvia: bool


PERFILES: tuple[PerfilActividad, ...] = (
    PerfilActividad(
        "aventura en desierto",
        "aventura_desierto",
        ("sandboarding", "aventura", "buggy", "tubular", "duna", "huacachina", "canon", "cañon"),
        0.90, (18, 32), 20, 40, 7, True
    ),
    PerfilActividad(
        "naturaleza y biodiversidad marina",
        "naturaleza_marina",
        ("naturaleza", "paracas", "reserva", "ballestas", "islas", "laguna", "oasis", "marina"),
        0.80, (17, 30), 25, 45, 7, True
    ),
    PerfilActividad(
        "visita cultural y mística",
        "cultura_mistica",
        ("cultural", "museo", "historia", "cachiche", "brujas", "luren", "catedral", "santuario"),
        0.40, (15, 34), 35, 60, 9, False
    ),
    PerfilActividad(
        "enoturismo y gastronomía",
        "enoturismo_gastronomia",
        ("gastronom", "vitivinic", "bodega", "pisco", "vino", "tacama", "catador", "lagar"),
        0.30, (15, 35), 40, 70, 10, False
    ),
    PerfilActividad(
        "arqueología y enigmas",
        "arqueologia_enigmas",
        ("arqueolog", "nasca", "nazca", "palpa", "geoglifo", "cahuachi", "cantalloc", "sobrevuelo"),
        0.75, (16, 32), 20, 40, 8, True
    ),
)
PERFIL_GENERAL = PerfilActividad(
    "actividad turística general", "general", (), 0.60, (17, 32), 25, 45, 7, True
)


def seleccionar_perfil(slugs_categorias: list[str], nombre_atractivo: str) -> PerfilActividad:
    """Elige el perfil más sensible al clima entre los que coincidan (criterio prudente)."""
    texto = " ".join([*slugs_categorias, nombre_atractivo.lower()])
    coincidencias = [p for p in PERFILES if any(k in texto for k in p.palabras_clave)]
    return max(coincidencias, key=lambda p: p.sensibilidad) if coincidencias else PERFIL_GENERAL


# ======================================================================
# Scoring (funciones puras)
# ======================================================================
def _puntaje_en_rango(valor: float, minimo: float, maximo: float, tolerancia: float = 10.0) -> float:
    if minimo <= valor <= maximo:
        return 1.0
    distancia = (minimo - valor) if valor < minimo else (valor - maximo)
    return max(0.0, 1.0 - distancia / tolerancia)


def _puntaje_descendente(valor: float, ideal: float, maximo: float) -> float:
    if valor <= ideal:
        return 1.0
    if valor >= maximo:
        return 0.0
    return 1.0 - (valor - ideal) / (maximo - ideal)


@dataclass
class ResultadoRecomendacion:
    score: float
    nivel: str  # excelente | bueno | regular | no_recomendado
    texto: str
    factores: dict[str, float] = field(default_factory=dict)
    consejos: list[str] = field(default_factory=list)
    perfil: str = ""
    afinidad_preferencia: float = 0.0


def nivel_desde_puntaje(score: float) -> str:
    if score >= 0.85:
        return "excelente"
    if score >= 0.65:
        return "bueno"
    if score >= 0.40:
        return "regular"
    return "no_recomendado"


def _evaluar_factores(
    *, temperatura: float, uv: float, viento: float, precipitacion: float, perfil: PerfilActividad,
    preferencias_usuario: list[str] | None = None
) -> tuple[float, dict[str, float], list[str], float]:
    p_temp = _puntaje_en_rango(temperatura, perfil.temp_ideal[0], perfil.temp_ideal[1])
    p_viento = _puntaje_descendente(viento, perfil.viento_ideal, perfil.viento_maximo)
    p_uv = _puntaje_descendente(uv, perfil.uv_ideal, max(perfil.uv_ideal + 5.0, 12.0))
    p_lluvia = max(0.0, 1.0 - precipitacion / 2.0) if perfil.sensible_lluvia else 1.0

    factores = {"temperatura": round(p_temp, 2), "viento": round(p_viento, 2),
                "uv": round(p_uv, 2), "lluvia": round(p_lluvia, 2)}
    pesos = {"temperatura": 0.30, "viento": 0.30, "uv": 0.20, "lluvia": 0.20 if perfil.sensible_lluvia else 0.05}
    total_pesos = sum(pesos.values())
    ponderado = sum(factores[k] * pesos[k] for k in factores) / total_pesos
    criticos = [factores["temperatura"], factores["viento"]]
    if perfil.sensible_lluvia:
        criticos.append(factores["lluvia"])
    combinado = min(ponderado, 0.5 * ponderado + 0.5 * min(criticos))
    sensibilidad_efectiva = min(1.0, perfil.sensibilidad * 1.25)
    score_base = 1.0 - sensibilidad_efectiva * (1.0 - combinado)

    # Modulador de Personalización (RF-01 / OE4 / HE4):
    # Si el usuario tiene registradas preferencias de Ica y este atractivo coincide con alguna,
    # recibe una bonificación de afinidad (+15% en el ranking, acotado a 1.0).
    afinidad = 0.0
    if preferencias_usuario:
        coincide = (
            perfil.codigo_categoria in preferencias_usuario
            or any(pref in perfil.palabras_clave for pref in preferencias_usuario)
        )
        if coincide:
            afinidad = 0.15
            score_final = min(1.0, score_base + afinidad)
        else:
            score_final = score_base
    else:
        score_final = score_base

    consejos: list[str] = []
    if uv >= 8:
        consejos.append("Usa protector solar y sombrero: radiación UV alta.")
    if viento >= 30 and perfil.sensibilidad >= 0.7:
        consejos.append("Viento fuerte: lleva lentes para protegerte de la arena.")
    if temperatura >= 32:
        consejos.append("Calor intenso: mantente bien hidratado.")
    elif temperatura <= 15:
        consejos.append("Temperatura baja: lleva abrigo ligero.")
    if precipitacion >= 1.0 and perfil.sensible_lluvia:
        consejos.append("Precipitación prevista: considera actividades bajo techo.")

    return max(0.0, min(1.0, round(score_final, 2))), factores, consejos, afinidad


_ENCABEZADOS = {
    "excelente": "Condiciones excelentes para visitar",
    "bueno": "Buen momento para disfrutar de",
    "regular": "Condiciones moderadas en",
    "no_recomendado": "No se recomienda realizar visitas en este momento a",
}


def _describir_viento(kmh: float) -> str:
    if kmh < 15:
        return "viento suave"
    if kmh < 30:
        return "viento moderado"
    if kmh < 45:
        return "viento fuerte"
    return "viento muy fuerte"


def _describir_uv(indice: float) -> str:
    if indice < 3:
        return "UV bajo"
    if indice < 6:
        return "UV moderado"
    if indice < 8:
        return "UV alto"
    if indice < 11:
        return "UV muy alto"
    return "UV extremo"


def generar_recomendacion(
    *,
    nombre_atractivo: str,
    slugs_categorias: list[str],
    temperatura: float,
    uv: float,
    viento: float,
    precipitacion: float = 0.0,
    preferencias_usuario: list[str] | None = None,
) -> ResultadoRecomendacion:
    perfil = seleccionar_perfil(slugs_categorias, nombre_atractivo)
    score, factores, consejos, afinidad = _evaluar_factores(
        temperatura=temperatura,
        uv=uv,
        viento=viento,
        precipitacion=precipitacion,
        perfil=perfil,
        preferencias_usuario=preferencias_usuario,
    )
    nivel = nivel_desde_puntaje(score)
    encabezado = _ENCABEZADOS[nivel]
    sujeto = f"{encabezado} {nombre_atractivo}" if nivel != "no_recomendado" else f"{encabezado}: {nombre_atractivo}"
    detalle = f"{temperatura:.0f} °C, {_describir_viento(viento)} ({viento:.0f} km/h), {_describir_uv(uv)} ({uv:.0f})"
    texto = f"{sujeto}. Condiciones actuales: {detalle}."
    if afinidad > 0:
        texto += " (Recomendado según tus preferencias de viaje en Ica)."
    if consejos:
        texto += " " + " ".join(consejos)
    return ResultadoRecomendacion(
        score=score,
        nivel=nivel,
        texto=texto[:900],
        factores=factores,
        consejos=consejos,
        perfil=perfil.nombre,
        afinidad_preferencia=afinidad,
    )


# ======================================================================
# Alertas automáticas (funciones puras)
# ======================================================================
@dataclass(frozen=True)
class AlertaDetectada:
    code: str
    severity: str  # low | medium | high
    message: str


def detectar_alertas(
    *, temperatura: float, uv: float, viento: float, precipitacion: float
) -> list[AlertaDetectada]:
    alertas: list[AlertaDetectada] = []
    if viento >= 60:
        alertas.append(AlertaDetectada("viento_fuerte", "high", f"Vientos muy fuertes ({viento:.0f} km/h): evita dunas y zonas abiertas del desierto."))
    elif viento >= 40:
        alertas.append(AlertaDetectada("viento_fuerte", "medium", f"Vientos fuertes ({viento:.0f} km/h): posible arena en suspensión en zonas desérticas."))
    if uv >= 11:
        alertas.append(AlertaDetectada("uv_extremo", "high", f"Radiación UV extrema ({uv:.0f}): protégete y evita la exposición prolongada."))
    if temperatura >= 42:
        alertas.append(AlertaDetectada("calor_extremo", "high", f"Calor extremo ({temperatura:.0f} °C): riesgo de golpe de calor."))
    elif temperatura >= 38:
        alertas.append(AlertaDetectada("calor_extremo", "medium", f"Calor intenso ({temperatura:.0f} °C): hidrátate y evita las horas centrales."))
    if temperatura <= 5:
        alertas.append(AlertaDetectada("frio_intenso", "medium", f"Frío intenso ({temperatura:.0f} °C): lleva abrigo, sobre todo en la noche."))
    if precipitacion >= 8:
        alertas.append(AlertaDetectada("lluvia_intensa", "high", f"Lluvia intensa ({precipitacion:.1f} mm/h): riesgo en quebradas y caminos."))
    elif precipitacion >= 2.5:
        alertas.append(AlertaDetectada("lluvia_intensa", "medium", f"Lluvia moderada ({precipitacion:.1f} mm/h): precaución en caminos y quebradas."))
    return alertas


# ======================================================================
# Redacción opcional con Gemini
# ======================================================================
async def redactar_con_gemini(
    *,
    nombre_atractivo: str,
    resultado: ResultadoRecomendacion,
    temperatura: float,
    uv: float,
    viento: float,
    condicion: str,
    preferencias_usuario: list[str] | None = None,
    idioma: str = "es",
) -> str | None:
    """Devuelve un texto redactado por Gemini o ``None`` si no está configurado / falla."""
    if not configuracion.GEMINI_API_KEY:
        return None
    
    intereses_str = f"Intereses del turista: {', '.join(preferencias_usuario)}." if preferencias_usuario else ""
    idioma_str = "en inglés" if idioma == "en" else "en español"

    prompt = (
        f"Eres el asistente turístico oficial de DIRCETUR Ica, Perú. Redacta {idioma_str}, en máximo 2 frases "
        "(220 caracteres), una recomendación amable y personalizada para un visitante. Usa SOLO estos datos, "
        "no inventes nada.\n"
        f"Atractivo: {nombre_atractivo}\nNivel: {resultado.nivel} (puntaje {resultado.score})\n"
        f"Clima: {temperatura:.0f} °C, viento {viento:.0f} km/h, UV {uv:.0f}, {condicion}\n"
        f"{intereses_str}\n"
        f"Consejos base: {' '.join(resultado.consejos) or 'ninguno'}"
    )
    url = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        f"{configuracion.GEMINI_MODELO}:generateContent"
    )
    try:
        async with httpx.AsyncClient(timeout=configuracion.GEMINI_TIMEOUT_SEGUNDOS) as cliente:
            respuesta = await cliente.post(
                url,
                headers={"x-goog-api-key": configuracion.GEMINI_API_KEY},
                json={
                    "contents": [{"parts": [{"text": prompt}]}],
                    "generationConfig": {"temperature": 0.4, "maxOutputTokens": 200},
                },
            )
            respuesta.raise_for_status()
            texto = respuesta.json()["candidates"][0]["content"]["parts"][0]["text"].strip()
    except (httpx.HTTPError, KeyError, IndexError, TypeError, ValueError) as exc:
        logger.warning("Gemini no disponible; se usa el texto por reglas: %s", exc)
        return None
    return texto[:500] if texto else None
