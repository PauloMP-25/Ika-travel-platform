"""Normalización de texto para el frasebook y la caché de traducciones."""

import unicodedata

_EDGE_PUNCTUATION = " ¿?¡!.,;:"


def _collapse_whitespace(text: str) -> str:
    return " ".join(unicodedata.normalize("NFKC", text).split())


def normalize_for_lookup(text: str) -> str:
    """Normaliza para buscar en el frasebook: NFKC, espacios, sin signos extremos y casefold.

    Conserva las tildes porque cambian el significado ("esta" vs "está").
    """
    return _collapse_whitespace(text).strip(_EDGE_PUNCTUATION).casefold()


def normalize_for_cache(text: str) -> str:
    """Normaliza para la clave de caché: NFKC y espacios colapsados.

    Conserva mayúsculas y puntuación porque la salida de la IA depende de ellas.
    """
    return _collapse_whitespace(text)
