"""Módulo de registro visual y estructurado del consumo de tokens de Gemini AI."""

import logging
import time

logger = logging.getLogger("ika.gemini.tokens")

# Códigos de escape ANSI para colores en consola
CYAN = "\033[96m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
MAGENTA = "\033[95m"
BOLD = "\033[1m"
RESET = "\033[0m"


def registrar_consumo_tokens(
    *,
    operacion: str,
    modelo: str,
    tiempo_segundos: float,
    usage_metadata: any = None,
    detalles_extra: str | None = None,
) -> None:
    """Imprime un banner formateado y visualmente atractivo en los logs del servidor."""
    prompt_tokens = getattr(usage_metadata, "prompt_token_count", 0) or 0
    candidate_tokens = getattr(usage_metadata, "candidates_token_count", 0) or 0
    total_tokens = getattr(usage_metadata, "total_token_count", prompt_tokens + candidate_tokens) or 0

    # Estimación de costo aproximado (gemini-flash: ~$0.075 / 1M input, ~$0.30 / 1M output)
    costo_usd = (prompt_tokens * 0.0000001) + (candidate_tokens * 0.0000004)

    banner = (
        f"\n{CYAN}┌──────────────────────────────────────────────────────────────┐{RESET}\n"
        f"{CYAN}│{RESET} {BOLD}✨ GEMINI AI — CONSUMO DE TOKENS & LATENCIA{RESET}\n"
        f"{CYAN}├──────────────────────────────────────────────────────────────┤{RESET}\n"
        f"{CYAN}│{RESET} • {BOLD}Operación:{RESET}     {MAGENTA}{operacion}{RESET}\n"
        f"{CYAN}│{RESET} • {BOLD}Modelo:{RESET}        {modelo}\n"
        f"{CYAN}│{RESET} • {BOLD}Tiempo ejec:{RESET}   {tiempo_segundos:.2f} s\n"
        f"{CYAN}├──────────────────────────────────────────────────────────────┤{RESET}\n"
        f"{CYAN}│{RESET} 📥 {BOLD}Tokens Entrada (Prompt):{RESET}      {YELLOW}{prompt_tokens:>6,}{RESET} tokens\n"
        f"{CYAN}│{RESET} 📤 {BOLD}Tokens Salida (Candidatos):{RESET}   {GREEN}{candidate_tokens:>6,}{RESET} tokens\n"
        f"{CYAN}│{RESET} 📊 {BOLD}Total Tokens Utilizados:{RESET}     {BOLD}{CYAN}{total_tokens:>6,}{RESET} tokens\n"
        f"{CYAN}│{RESET} 💲 {BOLD}Costo Estimado:{RESET}              ${costo_usd:.6f} USD\n"
    )

    if detalles_extra:
        banner += (
            f"{CYAN}├──────────────────────────────────────────────────────────────┤{RESET}\n"
            f"{CYAN}│{RESET} ℹ️ {BOLD}Detalle:{RESET} {detalles_extra}\n"
        )

    banner += f"{CYAN}└──────────────────────────────────────────────────────────────┘{RESET}\n"

    # Mostrar en stdout/consola de uvicorn directamente para visualización inmediata
    print(banner, flush=True)
