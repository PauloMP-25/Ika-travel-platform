"""Reglas de negocio puras, scoring meteorológico y detección de alertas de Ica.

Todo este código es determinista y sin I/O, garantizando evaluación < 150 ms.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class PerfilActividad:
    nombre: str
    codigo_categoria: str  # mapea con CategoriaTuristicaIca
    palabras_clave: tuple[str, ...]
    sensibilidad: float  # 0–1
    temp_ideal: tuple[float, float]
    viento_ideal: float
    viento_maximo: float
    uv_ideal: float
    sensible_lluvia: bool


PERFILES: tuple[PerfilActividad, ...] = (
    PerfilActividad(
        "aventura en desierto",
        "aventura_desierto",
        ("sandboarding", "aventura", "buggy", "tubular", "duna", "huacachina", "canon", "cañon"),
        0.90, (18, 32), 20, 40, 7, True,
    ),
    PerfilActividad(
        "naturaleza y biodiversidad marina",
        "naturaleza_marina",
        ("naturaleza", "paracas", "reserva", "ballestas", "islas", "laguna", "oasis", "marina"),
        0.80, (17, 30), 25, 45, 7, True,
    ),
    PerfilActividad(
        "visita cultural y mística",
        "cultura_mistica",
        ("cultural", "museo", "historia", "cachiche", "brujas", "luren", "catedral", "santuario"),
        0.40, (15, 34), 35, 60, 9, False,
    ),
    PerfilActividad(
        "enoturismo y gastronomía",
        "enoturismo_gastronomia",
        ("vino", "pisco", "bodega", "tacama", "queirolo", "catador", "vitivinicola", "gastronomia"),
        0.50, (16, 32), 30, 50, 8, False,
    ),
    PerfilActividad(
        "arqueología y misterio",
        "arqueologia_misterio",
        ("lineas", "nazca", "geoglifos", "arqueologico", "acueductos", "palpa", "cahuachi"),
        0.70, (16, 33), 25, 45, 8, True,
    ),
)

_PERFIL_GENERAL = PerfilActividad(
    "turismo general", "general", (), 0.50, (16, 30), 25, 50, 8, True
)


def seleccionar_perfil(slugs_categorias: list[str], nombre_atractivo: str) -> PerfilActividad:
    nombre_normalizado = nombre_atractivo.lower()
    slugs_normalizados = [s.lower() for s in slugs_categorias]

    for perfil in PERFILES:
        for palabra in perfil.palabras_clave:
            if palabra in nombre_normalizado or any(palabra in s for s in slugs_normalizados):
                return perfil
    return _PERFIL_GENERAL


def _puntaje_en_rango(valor: float, min_ideal: float, max_ideal: float) -> float:
    if min_ideal <= valor <= max_ideal:
        return 1.0
    margen = 8.0
    distancia = min_ideal - valor if valor < min_ideal else valor - max_ideal
    return max(0.0, 1.0 - (distancia / margen))


def _puntaje_descendente(valor: float, optimo: float, limite: float) -> float:
    if valor <= optimo:
        return 1.0
    if valor >= limite:
        return 0.0
    return (limite - valor) / (limite - optimo)


def nivel_desde_puntaje(score: float) -> str:
    if score >= 0.85:
        return "excelente"
    if score >= 0.70:
        return "bueno"
    if score >= 0.50:
        return "regular"
    return "no_recomendado"


def evaluar_factores(
    *,
    temperatura: float,
    uv: float,
    viento: float,
    precipitacion: float,
    perfil: PerfilActividad,
    preferencias_usuario: list[str] | None = None,
) -> tuple[float, dict[str, float], list[str], float]:
    p_temp = _puntaje_en_rango(temperatura, perfil.temp_ideal[0], perfil.temp_ideal[1])
    p_viento = _puntaje_descendente(viento, perfil.viento_ideal, perfil.viento_maximo)
    p_uv = _puntaje_descendente(uv, perfil.uv_ideal, max(perfil.uv_ideal + 5.0, 12.0))
    p_lluvia = max(0.0, 1.0 - precipitacion / 2.0) if perfil.sensible_lluvia else 1.0

    factores = {
        "temperatura": round(p_temp, 2),
        "viento": round(p_viento, 2),
        "uv": round(p_uv, 2),
        "lluvia": round(p_lluvia, 2),
    }
    pesos = {
        "temperatura": 0.30,
        "viento": 0.30,
        "uv": 0.20,
        "lluvia": 0.20 if perfil.sensible_lluvia else 0.05,
    }
    total_pesos = sum(pesos.values())
    ponderado = sum(factores[k] * pesos[k] for k in factores) / total_pesos
    criticos = [factores["temperatura"], factores["viento"]]
    if perfil.sensible_lluvia:
        criticos.append(factores["lluvia"])
    combinado = min(ponderado, 0.5 * ponderado + 0.5 * min(criticos))
    sensibilidad_efectiva = min(1.0, perfil.sensibilidad * 1.25)
    score_base = 1.0 - sensibilidad_efectiva * (1.0 - combinado)

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
