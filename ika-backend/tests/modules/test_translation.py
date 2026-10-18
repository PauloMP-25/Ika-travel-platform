"""Tests del módulo translation (F-1 a F-4 del Sprint 3).

Cubren T-01 (normalización), T-02 y T-03 (claves de caché), T-25
(integridad del frasebook), T-04…T-12 (servicio, proveedor y degradación)
y T-13…T-24 (contrato de los endpoints). Sin BD, sin red y sin Redis real:
los tests de servicio usan `fakeredis` y los de API inyectan
`MockTranslationProvider` con `app.dependency_overrides`.
"""

import asyncio
from collections import Counter
from types import SimpleNamespace

import fakeredis
import pytest
import redis.exceptions

from src.core.config import configuracion
from src.modules.translation.cache import TranslationCache, build_cache_keys
from src.modules.translation.dependencies import (
    get_translation_cache,
    get_translation_provider,
)
from src.modules.translation.exceptions import (
    InvalidTranslationResponseException,
    TranslationProviderUnavailableException,
)
from src.modules.translation.normalization import (
    normalize_for_cache,
    normalize_for_lookup,
)
from src.modules.translation.phrasebook import PHRASEBOOK
from src.modules.translation.providers import (
    GeminiTranslationProvider,
    MockTranslationProvider,
)
from src.modules.translation.schemas import (
    Language,
    PhraseCategory,
    TranslationOrigin,
    TranslationRequest,
)
from src.modules.translation.service import TranslationService
from tests.conftest import run

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


# ---------------------------------------------------------------------------
# Helpers de servicio (T-04 … T-12)
# ---------------------------------------------------------------------------


def _crear_cache(redis) -> TranslationCache:
    """Caché real sobre un Redis falso (o caído), con los TTLs de configuración."""
    return TranslationCache(
        redis=redis,
        ttl_seconds=configuracion.TRANSLATION_CACHE_TTL_SECONDS,
        fallback_ttl_seconds=configuracion.TRANSLATION_FALLBACK_TTL_SECONDS,
    )


def _crear_servicio(provider, cache: TranslationCache | None = None) -> TranslationService:
    """Servicio real con frasebook real y Redis fake por defecto."""
    return TranslationService(
        provider=provider,
        cache=cache or _crear_cache(fakeredis.FakeAsyncRedis()),
        phrasebook=PHRASEBOOK,
    )


def _solicitud(texto: str, source: Language = Language.ES, target: Language = Language.EN) -> TranslationRequest:
    return TranslationRequest(text=texto, source_lang=source, target_lang=target)


class _RedisCaido:
    """Doble de Redis que lanza RedisError en cada operación (T-08)."""

    def get(self, key):  # noqa: ANN001
        raise redis.exceptions.ConnectionError("Redis caído")

    def pipeline(self, transaction: bool = True):  # noqa: ANN001
        raise redis.exceptions.ConnectionError("Redis caído")


class _ModelosLentos:
    """Modelo falso que tarda más que el timeout (T-12)."""

    async def generate_content(self, model, contents, config):  # noqa: ANN001
        await asyncio.sleep(0.5)
        return SimpleNamespace(text="tarde demasado")


# ---------------------------------------------------------------------------
# T-04 y T-05 — Frase oficial sin invocar al proveedor
# ---------------------------------------------------------------------------


def test_t04_frase_oficial_exacta_sin_invocar_al_proveedor():
    """Un texto exacto del frasebook se resuelve sin caché ni proveedor."""
    provider = MockTranslationProvider()
    service = _crear_servicio(provider)

    respuesta = run(service.translate(_solicitud("¿Habla inglés?")))

    assert respuesta.origin is TranslationOrigin.OFFICIAL_PHRASE
    assert respuesta.translated_text == "Do you speak English?"
    assert respuesta.phrase_id == "sal-03"
    assert provider.calls == 0


def test_t05_frase_oficial_con_mayusculas_y_signos():
    """`¡HABLA INGLÉS!` resuelve la misma traducción oficial que `¿Habla inglés?`."""
    provider = MockTranslationProvider()
    service = _crear_servicio(provider)

    respuesta = run(service.translate(_solicitud("¡HABLA INGLÉS!")))

    assert respuesta.origin is TranslationOrigin.OFFICIAL_PHRASE
    assert respuesta.translated_text == "Do you speak English?"
    assert provider.calls == 0


# ---------------------------------------------------------------------------
# T-06 y T-07 — Caché hit y miss
# ---------------------------------------------------------------------------


def test_t06_cache_hit_no_vuelve_a_invocar_al_proveedor():
    """La segunda solicitud idéntica se sirve del caché (1 sola llamada al proveedor)."""
    provider = MockTranslationProvider()
    service = _crear_servicio(provider)
    solicitud = _solicitud("Necesito un tour de buggies al amanecer.")

    primera = run(service.translate(solicitud))
    segunda = run(service.translate(solicitud))

    assert primera.origin is TranslationOrigin.PROVIDER
    assert segunda.origin is TranslationOrigin.CACHE
    assert segunda.translated_text == primera.translated_text
    assert provider.calls == 1


def test_t07_cache_miss_guarda_con_ttl_7d_y_respaldo_30d():
    """Tras un miss, la clave principal expira en 7 días y la de respaldo en 30."""
    fake_redis = fakeredis.FakeAsyncRedis()
    provider = MockTranslationProvider()
    service = _crear_servicio(provider, cache=_crear_cache(fake_redis))
    texto = "¿Cuánto cuesta la cata de pisco?"

    respuesta = run(service.translate(_solicitud(texto)))

    assert respuesta.origin is TranslationOrigin.PROVIDER
    assert provider.calls == 1

    keys = build_cache_keys(Language.ES, Language.EN, texto)
    assert run(fake_redis.ttl(keys.primary)) == configuracion.TRANSLATION_CACHE_TTL_SECONDS
    assert run(fake_redis.ttl(keys.fallback)) == configuracion.TRANSLATION_FALLBACK_TTL_SECONDS


# ---------------------------------------------------------------------------
# T-08 — Redis caído: degradación controlada
# ---------------------------------------------------------------------------


def test_t08_redis_caido_continua_con_el_proveedor(caplog):
    """Si Redis lanza RedisError, la traducción se responde igual con origin=provider."""
    provider = MockTranslationProvider()
    service = _crear_servicio(provider, cache=_crear_cache(_RedisCaido()))

    respuesta = run(service.translate(_solicitud("Me siento mareado por el sol fuerte.")))

    assert respuesta.origin is TranslationOrigin.PROVIDER
    assert provider.calls == 1
    assert any("Redis no disponible" in record.getMessage() for record in caplog.records)


# ---------------------------------------------------------------------------
# T-09 y T-10 — Proveedor caído con y sin respaldo
# ---------------------------------------------------------------------------


def test_t09_proveedor_falla_sin_cache_lanza_503():
    """Sin ninguna copia en caché, el fallo del proveedor se propaga como 503."""
    service = _crear_servicio(MockTranslationProvider(fail=True))

    with pytest.raises(TranslationProviderUnavailableException) as excinfo:
        run(service.translate(_solicitud("Necesito un intérprete de urgencia.")))

    assert excinfo.value.codigo_http == 503
    assert excinfo.value.codigo == "TRADUCCION_PROVEEDOR_NO_DISPONIBLE"


def test_t10_proveedor_falla_con_respaldo_devuelve_cache_fallback():
    """Si la clave principal expiró pero la de respaldo existe, se sirve esa copia."""
    fake_redis = fakeredis.FakeAsyncRedis()
    texto = "¿Dónde está el hospital de Ica?"
    keys = build_cache_keys(Language.ES, Language.EN, texto)
    run(fake_redis.set(keys.fallback, "Where is the hospital of Ica?"))

    service = _crear_servicio(MockTranslationProvider(fail=True), cache=_crear_cache(fake_redis))

    respuesta = run(service.translate(_solicitud(texto)))

    assert respuesta.origin is TranslationOrigin.CACHE_FALLBACK
    assert respuesta.translated_text == "Where is the hospital of Ica?"


# ---------------------------------------------------------------------------
# T-11 y T-12 — Salida inválida y timeout del proveedor
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("raw_output", ["", "   ", "x" * 4000])
def test_t11_salida_vacia_o_desproporcionada_lanza_502(raw_output):
    """Una salida vacía o desproporcionada levanta InvalidTranslationResponseException."""
    service = _crear_servicio(MockTranslationProvider(raw_output=raw_output))

    with pytest.raises(InvalidTranslationResponseException) as excinfo:
        run(service.translate(_solicitud("Necesito agua potable de inmediato.")))

    assert excinfo.value.codigo_http == 502
    assert excinfo.value.codigo == "TRADUCCION_RESPUESTA_INVALIDA"


def test_t12_timeout_del_proveedor_mapeado_a_503():
    """Un timeout real del proveedor Gemini se convierte en excepción de dominio 503."""
    provider = GeminiTranslationProvider(
        api_key="clave-falsa", model="modelo-falso", timeout_seconds=0.01
    )
    # Cliente falso inyectado: sin red, solo asyncio.sleep para disparar el timeout.
    provider._client = SimpleNamespace(aio=SimpleNamespace(models=_ModelosLentos()))
    service = _crear_servicio(provider)

    with pytest.raises(TranslationProviderUnavailableException):
        run(service.translate(_solicitud("¿A qué hora sale el bus a Lima?")))


# ---------------------------------------------------------------------------
# Fixtures de API (T-13 … T-24)
# ---------------------------------------------------------------------------


@pytest.fixture
def mock_provider() -> MockTranslationProvider:
    return MockTranslationProvider()


@pytest.fixture
def translation_client(app, client, mock_provider, fakeredis_client):
    """Cliente de pruebas con proveedor mock y fakeredis inyectados en las dependencias."""
    app.dependency_overrides[get_translation_provider] = lambda: mock_provider
    app.dependency_overrides[get_translation_cache] = lambda: _crear_cache(fakeredis_client)
    return client


@pytest.fixture
def fakeredis_client():
    return fakeredis.FakeAsyncRedis()


def _post_traduccion(client, texto: str, source: str = "es", target: str = "en"):
    return client.post(
        "/api/v1/translation/translate",
        json={"text": texto, "source_lang": source, "target_lang": target},
    )


# ---------------------------------------------------------------------------
# T-13, T-14, T-15 y T-20 — Contrato de POST /translation/translate
# ---------------------------------------------------------------------------


def test_t13_api_frase_oficial(translation_client, mock_provider):
    """Frase oficial: 200 con origin=official_phrase y proveedor sin invocar."""
    response = translation_client.post(
        "/api/v1/translation/translate",
        json={"text": "¿Habla inglés?", "source_lang": "es", "target_lang": "en"},
    )

    assert response.status_code == 200
    data = response.json()
    assert data["origin"] == "official_phrase"
    assert data["translated_text"] == "Do you speak English?"
    assert mock_provider.calls == 0


def test_t14_api_texto_libre(translation_client, mock_provider):
    """Texto libre: 200 con origin=provider y el proveedor fue invocado."""
    response = _post_traduccion(translation_client, "Necesito un tour de buggies al amanecer.")

    assert response.status_code == 200
    assert response.json()["origin"] == "provider"
    assert mock_provider.calls == 1


def test_t15_api_segunda_llamada_identica_proviene_del_cache(translation_client, mock_provider):
    """La segunda llamada idéntica responde origin=cache con 1 sola invocación."""
    texto = "¿Cuánto demora el viaje a Huacachina?"

    primera = _post_traduccion(translation_client, texto)
    segunda = _post_traduccion(translation_client, texto)

    assert primera.status_code == segunda.status_code == 200
    assert segunda.json()["origin"] == "cache"
    assert segunda.json()["translated_text"] == primera.json()["translated_text"]
    assert mock_provider.calls == 1


def test_t20_api_sin_token_responde_200(translation_client):
    """Acceso anónimo (RN-02): la API no exige token ni devuelve 401."""
    response = _post_traduccion(translation_client, "¿Está lejos de aquí?")

    assert response.status_code == 200
    assert response.json()["origin"] == "official_phrase"


# ---------------------------------------------------------------------------
# T-16 … T-19 — Validaciones que devuelven 422
# ---------------------------------------------------------------------------


def test_t16_api_texto_vacio_devuelve_422(translation_client):
    assert _post_traduccion(translation_client, "").status_code == 422


def test_t17_api_texto_de_501_caracteres_devuelve_422(translation_client):
    assert _post_traduccion(translation_client, "x" * 501).status_code == 422


def test_t18_api_idiomas_iguales_devuelve_422(translation_client):
    assert _post_traduccion(translation_client, "Hola", source="es", target="es").status_code == 422


def test_t19_api_idioma_no_soportado_devuelve_422(translation_client):
    assert _post_traduccion(translation_client, "Bonjour", source="fr", target="en").status_code == 422


# ---------------------------------------------------------------------------
# T-22, T-23 y T-24 — Contrato de GET /translation/phrases (ETag)
# ---------------------------------------------------------------------------


def test_t22_api_phrases_devuelve_frasebook_versionado(translation_client):
    """Listado completo: 32 frases, 8 categorías, campo version y cabecera ETag."""
    response = translation_client.get("/api/v1/translation/phrases")

    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 32
    assert len(data["categories"]) == 8
    assert data["version"] == PHRASEBOOK.version
    assert response.headers["ETag"] == f'"{PHRASEBOOK.version}-all"'
    assert response.headers["Cache-Control"] == "public, max-age=3600"


def test_t23_api_filtro_por_categoria(translation_client):
    """`?category=emergencia` solo devuelve esa categoría; inválida → 422."""
    response = translation_client.get("/api/v1/translation/phrases", params={"category": "emergencia"})

    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 4
    assert {p["category"] for p in data["phrases"]} == {"emergencia"}

    invalida = translation_client.get("/api/v1/translation/phrases", params={"category": "inexistente"})
    assert invalida.status_code == 422


def test_t24_api_if_none_match_devuelve_304_sin_cuerpo(translation_client):
    """Revalidación con ETag: 304 con el mismo ETag y sin cuerpo."""
    previa = translation_client.get("/api/v1/translation/phrases")
    etag = previa.headers["ETag"]

    response = translation_client.get(
        "/api/v1/translation/phrases", headers={"If-None-Match": etag}
    )

    assert response.status_code == 304
    assert response.content == b""
