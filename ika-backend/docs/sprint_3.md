# Sprint 3 — Traducción Bidireccional y Panel Analítico DIRCETUR

**Proyecto:** Ika Travel & Experience (backend FastAPI, monolito modular)
**Duración:** Semanas 6–7 (10 días hábiles) · **Rama base:** `develop`
**Equipo backend (exclusivo):** Francis (Desarrollador Backend) y Paulo (Lead Dev / Arquitecto)
**Línea base:** 76 tests pasando al 100% · migración Alembic vigente `86f8f1fc5a16`
**Documento hermano:** `plan_arquitectura_sprint3.md` (diseño técnico y código de referencia)

---

## 1. Objetivo del Sprint 3

### 1.1 Meta general
Entregar el módulo `translation` (RNF-04) y el Panel Analítico DIRCETUR (RF-06 / CUN07) con la suite en verde (**≥ 125 tests**, +49 sobre la línea base) y los contratos OpenAPI listos para el equipo Flutter.

### 1.2 Entregables de negocio

| ID | Entregable | Valor |
|---|---|---|
| E1 | **Frasebook oficial es↔en** (32 frases en 8 categorías, versionado con ETag) | El turista se comunica con operadores y guías en situaciones críticas (emergencia, salud, servicios formales) con textos revisados, sin depender del proveedor de IA. |
| E2 | **Traducción de texto libre es↔en** con caché Redis y degradación controlada | Cubre lo que el frasebook no prevé. El caché reduce latencia y costo; el fallback evita que una caída del proveedor deje al turista sin respuesta. |
| E3 | **Registro anónimo de eventos de uso** (`usage_events`) | Base de datos para la analítica, sin guardar texto traducido, IP ni identidad (Ley N° 29733). |
| E4 | **Endpoints analíticos `/admin/analytics/*`** protegidos con `dircetur_admin` | DIRCETUR obtiene idiomas demandados, preferencias, atractivos con mayor interés e incidencias de informalidad. |
| E5 | **Rate limiting reutilizable** (`core/rate_limit.py`) | Protege el endpoint de texto libre (que consume cuota de Gemini) sin exigir login (RN-02). |

### 1.3 Impacto
- **Turistas angloparlantes:** frases listas para usar en 8 contextos y traducción libre en < 3 s (RNF-01). Sostiene la hipótesis **HE2** (comprensión multilingüe) del Capítulo I.
- **DIRCETUR Ica:** el CUN07 pasa de requisito a tablero de datos agregados y anonimizados. Sostiene **OE4/HE4** y la fiscalización de informalidad (CUN06).
- **Equipo Flutter:** el contrato de `/translation/phrases` con ETag es la base del almacenamiento offline del Sprint 4 (RN-04 del backend/OE3).

### 1.4 Trazabilidad

| Entregable | RF/RNF | CUN | OE / HE |
|---|---|---|---|
| E1, E2 | RNF-04 | Transversal | OE2 / HE2 |
| E3, E4 | RF-06 | CUN07 | OE4 / HE4 |
| E4 (incidencias) | RF-05, RF-06 | CUN06, CUN07 | Fiscalización DIRCETUR |
| E5 | RNF-01, RNF-03 | — | Calidad de servicio |

### 1.5 Métricas de éxito (medibles)

| Métrica | Meta |
|---|---|
| Suite `pytest` | ≥ 125 tests, 0 fallos, 0 regresiones sobre los 76 previos |
| `POST /translation/translate` (frase oficial o caché) | p95 < 150 ms |
| `POST /translation/translate` (proveedor) | p95 < 3.0 s (RNF-01) |
| `GET /admin/analytics/summary` con 100 000 eventos | p95 < 1.5 s sin caché · < 200 ms con caché |
| Cobertura de líneas en `translation/` y `analytics/` | ≥ 85 % |
| Datos personales en `usage_events` | 0 columnas con IP, `user_id` o texto libre |

### 1.6 Fuera de alcance
- CRUD de contenidos del panel (parte de RF-06; se planifica aparte).
- Detección automática de idioma y más idiomas (RNF-04 fija es/en).
- Sincronización offline (Sprint 4); aquí solo se deja el contrato con ETag.
- Reservas, pagos o e-commerce (exclusión estricta del producto).

---

## 2. División de trabajo exclusiva

### 2.1 Reglas de coordinación
1. Ramas: `feature/translation-module` (Francis) y `feature/analytics-dircetur` (Paulo), ambas desde `develop`. Prohibido commitear en `develop` o `main`.
2. **Revisión cruzada obligatoria:** Paulo revisa los PRs de Francis y Francis los de Paulo. Paulo hace el merge final tras el visto bueno del otro.
3. Commits convencionales en español (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`), un commit por tarea. Los cambios grandes llevan mensaje detallado.
4. **Dependencia crítica:** Paulo entrega **P-1** (modelo `UsageEvent` + migración + `UsageRecorder`) el **día 2**. Francis integra el registro de eventos en F-5 (día 6).
5. Francis agrega sus métodos de incidencias en `analytics/repository.py` y `analytics/service.py` solo en la sección `# --- Incidentes ---` (al final del archivo) para evitar conflictos de merge.

### 2.2 Resumen de asignación

| Tarea | Responsable | SP | Días |
|---|---|---|---|
| F-0 Pre-flight | Francis + Paulo | 1 | 1 |
| F-1 Esquemas, enums y frasebook | Francis | 3 | 1–2 |
| F-2 Normalización y caché Redis | Francis | 3 | 2–3 |
| F-3 Proveedor Gemini + servicio | Francis | 5 | 3–4 |
| F-4 Router, dependencias y contratos | Francis | 3 | 4–5 |
| F-5 Integración de eventos y rate limit | Francis | 2 | 6 |
| F-6 Endpoint analítico de incidencias | Francis | 5 | 7–8 |
| F-7 Tests Francis (29) | Francis | 5 | transversal |
| P-1 Modelo `UsageEvent`, migración, recorder | Paulo | 5 | 1–2 |
| P-2 Excepciones, rate limiter, config | Paulo | 3 | 2 |
| P-3 Analytics: idiomas, preferencias, top atractivos | Paulo | 8 | 3–6 |
| P-4 Instrumentación del catálogo | Paulo | 3 | 6 |
| P-5 Resumen consolidado y caché | Paulo | 3 | 7 |
| P-6 Tests Paulo (20), conftest, CI | Paulo | 5 | transversal |
| P-7 Revisión cruzada, docs, merge | Paulo | 3 | 9–10 |
| **Total** | | **54 SP** | |

### 2.3 Cronograma

| Día | Francis | Paulo |
|---|---|---|
| 1 | F-0, F-1 | F-0, P-1 (modelo) |
| 2 | F-1, F-2 | P-1 (migración + recorder) → **PR + merge**, P-2 |
| 3 | F-2, F-3 | P-3 (idiomas) |
| 4 | F-3, F-4 | P-3 (preferencias) |
| 5 | F-4, tests T-01…T-25 | P-3 (top atractivos) |
| 6 | F-5 (eventos + rate limit) | P-3 (tests), P-4 |
| 7 | F-6 (queries) | P-5 |
| 8 | F-6 (service + router + tests) | P-5 (tests), P-6 |
| 9 | Revisión cruzada, correcciones | P-7 revisión de PR de Francis |
| 10 | Regresión completa, DoD, demo | Merge a `develop`, tag `sprint-3` |

### 2.4 Tareas de Francis (Desarrollador Backend)

#### F-0 · Pre-flight (compartida con Paulo, día 1)
Verificar los supuestos listados en la sección 0 de `plan_arquitectura_sprint3.md`. Cada discrepancia se corrige en el import o la firma correspondiente antes de escribir lógica.

#### F-1 · Esquemas, enums y frasebook
- **Archivos:** `translation/schemas.py`, `translation/phrasebook.py`, `translation/normalization.py`.
- Enums `Language` (`es`, `en`), `PhraseCategory` (8 valores) y `TranslationOrigin` (`official_phrase`, `cache`, `cache_fallback`, `provider`).
- DTOs `TranslationRequest`, `TranslationResponse`, `PhraseItem`, `PhrasebookResponse`. Validación Pydantic v2: texto entre 1 y 500 caracteres, idiomas distintos, espacios recortados.
- `Phrasebook` inmutable con índice normalizado y `version` (hash SHA-256 de 12 caracteres) usada como ETag. Falla al importar si existen frases duplicadas.
- **Regla de negocio:** el contenido del frasebook es informativo; no incluye frases de reserva o pago (exclusión del producto).

#### F-2 · Normalización y caché Redis
- **Archivos:** `translation/cache.py`, `translation/normalization.py`.
- Dos normalizadores: `normalize_for_lookup` (casefold, sin signos extremos, para el frasebook) y `normalize_for_cache` (NFKC + espacios colapsados, **conserva mayúsculas**).
- Clave: `traduccion:v1:{src}:{dst}:{sha256}`. Clave de respaldo: `traduccion:respaldo:v1:…`.
- TTL: 7 días (principal) y 30 días (respaldo para caída del proveedor).
- Si Redis falla (`RedisError`) se registra una advertencia y se continúa sin caché.

#### F-3 · Proveedor Gemini y servicio
- **Archivos:** `translation/providers.py`, `translation/service.py`, `translation/exceptions.py`.
- Protocolo `TranslationProvider` con `GeminiTranslationProvider` (producción) y `MockTranslationProvider` (tests).
- Prompt de sistema fijo con `temperature=0`; el texto del turista se trata solo como dato. Timeout de 8 s; la salida vacía o desproporcionada lanza `InvalidTranslationResponseException`.
- Flujo de `TranslationService.translate`: **frasebook → caché → proveedor → caché de respaldo → 503**. No se devuelven traducciones "aproximadas" por fuzzy matching, porque un error en un contexto SOS o de salud es inaceptable.

#### F-4 · Router, dependencias y contratos
- **Archivos:** `translation/router.py`, `translation/dependencies.py`, registro en `main.py`.
- `POST /translation/translate` (público, con rate limit) y `GET /translation/phrases` (público, con `ETag` / `If-None-Match` → 304 y `Cache-Control`).
- Router sin lógica: solo delega en servicio y funciones puras.

#### F-5 · Integración de eventos y rate limit
- Inyectar `UsageRecorder` en `TranslationService` y registrar un evento por traducción (idiomas y origen; **nunca el texto**).
- Aplicar `limit_translations` (30 solicitudes/minuto por IP, configurable) al endpoint de texto libre.

#### F-6 · Endpoint analítico de incidencias (RF-05 / RF-06 / CUN06–07)
- **Endpoint:** `GET /admin/analytics/incidents?date_from=&date_to=`.
- Queries agregadas sobre `TouristIncidentReport`: totales por tipo y estado, serie diaria (zona horaria America/Lima, con días en cero rellenados), tasa de resolución, tiempo promedio de resolución y top 10 de agencias reportadas por informalidad.
- Sin `N+1`: cada métrica es una sola consulta agregada (`GROUP BY`).

#### F-7 · Tests de Francis (29 casos: T-01…T-26 y A-13…A-15)
Ver sección 4.

### 2.5 Tareas de Paulo (Lead Dev / Arquitectura)

#### P-1 · Modelo `UsageEvent`, migración y recorder (día 2, bloqueante)
- **Archivos:** `analytics/models.py`, `analytics/recorder.py`, `shared/usage_events.py`, migración Alembic, `alembic/env.py`.
- Tabla `usage_events` anonimizada con índices `(event_type, created_at)` y `(attraction_id)`; FK con `ON DELETE SET NULL`.
- Protocolo `UsageRecorder` en `shared/` (desacopla `translation` y `catalog` de `analytics`). `PostgresUsageRecorder` usa su propia sesión; su único `try/except` está acotado a `SQLAlchemyError` y registra en logs.
- Migración reversible; `alembic upgrade head` y `downgrade -1` verificados.

#### P-2 · Excepciones, rate limiter y configuración
- **Archivos:** `core/rate_limit.py`, `core/exceptions.py` (`RateLimitExceededException`), `core/config.py`, `.env.example`.
- `limit_requests(...)`: `SET NX EX` + `INCR` en transacción Redis (`MULTI`); falla abierto (con log) si Redis no responde.

#### P-3 · Analytics: idiomas, preferencias y top atractivos
- **Archivos:** `analytics/{router,service,repository,schemas,dependencies,exceptions}.py`.
- `GET /admin/analytics/languages`: usuarios por idioma preferido, traducciones por idioma destino, idioma de interfaz de las consultas y desglose por origen (mide la tasa de aciertos del caché).
- `GET /admin/analytics/preferences`: preferencias registradas (expansión del arreglo JSON de `users.preferences` con `json_array_elements_text`) y categorías más buscadas (eventos).
- `GET /admin/analytics/attractions/top?limit=&sort_by=`: vistas, favoritos y reseñas **por periodo**, calculados con subconsultas agregadas para evitar el producto cartesiano.
- `DateRange` como dependencia: `date_from`/`date_to`, valores por defecto de los últimos 30 días, máximo 366 días.

#### P-4 · Instrumentación del catálogo
- Agregar `dependencies=[Depends(track_attraction_search)]` a `GET /catalog/attractions` y `Depends(track_attraction_view)` a `GET /catalog/attractions/{attraction_id}`.
- El registro corre como `BackgroundTask` (después de la respuesta y solo en respuestas exitosas). Un fallo de analítica nunca rompe el catálogo.

#### P-5 · Resumen consolidado y caché
- `GET /admin/analytics/summary`: KPIs más bloques de idiomas, preferencias, top 5 y incidencias.
- Caché Redis de 300 s por rango. Las consultas se ejecutan **secuencialmente** porque una `AsyncSession` no admite concurrencia.

#### P-6 · Tests, conftest y CI
- Fixtures: `fakeredis`, override de `get_session_factory`, proveedor mock y fábricas de datos.
- Agregar `fakeredis`, `mypy` y `ruff` a dependencias de desarrollo. Pipeline: `ruff check`, `mypy --strict`, `pytest --cov`.

#### P-7 · Revisión cruzada, documentación y cierre
- Revisar los PRs de Francis con foco en seguridad (inyección de prompt, rate limit, anonimización).
- Actualizar `estructura_backend.md`, `modelo_datos.md` y `roadmap-ika-travel.md`. Etiquetar `sprint-3` tras el merge.

### 2.6 Riesgos

| Riesgo | Prob. | Mitigación |
|---|---|---|
| Cuota o latencia del proveedor Gemini | Media | Frasebook y caché primero, timeout de 8 s, rate limit, fallback a caché de respaldo |
| Nombres de enums/tablas distintos a los supuestos | Media | F-0 el día 1; el ajuste queda aislado en imports |
| Contrato de `ErrorDeNegocio` distinto | Baja | F-0; adaptar solo las subclases |
| Conflictos de merge en `analytics/*` | Media | Secciones separadas por responsable, PR de P-1 el día 2 |
| `updated_at` no equivale a la fecha de resolución | Cierta | Limitación documentada; recomendar `resolved_at` para el Sprint 4 |

---

## 3. Criterios de aceptación (Gherkin)

### 3.1 `POST /translation/translate`

```gherkin
Característica: Traducción bidireccional es↔en (RNF-04)

  Escenario: Una frase oficial se resuelve sin invocar al proveedor
    Dado que el frasebook contiene "¿Habla inglés?" con traducción "Do you speak English?"
    Cuando envío POST /translation/translate con texto "¿habla inglés?", source_lang "es" y target_lang "en"
    Entonces recibo 200
    Y translated_text es "Do you speak English?"
    Y origin es "official_phrase"
    Y el proveedor no fue invocado

  Escenario: Un texto libre se traduce con el proveedor y se guarda en caché
    Dado que el texto no existe en el frasebook ni en Redis
    Cuando envío POST /translation/translate con un texto libre válido
    Entonces recibo 200 con origin "provider"
    Y la traducción queda en Redis con TTL de 7 días y copia de respaldo de 30 días

  Escenario: Una segunda solicitud idéntica se sirve desde caché
    Dado que el texto ya fue traducido
    Cuando envío la misma solicitud
    Entonces recibo 200 con origin "cache"
    Y el proveedor se invocó exactamente una vez en total

  Escenario: El proveedor cae pero existe copia de respaldo
    Dado que la clave principal expiró y la de respaldo existe
    Cuando el proveedor lanza TranslationProviderUnavailableException
    Entonces recibo 200 con origin "cache_fallback"

  Escenario: El proveedor cae y no hay caché
    Cuando el proveedor falla y no existe copia alguna
    Entonces recibo 503 con codigo "TRADUCCION_PROVEEDOR_NO_DISPONIBLE"

  Escenario: Redis no responde
    Dado que Redis lanza RedisError
    Cuando envío una solicitud válida
    Entonces recibo 200 con origin "provider" y se registra una advertencia

  Esquema del escenario: Entradas inválidas
    Cuando envío texto "<texto>", source_lang "<origen>" y target_lang "<destino>"
    Entonces recibo 422
    Ejemplos:
      | texto               | origen | destino |
      |                     | es     | en      |
      | (501 caracteres)    | es     | en      |
      | Hola                | es     | es      |
      | Bonjour             | fr     | en      |

  Escenario: Límite de solicitudes por IP
    Dado un límite de 30 solicitudes por minuto
    Cuando una IP envía la solicitud número 31 dentro de la ventana
    Entonces recibo 429 con codigo "LIMITE_SOLICITUDES_EXCEDIDO"

  Escenario: Acceso anónimo (RN-02)
    Cuando envío una solicitud sin token
    Entonces no recibo 401
```

### 3.2 `GET /translation/phrases`

```gherkin
Característica: Frasebook oficial versionado

  Escenario: Listado completo
    Cuando consulto GET /translation/phrases
    Entonces recibo 200 con 32 frases, 8 categorías y un campo version
    Y la cabecera ETag está presente

  Escenario: Filtro por categoría
    Cuando consulto GET /translation/phrases?category=emergencia
    Entonces solo recibo frases de la categoría "emergencia"

  Escenario: Categoría inexistente
    Cuando consulto GET /translation/phrases?category=inexistente
    Entonces recibo 422

  Escenario: Revalidación con ETag
    Dado que obtuve el ETag de una respuesta previa
    Cuando repito la consulta con If-None-Match igual a ese ETag
    Entonces recibo 304 sin cuerpo
```

### 3.3 Endpoints `/admin/analytics/*`

```gherkin
Característica: Panel analítico DIRCETUR (RF-06 / CUN07)

  Escenario: Acceso restringido
    Cuando consulto cualquier endpoint de /admin/analytics sin token
    Entonces recibo 401
    Cuando lo consulto con un token de rol "tourist"
    Entonces recibo 403
    Cuando lo consulto con un token de rol "dircetur_admin"
    Entonces recibo 200

  Escenario: Idiomas demandados
    Dado 3 usuarios activos con idioma "en", 1 con "es" y 1 inactivo con "en"
    Y 4 traducciones hacia "en" y 1 hacia "es" dentro del rango
    Cuando consulto GET /admin/analytics/languages
    Entonces preferred_language_users contiene en=3 y es=1
    Y translation_target_languages contiene en=4 y es=1
    Y los porcentajes de cada lista suman 100

  Escenario: Preferencias turísticas
    Dado un usuario con preferencias ["aventura","relax"] y otro con ["aventura"]
    Cuando consulto GET /admin/analytics/preferences
    Entonces "aventura" aparece con 2 y "relax" con 1

  Escenario: Top de atractivos sin duplicación de conteos
    Dado un atractivo con 3 favoritos y 2 reseñas en el periodo
    Cuando consulto GET /admin/analytics/attractions/top?sort_by=favorites
    Entonces el atractivo muestra favorites=3 y reviews=2

  Escenario: Límite fuera de rango
    Cuando consulto GET /admin/analytics/attractions/top?limit=51
    Entonces recibo 422

  Escenario: Estadísticas de incidencias
    Dado 5 reportes (2 informal_service, 1 resolved) en el periodo y 0 fuera de él
    Cuando consulto GET /admin/analytics/incidents
    Entonces total es 5
    Y la serie diaria cubre todos los días del rango, incluidos los de valor 0
    Y resolution_rate es 20.0

  Escenario: Periodo sin incidencias
    Cuando consulto incidencias de un rango vacío
    Entonces total es 0 y resolution_rate es 0.0 (sin división por cero)

  Esquema del escenario: Rango de fechas inválido
    Cuando consulto con date_from "<desde>" y date_to "<hasta>"
    Entonces recibo 400 con codigo "<codigo>"
    Ejemplos:
      | desde      | hasta      | codigo                  |
      | 2026-03-10 | 2026-03-01 | RANGO_FECHAS_INVALIDO   |
      | 2025-01-01 | 2026-03-01 | RANGO_FECHAS_EXCEDIDO   |

  Escenario: Resumen consolidado con caché
    Cuando consulto GET /admin/analytics/summary dos veces con el mismo rango
    Entonces la segunda respuesta proviene de Redis sin consultar la base de datos
```

### 3.4 Registro de eventos de uso

```gherkin
Característica: Eventos de uso anonimizados (Ley N° 29733)

  Escenario: Búsqueda en el catálogo
    Cuando consulto GET /catalog/attractions?category=aventura
    Entonces se crea un UsageEvent "attraction_search" con category_slug "aventura"

  Escenario: Fallo del registro de analítica
    Dado que la base de eventos no está disponible
    Cuando consulto el catálogo
    Entonces recibo 200 con el listado y se registra una advertencia

  Escenario: Sin datos personales
    Entonces la tabla usage_events no tiene columnas de IP, user_id ni texto libre
```

---

## 4. Plan de pruebas (`pytest`)

**Meta:** 76 existentes + **49 nuevos = 125 tests**, todos verdes. Base de datos aislada `ika_travel_test`, motor `NullPool` y fixtures async existentes. Ningún test llama a Gemini ni a un Redis real (`MockTranslationProvider` + `fakeredis`).

### 4.1 Francis — `tests/modules/test_translation.py` (26) y `tests/modules/test_analytics_incidents.py` (3)

| ID | Tipo | Caso | Verificación clave |
|---|---|---|---|
| T-01 | Unit | Normalización | NFKC, espacios colapsados, mayúsculas preservadas en caché |
| T-02 | Unit | Clave de caché estable | Variantes de espacios producen la misma clave |
| T-03 | Unit | Clave por par de idiomas | es→en ≠ en→es |
| T-04 | Unit | Frase oficial exacta | Sin llamada al proveedor |
| T-05 | Unit | Frase oficial con mayúsculas y signos | `"¡HABLA INGLÉS!"`, mismo resultado |
| T-06 | Unit | Caché hit | Proveedor no invocado |
| T-07 | Unit | Caché miss | Proveedor invocado, TTL 7d y respaldo 30d |
| T-08 | Unit | Redis caído | Continúa con el proveedor y registra advertencia |
| T-09 | Unit | Proveedor falla sin caché | `TranslationProviderUnavailableException` |
| T-10 | Unit | Proveedor falla con respaldo | `origin == cache_fallback` |
| T-11 | Unit | Salida vacía o desproporcionada | `InvalidTranslationResponseException` |
| T-12 | Unit | Timeout del proveedor | Mapeado a excepción de dominio |
| T-13 | API | Traducción de frase oficial | 200 y `origin=official_phrase` |
| T-14 | API | Texto libre | 200 y `origin=provider` |
| T-15 | API | Segunda llamada idéntica | `origin=cache`, 1 sola invocación al proveedor |
| T-16 | API | Texto vacío | 422 |
| T-17 | API | Texto de 501 caracteres | 422 |
| T-18 | API | Idiomas iguales | 422 |
| T-19 | API | Idioma no soportado | 422 |
| T-20 | API | Acceso sin token | 200 (RN-02) |
| T-21 | API | Rate limit | Solicitud 3 con límite 2 → 429 `LIMITE_SOLICITUDES_EXCEDIDO` |
| T-22 | API | `GET /phrases` | 200, 32 frases, 8 categorías, ETag |
| T-23 | API | Filtro por categoría y categoría inválida | Solo la categoría pedida; inválida → 422 |
| T-24 | API | `If-None-Match` | 304 sin cuerpo |
| T-25 | Unit | Integridad del frasebook | IDs únicos, es/en no vacíos, ≥ 4 frases por categoría, sin duplicados normalizados |
| T-26 | API | Evento de traducción | Se crea `UsageEvent` con idiomas y origen, sin el texto |
| A-13 | API | Incidencias por tipo y estado | Conteos exactos con datos sembrados |
| A-14 | API | Periodo vacío | `total=0`, `resolution_rate=0.0`, serie en ceros |
| A-15 | API | Top agencias informales | Ordenado por conteo, agrupado sin distinguir mayúsculas |

### 4.2 Paulo — `tests/modules/test_analytics.py` (17), `tests/modules/test_usage_events.py` (3)

| ID | Tipo | Caso | Verificación clave |
|---|---|---|---|
| A-01 | API | `summary` como admin | 200 y estructura completa |
| A-02 | API | Sin token | 401 |
| A-03 | API | Rol `tourist` | 403 |
| A-04 | API | Idiomas preferidos | Conteos y porcentajes correctos |
| A-05 | API | Usuarios inactivos | Excluidos del conteo |
| A-06 | API | Traducciones por rango | Respeta `date_from`/`date_to` (límites en America/Lima) |
| A-07 | API | Preferencias JSON | Usuario con 2 preferencias suma en ambas |
| A-08 | API | Preferencias no-array o vacías | Ignoradas sin error SQL |
| A-09 | API | Top por favoritos | Orden correcto |
| A-10 | API | Top por vistas | Orden correcto |
| A-11 | API | Sin producto cartesiano | 3 favoritos y 2 reseñas → conteos exactos |
| A-12 | API | `limit=51` | 422 |
| A-16 | API | `date_from > date_to` | 400 `RANGO_FECHAS_INVALIDO` |
| A-17 | API | Rango mayor a 366 días | 400 `RANGO_FECHAS_EXCEDIDO` |
| A-21 | API | Caché del resumen | Segunda llamada sin consultas SQL |
| A-23 | Unit | Rate limiter | `SET NX EX`+`INCR`, TTL fijado y fail-open si Redis falla |
| A-18 | API | Evento de búsqueda | `category_slug` guardado |
| A-19 | API | Evento de vista | `attraction_id` guardado; no se registra en respuestas 404 |
| A-20 | Unit | Anonimización | El modelo no expone IP, `user_id` ni texto libre |
| A-22 | API | Fallo del recorder | El catálogo responde 200 y se registra la advertencia |

### 4.3 Reglas de ejecución
- Comando: `pytest -q --cov=src/modules/translation --cov=src/modules/analytics --cov=src/core/rate_limit --cov-fail-under=85`.
- La suite completa se ejecuta antes de cada PR y tras cada merge a `develop`.
- Todo test async usa los fixtures existentes (`conftest.py`); los overrides nuevos se registran en un fixture `autouse` para no alterar los 76 tests previos.
- Verificación manual de migración: `alembic upgrade head && alembic downgrade -1 && alembic upgrade head`.

---

## 5. Estimación y Definición de Hecho (DoD)

**Capacidad:** 54 SP en 10 días entre 2 desarrolladores (≈ 27 SP por persona; Francis 27, Paulo 27). Hay un colchón de 1 día para correcciones de revisión.

### 5.1 Checklist de calidad de código
- [ ] Todas las funciones, métodos y atributos con type hints; `mypy --strict` sin errores en `src/modules/translation`, `src/modules/analytics`, `src/core/rate_limit.py` y `src/shared/usage_events.py`.
- [ ] `ruff check` sin advertencias; sin `print`, sin código comentado y sin TODOs.
- [ ] `router.py` sin lógica de negocio ni SQL; `service.py` con la lógica; `repository.py` con las queries; `schemas.py` solo con Pydantic.
- [ ] Todas las excepciones de dominio heredan de `ErrorDeNegocio` y devuelven `{ "detail", "codigo" }`.
- [ ] Único `try/except` permitido sin relanzar: acotado a `RedisError` / `SQLAlchemyError`, con `logger.warning(..., exc_info=True)` (degradación controlada, no silencio).
- [ ] Ninguna respuesta de analítica expone `user_id`, correos, IP, texto traducido ni datos personales.
- [ ] Ningún endpoint nuevo introduce reservas, pagos ni flujos transaccionales.
- [ ] Endpoints documentados en OpenAPI (resumen, descripción, `responses` con 4xx/5xx relevantes y ejemplos).

### 5.2 Checklist de pruebas y datos
- [ ] 125 tests pasando; 0 tests omitidos (`skip`) o marcados `xfail` sin justificación.
- [ ] Cobertura ≥ 85 % en módulos nuevos.
- [ ] Migración revisada a mano, reversible y con una sola cabeza (`alembic heads` muestra 1 revisión).
- [ ] `alembic/env.py` y `conftest.py` importan `analytics.models`.
- [ ] `.env.example` actualizado con las variables nuevas.

### 5.3 Checklist de Git y revisión
- [ ] Ramas `feature/translation-module` y `feature/analytics-dircetur`; PR a `develop`.
- [ ] Commits convencionales en español, uno por tarea. Ejemplos:
  - `feat: agregar frasebook oficial es-en con versionado por hash`
  - `feat: implementar caché Redis con respaldo para traducciones`
  - `feat: crear tabla usage_events y registrador anónimo de eventos`
  - `feat: exponer endpoints analíticos de DIRCETUR protegidos por rol`
  - `test: cubrir rate limiter y degradación sin Redis`
- [ ] Mensaje detallado (`-m` con descripción y fecha) en commits grandes (migración, servicio de traducción, módulo analytics).
- [ ] Revisión cruzada aprobada por ambos; merge final de Paulo.
- [ ] `estructura_backend.md`, `modelo_datos.md` y `roadmap-ika-travel.md` actualizados.
- [ ] Demo con el equipo Flutter: contratos de `/translation/*` y `/admin/analytics/*` entregados.
