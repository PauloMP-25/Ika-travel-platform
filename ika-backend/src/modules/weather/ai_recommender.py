"""Motor de recomendación basado en clima.

Dos capas:

1. **Scoring por reglas (puro, determinista, sin red ni BD):** cruza temperatura,
   viento, UV y precipitación con el *perfil* de la actividad (aventura en desierto,
   cultural, gastronómica, etc.) y devuelve un puntaje 0–1 con su explicación.
2. **Redacción con Gemini (opcional):** si ``GEMINI_API_KEY`` está configurada, la IA
   generativa redacta el mensaje al turista a partir de los datos reales. El puntaje
   NUNCA lo decide la IA generativa; si Gemini falla se usa el texto por plantilla.
"""
import logging
from dataclasses import dataclass, field

import httpx

from src.core.config import configuracion

logger = logging.getLogger(__name__)


# ======================================================================
# Perfiles de actividad
# ======================================================================
@dataclass(frozen=True)
class PerfilActividad:
    nombre: str
    palabras_clave: tuple[str, ...]  # coinciden con slugs de categoría o nombre del atractivo
    sensibilidad: float  # 0–1: cuánto influye el clima en la experiencia
    temp_ideal: tuple[float, float]  # °C
    viento_ideal: float  # km/h hasta los que no molesta
    viento_maximo: float  # km/h a partir de los cuales es inviable
    uv_ideal: float
    sensible_lluvia: bool


PERFILES: tuple[PerfilActividad, ...] = (
    PerfilActividad("aventura en desierto", ("sandboarding", "aventura", "buggy", "tubular", "duna"),
                    0.90, (18, 32), 20, 40, 7, True),
    PerfilActividad("naturaleza al aire libre", ("naturaleza", "paracas", "reserva", "laguna", "oasis", "canon", "cañon"),
                    0.80, (17, 30), 25, 45, 7, True),
    PerfilActividad("visita cultural", ("cultural", "museo", "historia", "arqueolog", "nasca", "nazca"),
                    0.40, (15, 34), 35, 60, 9, False),
    PerfilActividad("experiencia gastronómica", ("gastronom", "vitivinic", "bodega", "pisco", "vino"),
                    0.30, (15, 35), 40, 70, 10, False),
)
PERFIL_GENERAL = PerfilActividad("actividad turística", (), 0.60, (17, 32), 25, 45, 7, True)


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


def nivel_desde_puntaje(score: float) -> str:
    if score >= 0.8:
        return "excelente"
    if score >= 0.6:
        return "bueno"
    if score >= 0.4:
        return "regular"
    return "no_recomendado"


def evaluar_condiciones(
    *,
    temperatura: float,
    uv: float,
    viento: float,
    precipitacion: float,
    perfil: PerfilActividad,
) -> tuple[float, dict[str, float], list[str]]:
    """Devuelve (score 0–1, puntaje por factor, consejos)."""
    factores = {
        "temperatura": _puntaje_en_rango(temperatura, *perfil.temp_ideal),
        "viento": _puntaje_descendente(viento, perfil.viento_ideal, perfil.viento_maximo),
        # El UV alto se mitiga con protección: nunca hunde el puntaje por completo.
        "uv": 0.35 + 0.65 * _puntaje_descendente(uv, perfil.uv_ideal, 12.0),
        "lluvia": _puntaje_descendente(precipitacion, 0.1, 3.0),
    }
    pesos = {"temperatura": 0.30, "viento": 0.30, "uv": 0.20, "lluvia": 0.20 if perfil.sensible_lluvia else 0.05}
    total_pesos = sum(pesos.values())
    ponderado = sum(factores[k] * pesos[k] for k in factores) / total_pesos
    # Un factor crítico muy malo (p. ej. viento por encima del máximo) no puede
    # compensarse con los demás: el peor factor crítico limita el resultado.
    criticos = [factores["temperatura"], factores["viento"]]
    if perfil.sensible_lluvia:
        criticos.append(factores["lluvia"])
    combinado = min(ponderado, 0.5 * ponderado + 0.5 * min(criticos))
    # Actividades poco sensibles al clima (museos, bodegas) se acercan a 1.0
    sensibilidad_efectiva = min(1.0, perfil.sensibilidad * 1.25)
    score = 1.0 - sensibilidad_efectiva * (1.0 - combinado)

    consejos: list[str] = []
    if uv >= 8:
        consejos.append("Usa protector solar, gorra y lentes.")
    if viento > perfil.viento_ideal and perfil.sensibilidad >= 0.7:
        consejos.append("El viento puede levantar arena: lleva lentes y cubre tu rostro.")
    if temperatura > perfil.temp_ideal[1]:
        consejos.append("Hidrátate bien y evita las horas de más calor.")
    if temperatura < perfil.temp_ideal[0]:
        consejos.append("Lleva una chaqueta: la temperatura es baja para esta actividad.")
    if precipitacion >= 0.2:
        consejos.append("Hay precipitación: considera reprogramar o llevar impermeable.")
    return round(max(0.0, min(1.0, score)), 2), {k: round(v, 2) for k, v in factores.items()}, consejos


def _describir_viento(viento: float) -> str:
    if viento < 12:
        return "viento suave"
    if viento < 25:
        return "viento moderado"
    if viento < 40:
        return "viento fuerte"
    return "viento muy fuerte"


def _describir_uv(uv: float) -> str:
    if uv < 3:
        return "UV bajo"
    if uv < 6:
        return "UV moderado"
    if uv < 8:
        return "UV alto"
    if uv < 11:
        return "UV muy alto"
    return "UV extremo"


_ENCABEZADOS = {
    "excelente": "Excelente momento para",
    "bueno": "Buen momento para",
    "regular": "Condiciones regulares para",
    "no_recomendado": "No se recomienda ahora",
}


def generar_recomendacion(
    *,
    nombre_atractivo: str,
    slugs_categorias: list[str],
    temperatura: float,
    uv: float,
    viento: float,
    precipitacion: float,
) -> ResultadoRecomendacion:
    """Lógica pura (testeable sin BD): clima + atractivo -> recomendación."""
    perfil = seleccionar_perfil(slugs_categorias, nombre_atractivo)
    score, factores, consejos = evaluar_condiciones(
        temperatura=temperatura, uv=uv, viento=viento, precipitacion=precipitacion, perfil=perfil
    )
    nivel = nivel_desde_puntaje(score)
    encabezado = _ENCABEZADOS[nivel]
    sujeto = f"{encabezado} {nombre_atractivo}" if nivel != "no_recomendado" else f"{encabezado}: {nombre_atractivo}"
    detalle = f"{temperatura:.0f} °C, {_describir_viento(viento)} ({viento:.0f} km/h), {_describir_uv(uv)} ({uv:.0f})"
    texto = f"{sujeto}. Condiciones actuales: {detalle}."
    if consejos:
        texto += " " + " ".join(consejos)
    return ResultadoRecomendacion(
        score=score, nivel=nivel, texto=texto[:900], factores=factores, consejos=consejos, perfil=perfil.nombre
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
    *, nombre_atractivo: str, resultado: ResultadoRecomendacion, temperatura: float,
    uv: float, viento: float, condicion: str,
) -> str | None:
    """Devuelve un texto redactado por Gemini o ``None`` si no está configurado / falla."""
    if not configuracion.GEMINI_API_KEY:
        return None
    prompt = (
        "Eres un asistente turístico de Ica, Perú. Redacta en español, en máximo 2 frases "
        "(220 caracteres), una recomendación amable para un turista. Usa SOLO estos datos, "
        "no inventes nada.\n"
        f"Atractivo: {nombre_atractivo}\nNivel: {resultado.nivel} (puntaje {resultado.score})\n"
        f"Clima: {temperatura:.0f} °C, viento {viento:.0f} km/h, UV {uv:.0f}, {condicion}\n"
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
