"""Generador de prompts estructurados con etiquetas XML para el recomendador con Gemini AI.

Regla de oro (DIRCETUR Ica):
Gemini NO calcula nada ni inventa cifras. Recibe los KPIs calculados por el backend
y su única función es estructurar la narrativa oficial turística en formato bilingüe.
"""

from __future__ import annotations


def generar_prompt_recomendacion_turistica(
    *,
    nombre_atractivo: str,
    categoria_pertur: str,
    temperatura: float,
    viento: float,
    uv: float,
    condicion_cielo: str,
    score_calculado: float,
    nivel_calculado: str,
    afinidad_preferencias: bool,
    alertas_activas: list[str],
    consejos_base: list[str],
    intereses_turista: list[str] | None = None,
    idioma: str = "es",
) -> str:
    """Construye el prompt formal en XML delimitando contexto, condiciones e instrucciones."""
    idioma_nombre = "inglés" if idioma == "en" else "español"
    alertas_str = ", ".join(alertas_activas) if alertas_activas else "Ninguna alerta activa"
    intereses_str = ", ".join(intereses_turista) if intereses_turista else "Turismo general"
    consejos_str = ", ".join(consejos_base) if consejos_base else "Ninguno específico"

    return f"""<rol>Asistente Oficial Inteligente de DIRCETUR Ica, Perú</rol>
<contexto>
Eres el recomendador turístico oficial para la región Ica (balnearios, oasis, desierto, reservas y valles vitivinícolas).
Tu única función es redactar la narrativa turística oficial en {idioma_nombre}, basándote estrictamente en los datos meteorológicos y cálculos ya procesados por el sistema.
</contexto>

<datos_atractivo>
- Atractivo: {nombre_atractivo}
- Categoría oficial PERTUR: {categoria_pertur}
</datos_atractivo>

<condiciones_meteorologicas>
- Temperatura: {temperatura:.1f} °C
- Velocidad del viento: {viento:.1f} km/h
- Radiación UV: {uv:.1f}
- Condición del cielo: {condicion_cielo}
- Alertas meteorológicas de seguridad: {alertas_str}
</condiciones_meteorologicas>

<calculos_previos_sistema>
- Score de idoneidad calculado: {score_calculado:.2f} (Nivel: {nivel_calculado})
- Coincidencia con preferencias del turista: {'Sí' if afinidad_preferencias else 'No'}
- Preferencias del turista: {intereses_str}
- Consejos calculados por reglas: {consejos_str}
</calculos_previos_sistema>

<tarea>
Genera la recomendación estructurada para el turista en {idioma_nombre}:
1. 'summary': Resumen cálido y atractivo invitando a la visita (o recomendando cautela si el nivel es bajo o hay alertas). Máximo 2 oraciones, 220 caracteres.
2. 'climate_justification': Justificación basada en la temperatura, viento y radiación UV actuales.
3. 'clothing': Lista de 2 a 4 prendas o elementos recomendados para esta actividad y clima en Ica.
4. 'precautions': Lista de 1 a 4 precauciones prioritarias (protección solar UV, viento con arena o hidratación).
5. 'suitability_score': Mantén el valor exacto de {score_calculado:.2f} proveniente del cálculo del sistema.
</tarea>

<restricciones>
1. Responde ÚNICAMENTE en el idioma solicitado: {idioma_nombre}.
2. Jamás inventes cifras meteorológicas ni modifiques el suitability_score de {score_calculado:.2f}.
3. Si hay alertas meteorológicas activas, las precauciones deben priorizarlas de forma clara y obligatoria.
</restricciones>""".strip()
