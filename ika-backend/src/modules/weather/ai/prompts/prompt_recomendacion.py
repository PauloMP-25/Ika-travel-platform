"""Generador de prompts estructurados con etiquetas XML para el recomendador con Gemini AI.

Regla de oro (DIRCETUR Ica):
Gemini NO calcula nada ni inventa cifras. Recibe los KPIs calculados por el backend
y su única función es estructurar la narrativa oficial turística en formato bilingüe.
Soporta 'narrativa_previa' para garantizar continuidad cronológica a lo largo del día.
"""

from __future__ import annotations


def generar_prompt_recomendacion_turistica(
    *,
    nombre_atractivo: str,
    categoria_pertur: str,
    atractivos_alternativos: list[str] | None = None,
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
    # Variables ampliadas de Ica
    presion_hpa: float | None = None,
    precipitacion_mm: float | None = None,
    temperatura_arena: float | None = None,
    pm10: float | None = None,
    ventana_pico_uv: str | None = None,
    horas_sol: float | None = None,
    altura_ola: float | None = None,
    # Memoria continua
    narrativa_previa: str | None = None,
) -> str:
    """Construye el prompt formal en XML delimitando contexto, condiciones e instrucciones."""
    idioma_nombre = "inglés" if idioma == "en" else "español"
    alertas_str = ", ".join(alertas_activas) if alertas_activas else "Ninguna alerta activa"
    intereses_str = ", ".join(intereses_turista) if intereses_turista else "Turismo general"
    consejos_str = ", ".join(consejos_base) if consejos_base else "Ninguno específico"

    detalles_extra = []
    if temperatura_arena is not None:
        detalles_extra.append(f"- Temperatura superficial de la arena: {temperatura_arena:.1f} °C")
    if ventana_pico_uv:
        detalles_extra.append(f"- Franja horaria de máxima radiación solar: {ventana_pico_uv}")
    if horas_sol is not None:
        detalles_extra.append(f"- Horas estimadas de sol directo: {horas_sol:.1f} h")
    if presion_hpa is not None:
        detalles_extra.append(f"- Presión barométrica: {presion_hpa:.1f} hPa")
    if precipitacion_mm is not None and precipitacion_mm > 0:
        detalles_extra.append(f"- Precipitación acumulada: {precipitacion_mm:.1f} mm")
    if pm10 is not None:
        detalles_extra.append(f"- Calidad del aire (partículas PM10): {pm10:.1f} µg/m³")
    if altura_ola is not None:
        detalles_extra.append(f"- Altura de oleaje en costa: {altura_ola:.2f} m")

    bloque_extras = "\n".join(detalles_extra) if detalles_extra else "- Condiciones estándar del desierto"

    bloque_narrativa_previa = ""
    if narrativa_previa:
        bloque_narrativa_previa = f"""
<narrativa_previa_del_dia>
{narrativa_previa}
</narrativa_previa_del_dia>
"""

    return f"""<rol>Asistente Oficial Inteligente de DIRCETUR Ica, Perú</rol>
<contexto>
Eres el recomendador turístico oficial para la región Ica (balnearios, oasis, desierto, reservas y valles vitivinícolas).
Tu única función es redactar la narrativa turística oficial en {idioma_nombre}, basándote estrictamente en los datos meteorológicos y cálculos ya procesados por el sistema.
</contexto>
{bloque_narrativa_previa}
<datos_atractivo>
- Atractivo principal: {nombre_atractivo}
- Categoría oficial PERTUR: {categoria_pertur}
- Otros lugares registrados en el catálogo de Ica recomendables hoy: {', '.join(atractivos_alternativos) if atractivos_alternativos else 'Oasis de Huacachina, Bodega Tacama, Pueblo de Cachiche, Reserva Nacional de Paracas'}
</datos_atractivo>

<condiciones_meteorologicas>
- Temperatura ambiente: {temperatura:.1f} °C
- Velocidad del viento: {viento:.1f} km/h
- Radiación UV: {uv:.1f}
- Condición del cielo: {condicion_cielo}
- Alertas meteorológicas de seguridad: {alertas_str}
{bloque_extras}
</condiciones_meteorologicas>

<calculos_previos_sistema>
- Score de idoneidad calculado: {score_calculado:.2f} (Nivel: {nivel_calculado})
- Coincidencia con preferencias del turista: {'Sí' if afinidad_preferencias else 'No'}
- Preferencias del turista: {intereses_str}
- Consejos calculados por reglas: {consejos_str}
</calculos_previos_sistema>

<tarea>
Genera la recomendación estructurada para el turista en {idioma_nombre}:
1. 'summary': Resumen cálido y persuasivo invitando a visitar {nombre_atractivo} según el clima actual de Ica.
2. 'climate_justification': Justificación meteorológica detallada que explique cómo las condiciones actuales (temperatura, viento, UV) favorecen la visita, comparándola con los otros atractivos sugeridos.
3. 'clothing': Lista de 2 a 4 prendas recomendadas (si la arena está caliente o el UV es alto, menciona calzado cerrado y protección).
4. 'precautions': Lista de 2 a 4 recomendaciones y precauciones prácticas. DEBES incluir aquí consejos específicos mencionando los otros lugares de alto índice calculados para visitar hoy ({', '.join(atractivos_alternativos[:2]) if atractivos_alternativos else 'Plaza de Armas de Ica, Bodega Tacama'}), explicando en qué momento del día conviene ir según el clima.
5. 'suitability_score': Mantén el valor exacto de {score_calculado:.2f} proveniente del cálculo del sistema.
</tarea>

<restricciones>
1. Responde ÚNICAMENTE en el idioma solicitado: {idioma_nombre}.
2. Jamás inventes cifras meteorológicas ni modifiques el suitability_score de {score_calculado:.2f}.
3. Si hay alertas meteorológicas activas o arena caliente (> 40 °C), las precauciones deben priorizarlas de forma obligatoria.
</restricciones>""".strip()
