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

    lugares_alt = ', '.join(atractivos_alternativos) if atractivos_alternativos else 'Oasis de Huacachina, Bodega Tacama, Pueblo de Cachiche, Reserva Nacional de Paracas'
    lugares_top2 = ', '.join(atractivos_alternativos[:2]) if atractivos_alternativos else 'Plaza de Armas de Ica, Bodega Tacama'

    if nivel_calculado == "no_recomendado":
        bloque_tarea = f"""<instruccion_prioritaria_seguridad>
ATENCIÓN CRÍTICA: El dictamen oficial del sistema para {nombre_atractivo} es NO_RECOMENDADO (Score: {score_calculado:.2f}/1.00, Nivel: no_recomendado).
Bajo NINGUNA circunstancia debes elogiar la visita ni invitar a ir hoy. Tu deber como asistente oficial de DIRCETUR Ica es proteger al turista, justificar el riesgo meteorológico de manera transparente y orientar hacia alternativas seguras.
</instruccion_prioritaria_seguridad>

<tarea>
Genera la recomendación estructurada para el turista en {idioma_nombre}:
1. 'summary': Advertencia oficial clara, empática y preventiva de DIRCETUR Ica desaconsejando la visita a {nombre_atractivo} en este momento debido a las condiciones adversas identificadas ({alertas_str}).
2. 'climate_justification': Justificación meteorológica rigurosa que explique con claridad POR QUÉ NO ES SEGURO O PROPICIO acudir a {nombre_atractivo} hoy (ej. vientos fuertes, oleaje anómalo, calor extremo o alertas activas). Sugiere explícitamente postergar la visita o dirigirse a atractivos alternativos más seguros ({lugares_alt}).
3. 'clothing': Vestimenta de protección adecuada para resguardarse de las condiciones adversas reportadas.
4. 'precautions': Lista de 2 a 4 precauciones estrictas de seguridad (respetar directivas de capitanía/autoridades, no exponerse a zonas de peligro) y sugerencias directas de alternativas seguras en Ica ({lugares_top2}).
5. 'suitability_score': Mantén el valor exacto de {score_calculado:.2f} proveniente del cálculo del sistema.
</tarea>"""
    elif nivel_calculado == "regular":
        bloque_tarea = f"""<tarea>
El sistema ha evaluado condiciones MODERADAS/REGULARES para visitar {nombre_atractivo} (Score: {score_calculado:.2f}/1.00, Nivel: regular).
Genera la recomendación estructurada para el turista en {idioma_nombre}:
1. 'summary': Recomendación con precaución moderada para visitar {nombre_atractivo}, indicando que la visita es factible pero requiere precauciones específicas.
2. 'climate_justification': Justificación meteorológica objetiva que señale factores favorables y factores que exigen precaución (viento moderado, radiación UV o calor), comparándola con otras opciones ({lugares_top2}).
3. 'clothing': Lista de 2 a 4 prendas recomendadas para adaptarse a la variabilidad del clima.
4. 'precautions': Lista de 2 a 4 recomendaciones y precauciones prácticas, indicando las mejores franjas horarias para el recorrido.
5. 'suitability_score': Mantén el valor exacto de {score_calculado:.2f} proveniente del cálculo del sistema.
</tarea>"""
    else:
        bloque_tarea = f"""<tarea>
El sistema ha determinado condiciones FAVORABLES para visitar {nombre_atractivo} (Score: {score_calculado:.2f}/1.00, Nivel: {nivel_calculado}).
Genera la recomendación estructurada para el turista en {idioma_nombre}:
1. 'summary': Resumen cálido y persuasivo invitando a visitar {nombre_atractivo} según el clima actual favorable de Ica.
2. 'climate_justification': Justificación meteorológica detallada que explique cómo las condiciones actuales (temperatura, viento, UV) favorecen la visita, comparándola con los otros atractivos sugeridos ({lugares_top2}).
3. 'clothing': Lista de 2 a 4 prendas recomendadas (ropa ligera, protección solar o cortavientos según corresponda).
4. 'precautions': Lista de 2 a 4 recomendaciones y precauciones prácticas, mencionando los otros lugares de alto índice calculados para visitar hoy ({lugares_top2}), explicando en qué momento del día conviene ir según el clima.
5. 'suitability_score': Mantén el valor exacto de {score_calculado:.2f} proveniente del cálculo del sistema.
</tarea>"""

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

{bloque_tarea}

<restricciones>
1. Responde ÚNICAMENTE en el idioma solicitado: {idioma_nombre}.
2. Jamás inventes cifras meteorológicas ni modifiques el suitability_score de {score_calculado:.2f}.
3. Si hay alertas meteorológicas activas o arena caliente (> 40 °C), las precauciones deben priorizarlas de forma obligatoria.
</restricciones>""".strip()
