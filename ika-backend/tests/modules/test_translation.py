"""Tests unitarios del módulo translation (F-1 y F-2 del Sprint 3).

Cubren T-01 (normalización), T-02 y T-03 (claves de caché) y T-25
(integridad del frasebook). Sin BD, sin Redis y sin red: solo lógica pura.
"""

from collections import Counter

from src.modules.translation.cache import build_cache_keys
from src.modules.translation.normalization import (
    normalize_for_cache,
    normalize_for_lookup,
)
from src.modules.translation.phrasebook import PHRASEBOOK
from src.modules.translation.schemas import Language, PhraseCategory

# ---------------------------------------------------------------------------
# T-01 — Normalización
# ---------------------------------------------------------------------------


def test_normalize_for_cache_colapsa_espacios_y_conserva_mayusculas():
    """NFKC + espacios colapsados, conservando mayúsculas y puntuación."""
    assert normalize_for_cache("  HOLA   mundo  ") == "HOLA mundo"


def test_normalize_for_lookup_casefold_y_sin_signos_extremos():
    """Casefold y signos de puntuación extremos retirados; las tildes se conservan."""
    assert normalize_for_lookup("¿Habla Inglés?") == "habla inglés"
    assert normalize_for_lookup("¡HABLA INGLÉS!") == "habla inglés"


# ---------------------------------------------------------------------------
# T-02 — Clave de caché estable
# ---------------------------------------------------------------------------


def test_clave_cache_estable_con_variantes_de_espacios():
    """Variantes de espacios y signos exteriores producen la misma clave."""
    una = build_cache_keys(Language.ES, Language.EN, "Necesito una farmacia")
    otra = build_cache_keys(Language.ES, Language.EN, "  Necesito   una farmacia ")
    assert una.primary == otra.primary
    assert una.fallback == otra.fallback


def test_clave_cache_con_prefijos_de_version():
    """Formato: traduccion:v1:{src}:{dst}:{sha256} y su variante de respaldo."""
    keys = build_cache_keys(Language.ES, Language.EN, "hola")
    assert keys.primary.startswith("traduccion:v1:es:en:")
    assert keys.fallback.startswith("traduccion:respaldo:v1:es:en:")


# ---------------------------------------------------------------------------
# T-03 — Clave por par de idiomas
# ---------------------------------------------------------------------------


def test_clave_cache_difiere_por_par_de_idiomas():
    """El mismo texto con el par de idiomas invertido genera claves distintas."""
    es_en = build_cache_keys(Language.ES, Language.EN, "Necesito agua")
    en_es = build_cache_keys(Language.EN, Language.ES, "Necesito agua")
    assert es_en.primary != en_es.primary
    assert es_en.fallback != en_es.fallback


# ---------------------------------------------------------------------------
# T-25 — Integridad del frasebook
# ---------------------------------------------------------------------------


def test_frasebook_integridad_general():
    """32 frases, ids únicos, es/en no vacíos, ≥4 por categoría y versión de 12 caracteres."""
    frases = PHRASEBOOK.list()
    assert len(frases) == 32

    ids = [f.id for f in frases]
    assert len(set(ids)) == len(ids)

    for frase in frases:
        assert frase.es.strip()
        assert frase.en.strip()

    conteo = Counter(frase.category for frase in frases)
    assert set(conteo) == set(PhraseCategory)
    assert all(conteo[categoria] >= 4 for categoria in PhraseCategory)

    assert len(PHRASEBOOK.version) == 12


def test_frasebook_sin_duplicados_normalizados():
    """Ningún texto normalizado (por idioma) se repite en el índice."""
    vistos: set[tuple[Language, str]] = set()
    for frase in PHRASEBOOK.list():
        for language in Language:
            clave = (language, normalize_for_lookup(frase.text_in(language)))
            assert clave not in vistos, f"Frase duplicada normalizada: {clave}"
            vistos.add(clave)


def test_frasebook_encuentra_frase_con_variaciones_de_forma():
    """La búsqueda por texto normalizado resuelve mayúsculas y signos distintos."""
    frase = PHRASEBOOK.find(Language.ES, normalize_for_lookup("¡HABLA INGLÉS!"))
    assert frase is not None
    assert frase.id == "sal-03"
    assert frase.text_in(Language.EN) == "Do you speak English?"
