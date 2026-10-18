# Sprint 4 — Hardening Total del Backend

Revisé `contexto.md`, `roadmap-ika-travel.md`, `instrucciones_claude.md`, `estructura_backend.md`, `modelo_datos.md` (raíz y `docs/`), `contexto_especificacion_producto.md` y `capitulo1_puntos_clave.md`. Antes del plan, tres hallazgos que afectan al sprint:

1. **Numeración de RN inconsistente entre documentos.** En `contexto_especificacion_producto.md`, RN-03 es protección de datos (Ley 29733) y RN-04 es offline. En el Cap. IV y el roadmap, RN-03 es frescura del clima (6 h) y RN-04 son permisos GPS. El plan usa los códigos del roadmap (RN-03 = clima, RN-04 = GPS/SOS). Aun así, cito la regla por nombre en código y tests, y conviene unificar la numeración en la memoria antes de cerrar el informe. El login con Google debe cumplir la regla de datos personales (consentimiento, minimización) con el nombre que tenga.
2. **`idx_attractions_category_rating` no existe tal cual en el modelo.** `Attraction` no tiene `rating` (se agrega desde `reviews`) y la categoría es N:M. Mantengo el objetivo (acelerar filtro por categoría + promedio) pero con índices sobre las tablas reales (§ Francis F2).
3. **ETag da validación, no sincronización delta.** El roadmap dice "sincronización delta", pero ETag/304 solo responde "¿cambió el recurso?". Cumple OE3/HE3 como contrato mínimo offline-first. El delta real (`updated_since`) lo dejo como opción para Sprint 5.

---

## Sprint Goals

### Meta general
Cerrar el backend al 100% funcional, optimizado y con contratos listos para que el Sprint 5 (Flutter) se conecte sin cambios de API.

### Metas medibles

| # | Meta | Criterio de aceptación | Dueño |
|---|---|---|---|
| G1 | Alertas climáticas de Ica (viento Paracas, UV extremo, calor, lluvia) | Motor de reglas puro, parametrizable, con ≥ 12 casos de borde en tests | Paulo |
| G2 | Frescura RN-03 sin picos de latencia | Cache-Aside en Redis con TTL 6 h, anti-stampede y dato > 6 h nunca servido como vigente | Paulo |
| G3 | Recomendador Gemini validado | Salida JSON estructurada y validada con Pydantic, bilingüe, 5 categorías PERTUR × 5 lugares cubiertos | Paulo |
| G4 | Fallback determinista | Cálculo del fallback < 150 ms (medido en test) y respuesta siempre válida, aunque Gemini falle | Paulo |
| G5 | Login con Google | `POST /api/v1/auth/login/google` con `GoogleAuthStrategy`, aprovisionamiento de turista y JWT | Francis |
| G6 | BD optimizada | `EXPLAIN ANALYZE` antes/después documentado; sin Seq Scan en las consultas de catálogo y analítica listadas | Francis |
| G7 | Contrato ETag | `/catalog/attractions` y `/catalog/agencies` responden 304 con `If-None-Match` | Francis |
| G8 | Idempotencia | Reenviar `POST /emergency/sos` o `/emergency/reports` con la misma `Idempotency-Key` no duplica filas ni despachos | Francis |
| G9 | Calidad | 119 tests intactos y suite ≥ 135 (meta realista: ~150) | Ambos |

### Fuera de alcance
- Integración con pantallas Flutter (Sprint 5).
- Delta sync (`updated_since`), PostGIS, login con Facebook.
- Cualquier reserva o pago (exclusiones 01–03 de la especificación).

### Cronograma (10 días hábiles)

| Día | Paulo | Francis |
|---|---|---|
| 1–2 | P1 Auditoría del Aggregator | F1 Google Auth (config, strategy, schemas) |
| 3–4 | P2 Motor de alertas | F1 Servicio, router, migración de índice único |
| 5–6 | P3 Cache-Aside + Celery beat | F2 Índices y `EXPLAIN ANALYZE` |
| 7–8 | P4 Recomendador Gemini | F3 ETag |
| 9 | P5 Fallback + P6 bilingüe | F4 Idempotency-Key |
| 10 | P7 Pruebas, cobertura, cierre | Pruebas, cierre, tag `sprint-4` |

**Regla de migraciones (evita múltiples heads de Alembic):** Francis es dueño de las migraciones del sprint. Si Paulo necesita un cambio de esquema (ver P2), lo pide a Francis o coordinan el orden de merge. El CI debe fallar si `alembic heads` devuelve más de una línea.

**Flujo Git (según `guia_y_tareas_equipo.md`):** ramas `feature/...` desde `develop`, commits convencionales en español, PR cruzado (Francis revisa a Paulo y viceversa) y prueba local antes de aprobar.

---

## Task Breakdown — Paulo

### Rama sugerida: `feature/weather-alerts-ica` → `feature/gemini-recommender-hardening`

### P1 — Auditoría y robustecimiento del Aggregator (`weather/provider.py`, `adapters/`)

1. Ejecutar los tres adaptadores con `asyncio.gather(..., return_exceptions=True)` y **timeout por proveedor de 3 s** (`asyncio.timeout`).
2. Normalizar unidades en cada adaptador (°C, km/h, %, índice UV). OpenWeatherMap puede entregar viento en m/s: convertir en el adaptador, no en el agregador.
3. Consolidar con **quórum ≥ 1**: con un solo proveedor sano se responde. Con varios, usar mediana de temperatura y viento y el **máximo** de UV (criterio conservador de seguridad). Descartar outliers fuera de ±3 σ o de rangos físicos válidos.
4. Registrar en `source_provider` los proveedores usados (ej. `"open-meteo+weatherapi"`).
5. Si fallan los tres, lanzar `WeatherProviderUnavailableException`.
6. Test: cada proveedor caído por separado, los tres caídos, un proveedor lento (timeout) y uno con dato absurdo.

### P2 — Motor de alertas climáticas de Ica (`weather/constants.py`, `weather/service.py`)

Función **pura** `evaluar_alertas(snapshot, zona) -> list[AlertaCandidata]`, sin I/O, para poder testearla con tablas.

Umbrales iniciales **propuestos y parametrizables** (no son valores oficiales; validarlos con DIRCETUR/SENAMHI antes de producción):

| `alert_type` | Zona | advisory | warning | danger |
|---|---|---|---|---|
| `paracas_wind` | Solo atractivos de Paracas | ≥ 25 km/h | ≥ 35 km/h | ≥ 50 km/h |
| `extreme_uv` | Toda la región | UV 8–10 | UV 11 | UV ≥ 12 |
| `high_temperature` | Toda la región | ≥ 33 °C | ≥ 37 °C | ≥ 40 °C |
| `rain_hazard` | Toda la región | llovizna | lluvia | lluvia intensa |

Notas:
- La escala UV (11+ = extremo) es la de la OMS, y los demás valores salen de `constants.py`, no de `if` dispersos.
- **Decisión pendiente:** `WeatherSnapshot` no tiene campo de precipitación. Opción A: mapear `condition_code` a lluvia (sin migración). Opción B: agregar `precipitation_mm` (migración que hace Francis). Recomiendo A en este sprint.
- Persistencia: **upsert** de `WeatherAlert` por (`attraction_id`, `alert_type`, `is_active`). Si la severidad cambia, actualizar. Si la condición cesa, `is_active=False`. `expires_at = captured_at + 6 h`.
- Test: tabla `pytest.mark.parametrize` con valores justo debajo, en y por encima de cada umbral, más "Paracas sí / Huacachina no" para el viento.

### P3 — Cache-Aside RN-03 con Redis (`weather/service.py`, `weather/tasks.py`)

- Claves: `weather:snapshot:{attraction_id}` y `weather:alerts:{attraction_id}`, TTL **21 600 s** (6 h). El TTL de alertas nunca excede el tiempo restante del snapshot.
- **Anti-stampede:** lock `SET weather:lock:{id} NX EX 15`. Quien no obtiene el lock espera ≤ 2 s y relee la caché.
- Orden de resolución en `get_fresh_snapshot`: Redis → provider (con lock) → último snapshot en BD **solo si `captured_at` ≤ 6 h**. Si no hay dato válido, `StaleWeatherDataException` (HTTP 503, `codigo` propio). Nunca se sirve como vigente un dato de más de 6 h.
- **Celery Beat cada 3 h** (`refresh_weather_cache`) recorre atractivos activos. El margen de 3 h evita llegar al límite de 6 h si una ejecución falla.
- Test con `fakeredis` o un Redis de test: hit, miss, expirado, lock contendido, proveedor caído con snapshot de 2 h en BD (sirve) y con snapshot de 7 h (503).

### P4 — Recomendador Gemini estructurado (`weather/ai_recommender.py`)

1. Usar **salida estructurada** del SDK `google-genai` (`response_mime_type="application/json"` + `response_schema`) con el modelo Pydantic `RecomendacionEnriquecida` (§ diseño técnico).
2. Prompt compuesto por: atractivo (nombre, lugar, categoría oficial PERTUR/PROMPERÚ), snapshot, alertas activas e idioma. Las 5 categorías (aventura en desierto, enoturismo, marina costera, arqueología, cultural urbano) se mapean en una tabla en `constants.py`, no en el prompt libre.
3. **Presupuesto de tiempo:** `asyncio.wait_for(gemini, timeout=2.5)`. Ante timeout, error de API, JSON inválido o idioma incorrecto, se usa el fallback (P5).
4. **Guardarraíl de seguridad post-IA:** si hay una alerta `danger` activa, el `suitability_score` se recorta a ≤ 0.3 y se antepone la precaución correspondiente, aunque Gemini diga lo contrario. La IA no puede contradecir una alerta oficial.
5. Caché de la recomendación en Redis por (`attraction_id`, `idioma`, hash de preferencias, `snapshot_id`), TTL igual al del snapshot. Evita llamadas repetidas a Gemini.
6. Pruebas con Gemini **mockeado** (CI) y un marcador `@pytest.mark.live` para las pruebas reales de `test_poc_weather_ai.py`, excluidas del CI por defecto.

### P5 — Fallback determinista < 150 ms

- Función pura `recomendar_determinista(atractivo, snapshot, alertas, idioma, afinidad) -> RecomendacionEnriquecida`, basada en reglas y plantillas es/en. Sin red ni Redis.
- Reglas ejemplo: Sandboarding con viento > 35 km/h baja el score y añade la precaución de arena en suspensión. Paracas con `paracas_wind` ≥ warning desaconsejará lanchas. Nazca con visibilidad baja ajusta el sobrevuelo. UV alto exige protección.
- Marcar `source="fallback"`. Test de rendimiento: 1 000 ejecuciones con `time.perf_counter`, p95 < 150 ms.
- Si Gemini falló, encolar una tarea Celery de "calentamiento" de la caché para la siguiente petición.

### P6 — Formato enriquecido bilingüe

Campos: `summary`, `climate_justification`, `clothing`, `precautions`, `visibility_level`, `suitability_score`, `source`, `language`. Validar que el texto de Gemini esté realmente en el idioma pedido (heurística simple por stopwords es/en); si no, fallback. Plantillas del fallback en un módulo `constants.py`/`i18n` de weather.

### P7 — Suite de escenarios de Ica

Matriz de escenarios (§ testing) con clima sintético: mediodía de verano en Huacachina, tarde ventosa en Paracas, mañana nublada en Nazca, etc. Verificar guardarraíles, idioma y estructura. Meta: ~16 tests nuevos.

### Definition of Done de Paulo

- [ ] Alertas, caché y recomendador cubiertos por tests y verdes junto con los 119 previos.
- [ ] `mypy`/type hints estrictos sin errores en `weather/`.
- [ ] Umbrales documentados como "propuestos, pendientes de validación".
- [ ] Sin llamadas reales a APIs externas en la suite por defecto.

---

## Task Breakdown — Francis

### Ramas sugeridas: `feature/google-auth`, `feature/db-indexes`, `feature/offline-contracts`

### F1 — Login con Google (`users/`)

1. **Config** (`core/config.py`): `GOOGLE_CLIENT_IDS` (lista: Android, iOS y web), por entorno. Agregar `google-auth` y `requests` a `requirements.txt`.
2. **Strategy:** crear `users/auth_strategies/` con `base.py` (Protocol `EstrategiaAutenticacionSocial` y dataclass `IdentidadSocial`), `google.py` (`GoogleAuthStrategy`) y un registro `{ "google": GoogleAuthStrategy }`. Esto deja la puerta abierta a Facebook sin tocar el servicio.
3. **Verificación del token:** `id_token.verify_oauth2_token` es síncrono, así que ejecutarlo con `anyio.to_thread.run_sync`. Validar firma (la librería lo hace), `aud` contra `GOOGLE_CLIENT_IDS`, `iss`, `exp` y `email_verified is True`.
4. **Servicio** `autenticar_social(db, proveedor, token, consentimiento)`:
   - Buscar por `provider_id` (el `sub` de Google).
   - Si no existe, buscar por email. Si existe y `email_verified` es true, **vincular** (`provider_id`). Si no, crear usuario `role=tourist`, `auth_provider=google`, `password_hash=None`, `preferred_language` del request o `"es"`, `preferences=[]`.
   - Usuario inactivo → `InactiveUserException`.
5. **Consentimiento de datos personales:** si el usuario es nuevo y no vino `acepta_politica_datos=true`, responder con error de negocio `CONSENTIMIENTO_REQUERIDO` (el cliente reenvía con el flag). Guardar solo `sub`, email y nombre; **no** almacenar el ID token ni la foto.
6. **Endurecer el login por email:** `authenticate_user` debe rechazar con `InvalidCredentialsException` genérica a un usuario con `password_hash is None` (cuenta social), sin revelar que existe.
7. Endpoint: `POST /api/v1/auth/login/google` → `TokenSocialResponse`. Si se mantiene `/auth/login/social`, que sea un alias que delega en el mismo servicio.
8. **Decisión a validar con Paulo:** al vincular una cuenta de email existente con Google, `auth_provider` se queda en `email` (la contraseña sigue funcionando) y solo se rellena `provider_id`. Es lo más simple con el esquema actual de una columna. La alternativa, una tabla `social_identities`, queda para después.

### F2 — Optimización de PostgreSQL

Primero medir, luego indexar: guardar la salida de `EXPLAIN (ANALYZE, BUFFERS)` antes y después de cada índice en `docs/optimizacion_bd.md`.

| Índice | Tabla / columnas | Consulta que acelera |
|---|---|---|
| `idx_attraction_category_category` | `attraction_category (category_id, attraction_id)` | Filtro por categoría (la PK actual empieza por `attraction_id`) |
| `idx_reviews_attraction_rating` | `reviews (attraction_id, rating)` | `avg_rating` y distribución, con index-only scan |
| `idx_attractions_active_district` | `attractions (is_active, district)` | Listado filtrado por distrito |
| `idx_attractions_lat_lng` | `attractions (latitude, longitude)` | Prefiltro por bounding box antes del cálculo Haversine en `geo` |
| `idx_agencies_validated` | `agencies (name) WHERE is_validated` (parcial) | RN-01: solo las validadas se listan y buscan |
| `idx_usage_events_event_timestamp` | `usage_events (<columna de tipo de evento>, <columna de timestamp>)` | Analítica `/admin/analytics/*` |
| `idx_sos_reports_user_created` | `sos_reports (user_id, created_at DESC)` | Historial de incidentes del usuario |
| `idx_incident_reports_status_created` | `tourist_incident_reports (status, created_at DESC)` | Panel de fiscalización |

Notas:
- `idx_attractions_category_rating` del pedido queda cubierto por los dos primeros índices. Si el equipo prefiere conservar ese nombre, es un alias de documentación.
- **Verificar los nombres reales de columnas en los modelos** (por ejemplo, `usage_events` puede usar `timestamp` o `event_timestamp`) antes de generar la migración. Mi lista se basa en los documentos, no en el código.
- Los índices `CREATE INDEX CONCURRENTLY` en Alembic requieren `with op.get_context().autocommit_block():`. Para el volumen del MVP un índice normal también sirve, pero documentar la elección.
- Revisar la migración autogenerada a mano y probar `upgrade` y `downgrade`.

### F3 — ETag en `/catalog/attractions` y `/catalog/agencies` (304)

- Helper en `shared/http_cache.py`: serializa el payload de forma canónica, calcula `W/"<sha256[:32]>"` y compara con `If-None-Match` (varios valores y `*`). Si coincide, devuelve **304 sin cuerpo**, pero con `ETag` y `Cache-Control`.
- El hash va sobre el **cuerpo ya filtrado y paginado**, así que cada combinación de query params tiene su propio ETag. Esto garantiza que una agencia que pierde `is_validated` (RN-01) cambia el ETag automáticamente, cosa que un `max(updated_at)` no garantizaría.
- `Cache-Control: no-cache` (el cliente siempre revalida y ahorra ancho de banda).
- Añadir `expose_headers=["ETag"]` en el middleware CORS por si se consume desde web.
- Coste: la consulta a BD igual se ejecuta, y el ahorro es de payload. Si el catálogo crece, una clave de versión en Redis es la optimización futura.
- No tocar `router.py` más de lo necesario: el router recibe `Request` y delega en el helper.

### F4 — `Idempotency-Key` en `POST /emergency/sos` y `/emergency/reports`

- Header **opcional** (los clientes actuales no se rompen). Formato validado: `^[A-Za-z0-9_-]{8,64}$` (se espera un UUID v4 generado por la app).
- Persistencia: columnas `idempotency_key` (String(64), nullable) y `request_hash` (String(64), nullable) en `sos_reports` y `tourist_incident_reports`, con `UniqueConstraint(user_id, idempotency_key)`. PostgreSQL permite múltiples NULL, así que las peticiones sin clave no chocan.
- Semántica:
  - Misma clave y mismo payload → devuelve el recurso original con **200** y header `Idempotent-Replayed: true`. **No** se vuelve a encolar el despacho Celery.
  - Misma clave y payload distinto → **422**, `codigo: IDEMPOTENCY_KEY_REUTILIZADA`.
  - Carrera entre dos peticiones simultáneas → la restricción única lanza `IntegrityError`. Se hace rollback, se relee por clave y se aplica la regla anterior.
- El ámbito de la clave es por usuario (nunca global).
- El despacho se encola **después del commit** y solo en la creación real.

### F5 — Migraciones

Dos revisiones encadenadas desde `a50e921e5758`: (1) índices, (2) columnas y restricciones de idempotencia + índice único parcial de `provider_id`. Se prueba `upgrade head` y `downgrade -1` sobre una BD limpia y sobre una con datos.

### Definition of Done de Francis

- [ ] `EXPLAIN ANALYZE` documentado y sin Seq Scan en las consultas de la tabla de F2.
- [ ] Login Google verificado con tokens mockeados (CI) y una prueba manual con un token real.
- [ ] 304 y replay idempotente probados end-to-end.
- [ ] Un solo head de Alembic.

---

## Technical Design

### 1. Manejo de errores

Todas las excepciones nuevas heredan de `ErrorDeNegocio` (adaptar los fragmentos a la firma real de `src/core/exceptions.py`) y salen como `{ "detail": "...", "codigo": "..." }`.

| Excepción | HTTP | `codigo` | Módulo |
|---|---|---|---|
| `TokenSocialInvalidoError` | 401 | `TOKEN_SOCIAL_INVALIDO` | users |
| `EmailSocialNoVerificadoError` | 403 | `EMAIL_NO_VERIFICADO` | users |
| `ConsentimientoRequeridoError` | 428 | `CONSENTIMIENTO_REQUERIDO` | users |
| `ProveedorSocialNoSoportadoError` | 400 | `PROVEEDOR_NO_SOPORTADO` | users |
| `IdempotencyKeyInvalidaError` | 400 | `IDEMPOTENCY_KEY_INVALIDA` | shared |
| `IdempotencyKeyReutilizadaError` | 422 | `IDEMPOTENCY_KEY_REUTILIZADA` | shared |
| `StaleWeatherDataException` | 503 | `CLIMA_DESACTUALIZADO` | weather (existente) |
| `WeatherProviderUnavailableException` | 503 | `PROVEEDOR_CLIMA_NO_DISPONIBLE` | weather (existente) |

### 2. Francis — Strategy de autenticación social

```python
# src/modules/users/auth_strategies/base.py
from dataclasses import dataclass
from typing import Protocol


@dataclass(frozen=True, slots=True)
class IdentidadSocial:
    proveedor: str
    id_proveedor: str          # 'sub' de Google
    email: str
    email_verificado: bool
    nombre_completo: str


class EstrategiaAutenticacionSocial(Protocol):
    proveedor: str

    async def verificar(self, token: str) -> IdentidadSocial: ...
```

```python
# src/modules/users/auth_strategies/google.py
import anyio
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token

from src.modules.users.exceptions import (
    EmailSocialNoVerificadoError,
    TokenSocialInvalidoError,
)
from .base import IdentidadSocial

_EMISORES_VALIDOS = {"accounts.google.com", "https://accounts.google.com"}


class GoogleAuthStrategy:
    proveedor = "google"

    def __init__(self, client_ids: list[str]) -> None:
        self._client_ids = set(client_ids)

    async def verificar(self, token: str) -> IdentidadSocial:
        try:
            claims = await anyio.to_thread.run_sync(self._verificar_sync, token)
        except ValueError as exc:  # firma, expiración o formato inválidos
            raise TokenSocialInvalidoError() from exc

        if claims.get("iss") not in _EMISORES_VALIDOS or claims.get("aud") not in self._client_ids:
            raise TokenSocialInvalidoError()
        if claims.get("email_verified") is not True:
            raise EmailSocialNoVerificadoError()

        return IdentidadSocial(
            proveedor=self.proveedor,
            id_proveedor=str(claims["sub"]),
            email=str(claims["email"]).lower(),
            email_verificado=True,
            nombre_completo=str(claims.get("name") or claims["email"]),
        )

    @staticmethod
    def _verificar_sync(token: str) -> dict:
        # audience=None: la comprobación de 'aud' (varios client IDs) se hace arriba
        return id_token.verify_oauth2_token(token, google_requests.Request(), audience=None)
```

```python
# src/modules/users/schemas.py (añadidos)
from typing import Literal
from pydantic import BaseModel, Field

class GoogleLoginRequest(BaseModel):
    id_token: str = Field(min_length=20)
    preferred_language: Literal["es", "en"] | None = None
    acepta_politica_datos: bool = False

class TokenSocialResponse(TokenResponse):
    es_nuevo_usuario: bool
```

```python
# src/modules/users/router.py (solo recibe, delega y responde)
@router.post("/auth/login/google", response_model=TokenSocialResponse)
async def login_google(
    datos: GoogleLoginRequest,
    db: AsyncSession = Depends(obtener_bd),
) -> TokenSocialResponse:
    return await service.login_con_google(db, datos)
```

El servicio resuelve la estrategia desde el registro, ejecuta el flujo find-or-link-or-create, genera el JWT con `create_access_token` y devuelve `es_nuevo_usuario`. Inyectar el registro de estrategias como dependencia permite sustituirlo por un fake en los tests.

### 3. Francis — ETag

```python
# src/shared/http_cache.py
import hashlib
import json
from fastapi import Request, Response
from pydantic import BaseModel


def _calcular_etag(payload: BaseModel) -> str:
    canonico = json.dumps(payload.model_dump(mode="json"), sort_keys=True, separators=(",", ":"))
    return f'W/"{hashlib.sha256(canonico.encode()).hexdigest()[:32]}"'


def _coincide(if_none_match: str | None, etag: str) -> bool:
    if not if_none_match:
        return False
    candidatos = {c.strip() for c in if_none_match.split(",")}
    return "*" in candidatos or etag in candidatos


def responder_con_etag(request: Request, payload: BaseModel) -> Response:
    etag = _calcular_etag(payload)
    cabeceras = {"ETag": etag, "Cache-Control": "no-cache"}
    if _coincide(request.headers.get("if-none-match"), etag):
        return Response(status_code=304, headers=cabeceras)
    return Response(
        content=payload.model_dump_json(),
        media_type="application/json",
        headers=cabeceras,
    )
```

### 4. Francis — Idempotencia

```python
# src/shared/idempotency.py
import hashlib
import json
import re
from fastapi import Header
from pydantic import BaseModel
from src.shared.exceptions import IdempotencyKeyInvalidaError  # o core/exceptions

_PATRON = re.compile(r"^[A-Za-z0-9_-]{8,64}$")


def obtener_clave_idempotencia(
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
) -> str | None:
    if idempotency_key is not None and not _PATRON.fullmatch(idempotency_key):
        raise IdempotencyKeyInvalidaError()
    return idempotency_key


def calcular_hash_solicitud(payload: BaseModel) -> str:
    canonico = json.dumps(payload.model_dump(mode="json"), sort_keys=True)
    return hashlib.sha256(canonico.encode()).hexdigest()
```

Flujo en `emergency/service.py` (función privada de consulta por (`user_id`, `clave`) dentro del propio service, ya que ese módulo no tiene `repository.py`):

```python
async def crear_reporte_sos(
    db: AsyncSession, usuario_id: UUID, datos: SOSCreate, clave: str | None
) -> tuple[SOSReport, bool]:
    """Devuelve (reporte, repetido)."""
    huella = calcular_hash_solicitud(datos)
    if clave and (previo := await _buscar_por_clave(db, usuario_id, clave)):
        return _validar_repeticion(previo, huella), True

    reporte = SOSReport(user_id=usuario_id, **datos.model_dump(),
                        idempotency_key=clave, request_hash=huella)
    db.add(reporte)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        if clave and (previo := await _buscar_por_clave(db, usuario_id, clave)):
            return _validar_repeticion(previo, huella), True
        raise
    await db.refresh(reporte)
    despachar_sos.delay(str(reporte.id))   # solo en la creación real
    return reporte, False
```

El router usa 201 en creación y 200 con `Idempotent-Replayed: true` en repetición. La validación de RN-04 (coordenadas obligatorias) ocurre **antes** de consultar la clave.

### 5. Paulo — Contratos del recomendador

```python
# src/modules/weather/schemas.py (añadidos)
from enum import StrEnum
from typing import Literal
from pydantic import BaseModel, Field

class NivelVisibilidad(StrEnum):
    BUENA = "good"
    MODERADA = "moderate"
    BAJA = "poor"

class RecomendacionEnriquecida(BaseModel):
    summary: str = Field(min_length=10, max_length=300)
    climate_justification: str = Field(min_length=10, max_length=500)
    clothing: list[str] = Field(min_length=1, max_length=6)
    precautions: list[str] = Field(min_length=1, max_length=6)
    visibility_level: NivelVisibilidad
    suitability_score: float = Field(ge=0.0, le=1.0)
    language: Literal["es", "en"]
    source: Literal["gemini", "fallback"]
```

Orquestación (el router no conoce a Gemini):

```python
async def generar_recomendacion(ctx: ContextoRecomendacion) -> RecomendacionEnriquecida:
    if cacheada := await cache.obtener(ctx.clave_cache):
        return cacheada
    try:
        bruta = await asyncio.wait_for(_llamar_gemini(ctx), timeout=2.5)
        rec = RecomendacionEnriquecida.model_validate(bruta)
        _validar_idioma(rec, ctx.idioma)
    except (TimeoutError, ValidationError, ErrorProveedorIA, IdiomaIncorrectoError):
        rec = recomendar_determinista(ctx)              # < 150 ms, sin I/O
        calentar_cache.delay(ctx.clave_cache_serializada)
    rec = aplicar_guardarrailes(rec, ctx.alertas)       # alerta 'danger' => score <= 0.3
    await cache.guardar(ctx.clave_cache, rec, ttl=ctx.ttl_restante_snapshot)
    return rec
```

Sobre los 150 ms: ese es el coste del **cálculo** del fallback. La latencia total de una petición con Gemini caído incluye el timeout de 2.5 s, que sigue dentro del límite de 3 s de RNF-01 para fichas. Si el equipo necesita que *toda* la respuesta de fallback sea < 150 ms, la alternativa es servir el determinista de inmediato y calentar Gemini en segundo plano. Hay que decidirlo explícitamente.

### 6. Resumen de cambios de esquema

| Revisión | Contenido | Dueño |
|---|---|---|
| `rev_1_indices_sprint4` | 8 índices de F2 | Francis |
| `rev_2_idempotencia_oauth` | `idempotency_key`, `request_hash`, `UniqueConstraint`, índice único parcial `provider_id` | Francis |
| *(opcional)* `precipitation_mm` | Solo si se elige la opción B de P2 | Francis a pedido de Paulo |

### 7. Variables de entorno nuevas

`GOOGLE_CLIENT_IDS`, `GEMINI_API_KEY` (ya existente), `GEMINI_TIMEOUT_SECONDS=2.5`, `WEATHER_PROVIDER_TIMEOUT_SECONDS=3`. Actualizar `.env.example`, que hoy solo trae `URL_BASE_DATOS`.

---

## Testing Strategy

### Principios

- **0 regresiones:** los 119 tests actuales deben seguir verdes en cada PR (`pytest -q`).
- BD aislada `ika_travel_test`, fixtures async con `NullPool` (como ya está).
- **Ningún test por defecto llama a Google, Gemini ni a las APIs de clima.** Todo se mockea. Las pruebas con red real van con `@pytest.mark.live` y se ejecutan manualmente.
- Un solo head de Alembic (`alembic heads`) y `upgrade/downgrade` probados en CI.

### Francis (~18 tests) en `tests/modules/test_users.py`, `test_catalog.py`, `test_emergency.py`

**Google Login (8)**

1. Token válido de usuario nuevo con consentimiento → 200, usuario `tourist`, `es_nuevo_usuario=true`, JWT válido en `/users/me`.
2. Usuario nuevo sin consentimiento → 428 `CONSENTIMIENTO_REQUERIDO` y **no se crea fila**.
3. Usuario ya vinculado → 200, `es_nuevo_usuario=false`, sin duplicados.
4. Email existente registrado por correo → vincula `provider_id` sin crear otro usuario.
5. Token inválido o expirado → 401 `TOKEN_SOCIAL_INVALIDO`.
6. `aud` no permitido → 401.
7. `email_verified=false` → 403.
8. Cuenta social intentando login con email/password → 401 genérico (sin revelar existencia). Más: usuario inactivo → 403 (puede ser el 9.º).

**ETag (4)**

9. Primera petición devuelve `ETag`; la segunda con `If-None-Match` devuelve 304 sin cuerpo.
10. Crear o editar un atractivo cambia el ETag y devuelve 200.
11. Distintos query params dan distintos ETag.
12. **RN-01:** invalidar una agencia cambia el ETag de `/catalog/agencies` y ya no aparece.

**Idempotencia (6)**

13. Dos SOS con la misma clave y mismo payload → 1 fila, 2.ª respuesta 200 con `Idempotent-Replayed`.
14. Esa repetición **no** vuelve a invocar `despachar_sos.delay` (spy).
15. Misma clave y payload distinto → 422.
16. Sin header → comportamiento actual intacto (dos filas).
17. Clave con formato inválido → 400.
18. Misma clave en `/reports` con dos usuarios distintos → ambos se crean (ámbito por usuario). Carrera simulada con `asyncio.gather` (dos peticiones concurrentes → 1 fila).

**Índices (verificación)**

- Test de esquema que consulta `pg_indexes` y confirma la existencia de los índices de F2.
- Script o `EXPLAIN` documentado, no assert frágil sobre el plan en CI.

### Paulo (~16 tests) en `tests/modules/test_weather.py`, `test_weather_rn03.py`, `test_weather_ai.py`

**Alertas (≈ 5)**, parametrizadas por tabla: viento justo debajo, en y sobre cada umbral; viento alto en Huacachina **sin** alerta `paracas_wind`; UV 10/11/12; calor 36/37/40; upsert sin duplicados; desactivación al cesar la condición.

**Aggregator y caché RN-03 (≈ 5):** proveedor lento (timeout), un proveedor caído, los tres caídos → 503; hit y miss de Redis; snapshot de BD de 2 h sirve y de 7 h → 503 `CLIMA_DESACTUALIZADO`; lock anti-stampede (N lecturas concurrentes, 1 llamada al proveedor).

**Recomendador (≈ 6):**

| Escenario | Esperado |
|---|---|
| Sandboarding en Huacachina, 34 °C, viento 12 km/h, UV 11 | Score moderado, `clothing` con protección solar, `source="gemini"` (mock) |
| Lanchas en Paracas con `paracas_wind` danger | Guardarraíl: score ≤ 0.3, precaución prioritaria, aunque el mock de Gemini diga 0.9 |
| Sobrevuelo en Nazca, visibilidad baja | `visibility_level="poor"` |
| Ocucaje (enoturismo), calor alto | Recomienda horario fresco |
| Gemini con timeout | `source="fallback"` y respuesta válida |
| Gemini devuelve JSON inválido o idioma erróneo | Fallback; el resultado valida contra `RecomendacionEnriquecida` |

Más pruebas transversales: mismo escenario en `es` y `en` (campos en el idioma correcto), fallback p95 < 150 ms en 1 000 ejecuciones, y las 5 categorías PERTUR × los 5 lugares sin excepciones (matriz parametrizada).

### Totales

- 119 existentes + ~34 nuevos ≈ **150 tests** (meta mínima ≥ 135 cubierta con margen).
- Cobertura objetivo: ≥ 85 % en `weather/`, `users/auth_strategies/`, `shared/http_cache.py` y `shared/idempotency.py` (`pytest-cov`).

### Verificación de cierre (checklist de Paulo como QA/Lead)

- [ ] `pytest` completo en verde, sin tests `live`.
- [ ] `alembic upgrade head` y `downgrade -1` sobre BD limpia.
- [ ] `alembic heads` → 1 línea.
- [ ] `docs/optimizacion_bd.md` con los `EXPLAIN` antes/después.
- [ ] `.env.example` y `README` actualizados.
- [ ] Merge a `develop` y tag `sprint-4`.

---

## Decisiones pendientes de confirmación antes de arrancar

1. **Presupuesto del fallback:** ¿basta que el *cálculo* sea < 150 ms (diseño actual), o se exige que la respuesta completa sea < 150 ms?
2. **Vinculación de cuentas:** ¿se acepta vincular Google a una cuenta de email existente dejando `auth_provider=email`?
3. **Lluvia en el motor de alertas:** opción A (mapear `condition_code`) u opción B (nueva columna `precipitation_mm`).
4. **Umbrales de alertas:** ¿alguien puede validarlos con DIRCETUR/SENAMHI antes del cierre, o quedan como "propuestos" en la memoria?
5. **Numeración de RN:** unificar RN-03/RN-04 entre la especificación y el Cap. IV.
