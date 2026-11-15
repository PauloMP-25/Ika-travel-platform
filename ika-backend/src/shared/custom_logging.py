"""Sistema de logging visual, estilizado y estructurado para Ika Travel Platform.

Incluye banners ANSI de alta legibilidad para eventos críticos (Recomendaciones,
consumo de tokens de Gemini, consultas de clima) y logs formateados para auth y catálogo.
"""

from __future__ import annotations

import logging
from typing import Any

# Códigos de color y estilo ANSI
CYAN = "\033[96m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
MAGENTA = "\033[95m"
BLUE = "\033[94m"
RED = "\033[91m"
BOLD = "\033[1m"
DIM = "\033[2m"
RESET = "\033[0m"

logger = logging.getLogger("ika.platform")


def registrar_log_recomendacion(
    *,
    atractivo: str,
    modo: str,  # 'tiempo_real' o 'planificacion_manana'
    score: float,
    nivel: str,
    temperatura: float,
    uv: float,
    viento: float,
    condicion: str,
    hora_sugerida: str | None = None,
    justificacion_seguridad: str | None = None,
    fuente_motor: str = "gemini",  # 'gemini' o 'fallback_determinista'
    tokens_prompt: int = 0,
    tokens_candidates: int = 0,
    tiempo_segundos: float = 0.0,
) -> None:
    """Imprime un banner vistoso y detallado de la recomendación turística generada."""
    color_nivel = {
        "excelente": GREEN,
        "bueno": CYAN,
        "regular": YELLOW,
        "no_recomendado": RED,
    }.get(nivel.lower(), CYAN)

    icono_modo = "🌅 PLANIFICACIÓN PARA MAÑANA" if modo == "planificacion_manana" else "☀️ RECOMENDACIÓN EN TIEMPO REAL"
    color_modo = YELLOW if modo == "planificacion_manana" else GREEN

    total_tokens = tokens_prompt + tokens_candidates
    costo_usd = (tokens_prompt * 0.0000001) + (tokens_candidates * 0.0000004)

    banner = (
        f"\n{MAGENTA}╔══════════════════════════════════════════════════════════════╗{RESET}\n"
        f"{MAGENTA}║{RESET} {BOLD}🎯 RECOMENDACIÓN INTELIGENTE DE VIAJE — IKA TRAVEL{RESET}\n"
        f"{MAGENTA}╠══════════════════════════════════════════════════════════════╣{RESET}\n"
        f"{MAGENTA}║{RESET} • {BOLD}Destino:{RESET}          {BOLD}{CYAN}{atractivo}{RESET}\n"
        f"{MAGENTA}║{RESET} • {BOLD}Modalidad:{RESET}        {color_modo}{BOLD}{icono_modo}{RESET}\n"
    )

    if hora_sugerida:
        banner += f"{MAGENTA}║{RESET} • {BOLD}Hora Sugerida:{RESET}    {BOLD}{GREEN}{hora_sugerida}{RESET} (ajustada por clima y seguridad)\n"

    banner += (
        f"{MAGENTA}║{RESET} • {BOLD}Nivel & Score:{RESET}    {color_nivel}{BOLD}{nivel.upper()} ({score:.2f}){RESET}\n"
        f"{MAGENTA}╠══════════════════════════════════════════════════════════════╣{RESET}\n"
        f"{MAGENTA}║{RESET} 🌤️  {BOLD}Métricas Climatológicas Evaluadas:{RESET}\n"
        f"{MAGENTA}║{RESET}    🌡️ Temp: {BOLD}{temperatura:.1f}°C{RESET}  |  💨 Viento: {BOLD}{viento:.1f} km/h{RESET}  |  ☀️ UV: {BOLD}{uv:.1f}{RESET}\n"
        f"{MAGENTA}║{RESET}    ☁️ Condición: {BOLD}{condicion}{RESET}\n"
    )

    if justificacion_seguridad:
        banner += (
            f"{MAGENTA}╠══════════════════════════════════════════════════════════════╣{RESET}\n"
            f"{MAGENTA}║{RESET} 🛡️ {BOLD}Control de Seguridad & Horario:{RESET}\n"
            f"{MAGENTA}║{RESET}    {DIM}{justificacion_seguridad}{RESET}\n"
        )

    banner += f"{MAGENTA}╠══════════════════════════════════════════════════════════════╣{RESET}\n"
    if fuente_motor == "gemini" and total_tokens > 0:
        banner += (
            f"{MAGENTA}║{RESET} 🧠 {BOLD}Motor IA:{RESET} Google Gemini ({tiempo_segundos:.2f} s)\n"
            f"{MAGENTA}║{RESET}    📥 In: {YELLOW}{tokens_prompt:>5,}{RESET} tok | 📤 Out: {GREEN}{tokens_candidates:>4,}{RESET} tok | 📊 Total: {BOLD}{total_tokens:>5,}{RESET} | 💲 ${costo_usd:.6f}\n"
        )
    else:
        banner += f"{MAGENTA}║{RESET} ⚡ {BOLD}Motor IA:{RESET} Reglas Deterministas / Fallback (< 5 ms)\n"

    banner += f"{MAGENTA}╚══════════════════════════════════════════════════════════════╝{RESET}\n"
    print(banner, flush=True)


def registrar_log_clima(
    *,
    destino: str,
    origen: str,  # 'cache_redis' o 'api_open_meteo'
    temperatura: float,
    sensacion: float | None = None,
    viento: float,
    uv: float,
    condicion: str,
    alertas_activas: int = 0,
) -> None:
    """Imprime un banner estilizado cada vez que se consulta o refresca el clima."""
    badge_origen = f"{GREEN}⚡ CACHE HIT (Redis){RESET}" if origen == "cache_redis" else f"{CYAN}🌐 API EXTERNA (Open-Meteo){RESET}"

    banner = (
        f"\n{CYAN}┌──────────────────────────────────────────────────────────────┐{RESET}\n"
        f"{CYAN}│{RESET} {BOLD}🌤️  CONSULTA DE CLIMA EN TIEMPO REAL — IKA TRAVEL{RESET}\n"
        f"{CYAN}├──────────────────────────────────────────────────────────────┤{RESET}\n"
        f"{CYAN}│{RESET} • {BOLD}Ubicación:{RESET}   {BOLD}{destino}{RESET}\n"
        f"{CYAN}│{RESET} • {BOLD}Fuente:{RESET}      {badge_origen}\n"
        f"{CYAN}│{RESET} • {BOLD}Mediciones:{RESET}  🌡️ {BOLD}{temperatura:.1f}°C{RESET}"
    )
    if sensacion is not None:
        banner += f" (Sensación: {sensacion:.1f}°C)"
    banner += (
        f"  |  💨 {BOLD}{viento:.1f} km/h{RESET}  |  ☀️ UV: {BOLD}{uv:.1f}{RESET}\n"
        f"{CYAN}│{RESET} • {BOLD}Condición:{RESET}   {condicion}\n"
    )
    if alertas_activas > 0:
        banner += f"{CYAN}│{RESET} • {BOLD}Alertas:{RESET}     {RED}{BOLD}⚠️ {alertas_activas} alerta(s) de riesgo meteorológico activa(s){RESET}\n"
    else:
        banner += f"{CYAN}│{RESET} • {BOLD}Alertas:{RESET}     {GREEN}✓ Sin alertas meteorológicas críticas{RESET}\n"

    banner += f"{CYAN}└──────────────────────────────────────────────────────────────┘{RESET}\n"
    print(banner, flush=True)


def imprimir_tabla_comparativa_apis(
    resultados_por_proveedor: dict[str, Any],
    consenso: Any,
) -> None:
    """Imprime una tabla comparativa vistosa de 3 APIs x dimensiones extraídas."""
    def _val(prov: str, campo: str, unidad: str = "", formato: str = ".1f") -> str:
        if prov == "Consenso Final":
            obj = consenso
        else:
            # Buscar por coincidencia flexible (ej. open-meteo, weatherapi, openweathermap)
            obj = None
            t = prov.lower().replace("-", "").replace("_", "")
            for k, v in resultados_por_proveedor.items():
                if t in k.lower().replace("-", "").replace("_", ""):
                    obj = v
                    break
            if obj is None:
                obj = resultados_por_proveedor.get(prov)

        if obj is None or isinstance(obj, Exception):
            return "N/D / Fallo"
        v = getattr(obj, campo, None)
        if v is None:
            return "N/D"
        if isinstance(v, (int, float)):
            return f"{v:{formato}} {unidad}".strip()
        return str(v)

    dimensiones = [
        ("🌡️  Temperatura", "temperatura_actual", "°C", ".1f"),
        ("🌡️  Sensación Térmica", "sensacion_termica", "°C", ".1f"),
        ("💨 Velocidad Viento", "velocidad_viento", "km/h", ".1f"),
        ("💨 Ráfagas de Viento", "rafagas_viento", "km/h", ".1f"),
        ("💧 Humedad Relativa", "humedad", "%", ".0f"),
        ("☀️  Índice UV", "indice_uv", "", ".1f"),
        ("🌧️  Prob. Precipitación", "probabilidad_precipitacion", "%", ".0f"),
        ("🧭 Presión Atmosférica", "presion_atmosferica", "hPa", ".0f"),
        ("☁️  Condición / Clima", "descripcion_clima", "", "s"),
    ]

    ancho_dim = 26
    ancho_col = 20

    sep = f"{CYAN}├─{'─' * ancho_dim}─┼─{'─' * ancho_col}─┼─{'─' * ancho_col}─┼─{'─' * ancho_col}─┼─{'─' * ancho_col}─┤{RESET}"
    top = f"{CYAN}┌─{'─' * ancho_dim}─┬─{'─' * ancho_col}─┬─{'─' * ancho_col}─┬─{'─' * ancho_col}─┬─{'─' * ancho_col}─┐{RESET}"
    bot = f"{CYAN}└─{'─' * ancho_dim}─┴─{'─' * ancho_col}─┴─{'─' * ancho_col}─┴─{'─' * ancho_col}─┴─{'─' * ancho_col}─┘{RESET}"

    header = (
        f"{CYAN}│{RESET} {BOLD}{'Dimensión':<{ancho_dim}}{RESET} "
        f"{CYAN}│{RESET} {BOLD}{'Open-Meteo':<{ancho_col}}{RESET} "
        f"{CYAN}│{RESET} {BOLD}{'OpenWeatherMap':<{ancho_col}}{RESET} "
        f"{CYAN}│{RESET} {BOLD}{'WeatherAPI':<{ancho_col}}{RESET} "
        f"{CYAN}│{RESET} {BOLD}{GREEN}{'Consenso Final':<{ancho_col}}{RESET} {CYAN}│{RESET}"
    )

    titulo = (
        f"\n{CYAN}┌─────────────────────────────────────────────────────────────────────────────────────────────────┐{RESET}\n"
        f"{CYAN}│{RESET} {BOLD}📊 CONFRONTACIÓN DE 3 APIS METEOROLÓGICAS (PATRÓN AGGREGATOR) — IKA TRAVEL{RESET}\n"
        f"{CYAN}└─────────────────────────────────────────────────────────────────────────────────────────────────┘{RESET}"
    )

    filas = [titulo, top, header, sep]
    for etiqueta, campo, unidad, fmt in dimensiones:
        v_om = _val("Open-Meteo", campo, unidad, fmt)
        v_owm = _val("OpenWeatherMap", campo, unidad, fmt)
        v_wapi = _val("WeatherAPI", campo, unidad, fmt)
        v_cons = _val("Consenso Final", campo, unidad, fmt)

        def _pad(s: str, w: int) -> str:
            raw = s.replace(DIM, "").replace(RESET, "").replace(BOLD, "").replace(GREEN, "")
            if len(raw) > w:
                return s[:w-1] + "…"
            return s + " " * max(0, w - len(raw))

        fila = (
            f"{CYAN}│{RESET} {etiqueta:<{ancho_dim}} "
            f"{CYAN}│{RESET} {_pad(v_om, ancho_col)} "
            f"{CYAN}│{RESET} {_pad(v_owm, ancho_col)} "
            f"{CYAN}│{RESET} {_pad(v_wapi, ancho_col)} "
            f"{CYAN}│{RESET} {_pad(v_cons, ancho_col)} {CYAN}│{RESET}"
        )
        filas.append(fila)
    filas.append(bot)

    print("\n".join(filas), flush=True)


def log_auth(accion: str, email: str, metodo: str = "email", exitoso: bool = True, detalle: str = "") -> None:
    """Registra eventos de autenticación de forma clara y profesional."""
    estado = f"{GREEN}EXITOSO{RESET}" if exitoso else f"{RED}FALLIDO{RESET}"
    icono = "🔑" if exitoso else "❌"
    msg = f"{icono} [AUTH] {accion.upper()} | Metodo: {metodo} | Usuario: {email} | Estado: {estado}"
    if detalle:
        msg += f" | Detalle: {detalle}"
    print(msg, flush=True)


def log_catalog(accion: str, total: int = 0, filtros: str = "", etag: str = "") -> None:
    """Registra consultas del catálogo de atractivos y agencias."""
    msg = f"🏛️  [CATALOG] {accion} | Total items: {total}"
    if filtros:
        msg += f" | Filtros: {filtros}"
    if etag:
        msg += f" | ETag: {etag}"
    print(msg, flush=True)


def log_emergency(tipo: str, detalle: str = "") -> None:
    """Registra eventos del módulo de emergencia y SOS."""
    print(f"🚨 [EMERGENCIA] {tipo} | {detalle}", flush=True)
