# Guía y Documentación Integral del Backend - Ika Travel Platform

Esta guía detalla la arquitectura de software, patrones de diseño, estructura modular, flujos de ejecución paso a paso, stack tecnológico y mecanismos de resiliencia aplicados en el backend de **Ika Travel & Experience**.

---

## 1. Visión General del Sistema

El backend de **Ika Travel** es una plataforma orientada a servicios RESTful y asíncronos diseñada para brindar a turistas y operadores turísticos una experiencia enriquecida en la región de Ica, Perú (Huacachina, Paracas, Nazca, Cañón de los Perdidos, Chincha y valles vitivinícolas).

El sistema centraliza:
1. **Recomendaciones inteligentes** con Inteligencia Artificial generativa (**Google Gemini Flash**) y guardarrailes deterministas para la seguridad física del turista ante fenómenos climáticos locales (Viento Paracas, Radiación UV extrema).
2. **Catálogo turístico y reservas** con optimización por índices compuestos y caché HTTP mediante **ETag (RFC 7232)**.
3. **Módulo de emergencias y reportes SOS** con garantías de **Idempotencia (RFC 9535)** mediante la cabecera `Idempotency-Key`.
4. **Traducción semántica bilingüe y frasebook oficial** versionado para turistas angloparlantes.
5. **Autenticación robusta y extensible** soportando credenciales locales (JWT + Bcrypt) y login social federado mediante el **Patrón Strategy (Google OAuth)**.

---

## 2. Arquitectura de Software

### 2.1. Arquitectura Modular y en Capas (Layered Modular Architecture)

El backend sigue una arquitectura **Modular Monolithic** con estricta **Separación de Responsabilidades (SoC)** dentro de cada módulo del dominio. Cada módulo (`src/modules/<dominio>`) se organiza de forma autosuficiente respetando el principio de diseño en capas:

```
                  ┌───────────────────────────────────────────┐
                  │          Cliente Web / Móvil              │
                  └─────────────────────┬─────────────────────┘
                                        │ HTTP / JSON
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CAPA DE ENTRADA (Router)                          │
│  - FastAPI APIRouter con inyección de dependencias (Depends)               │
│  - Validación sintáctica y esquemas Pydantic                                │
│  - Middleware de CORS, control de cabeceras ETag e Idempotency-Key          │
└───────────────────────────────────────┬─────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CAPA DE NEGOCIO (Service)                         │
│  - Reglas de negocio puras, scoring meteorológico y control de alertas       │
│  - Orquestación de IA (Gemini Engine) y validación de guardarrailes         │
│  - Lógica de idempotencia, deduplicación y anti-stampede con Redis          │
└──────────────────┬────────────────────────────────────┬─────────────────────┘
                   │                                    │
                   ▼                                    ▼
┌───────────────────────────────────────┐  ┌──────────────────────────────────┐
│      CAPA DE PERSISTENCIA (Data)      │  │     CAPA DE INTEGRACIÓN (Adapters│
│  - Repositorios SQLAlchemy asíncronos │  │  - Open-Meteo, OpenWeather, etc. │
│  - Modelos ORM relacionales (Postgres)│  │  - Google OAuth / Gemini SDK     │
│  - Caché y Locks distribuidos (Redis) │  │  - Resiliencia con Tenacity      │
└───────────────────────────────────────┘  └──────────────────────────────────┘
```

### 2.2. Patrones de Diseño Aplicados

1. **Patrón Estrategia (Strategy Pattern):**
   - Utilizado en la autenticación social (`src/modules/users/auth_strategies/`). Permite autenticar mediante diferentes proveedores de identidad (Google, Facebook, Apple) compartiendo un contrato común (`SocialAuthStrategy`) sin modificar el servicio de usuarios.
2. **Patrón Adaptador (Adapter Pattern):**
   - Utilizado en el módulo de clima (`src/modules/weather/adapters/`). Desacopla la lógica de negocio de los proveedores externos (Open-Meteo, OpenWeatherMap, WeatherAPI). Si la API de un proveedor cambia, únicamente se modifica su adaptador.
3. **Patrón Guardarrail / Sanitizador Post-IA (Post-AI Safety Guardrail):**
   - Garantiza que la salida generativa del LLM no vulnere la seguridad física del turista. Si existen alertas críticas activas (ej. Viento Paracas de alta severidad), el guardarrail sobreescribe el nivel a `"no_recomendado"` y limita el score a $\le 0.30$.
4. **Patrón Cerrojo Anti-Estampida (Anti-Stampede Mutex Lock):**
   - En el consumo de APIs meteorológicas e inferencias costosas de IA, se implementa un bloqueo en Redis (`SET NX EX`) que evita que 100 usuarios concurrentes disparen 100 llamadas simultáneas a APIs externas al vencer la caché.
5. **Patrón Inyección de Dependencias (Dependency Injection):**
   - FastAPI `Depends()` se utiliza de forma ubicua para inyectar sesiones de base de datos (`AsyncSession`), clientes Redis, servicios y proveedores autenticados.

---

## 3. Stack Tecnológico

| Componente | Tecnología | Versión | Propósito |
| :--- | :--- | :--- | :--- |
| **Framework Web** | FastAPI | `>=0.100.0` | API asíncrona de alto rendimiento, validación con Pydantic y generación automática de OpenAPI/Swagger. |
| **Servidor ASGI** | Uvicorn | `>=0.23.0` | Servidor ASGI para ejecución asíncrona con event loop `uvloop`. |
| **Base de Datos Relacional** | PostgreSQL | `16` | Persistencia relacional ACID, soporte de tipos UUID, arrays e índices B-tree/GIST. |
| **ORM / Driver** | SQLAlchemy 2.0 + Asyncpg | `>=2.0.0` | Acceso a datos relacionales 100% asíncrono y no bloqueante. |
| **Migraciones de Esquema** | Alembic | `>=1.11.0` | Control de versiones evolutivo de la base de datos con validación de grafo único. |
| **Caché y Locks** | Redis | `7` | Almacenamiento clave-valor de alta velocidad, caché de 30 minutos y cerrojos distribuidos. |
| **Inteligencia Artificial** | Google GenAI SDK | `gemini-flash-latest` | Generación de narrativas climáticas contextualizadas para turistas mediante prompts estructurados XML. |
| **Autenticación** | PyJWT + Passlib + Google Auth | — | Tokens JWT Bearer stateless, hashing seguro Bcrypt y verificación de tokens OAuth Google. |
| **Cliente HTTP Asíncrono**| HTTPX | `>=0.27.0` | Consumo asíncrono no bloqueante de servicios meteorológicos externos y LLMs. |
| **Resiliencia** | Tenacity | `>=8.2.0` | Reintentos exponenciales con jitter ante fallos transitorios de red. |
| **Testing** | Pytest + Pytest-Asyncio | — | Suite automatizada de pruebas unitarias y de integración (176 tests). |

---

## 4. Estructura de Directorios del Backend (`ika-backend`)

```text
ika-backend/
├── alembic/                      # Migraciones de base de datos
│   ├── env.py                    # Configuración asíncrona de SQLAlchemy en Alembic
│   └── versions/                 # Scripts de migración versionados
│       ├── f1a2b3c4d5e6_indices_sprint_4.py           # Índices compuestos optimizados
│       ├── a1b2c3d4e5f6_idempotencia_y_oauth_sprint_4.py # Tablas de idempotencia y OAuth
│       └── 8db9ab3bcce4_agregar_variables_climaticas.py # 7 variables climáticas de Ica
├── docs/                         # Documentación de arquitectura y planes de sprint
│   ├── arquitectura_backend.md   # Este documento maestro
│   ├── optimizacion_bd.md        # Análisis de índices y planes EXPLAIN
│   └── sprint_4.md               # Bitácora y especificación del Sprint 4
├── scripts/                      # Scripts de utilidad y diagnóstico
├── src/                          # Código fuente de la aplicación
│   ├── core/                     # Configuración global del sistema
│   │   ├── config.py             # Configuración tipada con Pydantic Settings (.env)
│   │   ├── database.py           # Engine asíncrono, SessionLocal y Base declarativa
│   │   └── redis.py              # Pool de conexiones asíncrono de Redis
│   ├── modules/                  # Módulos de dominio desacoplados
│   │   ├── analytics/            # Métricas, eventos de uso y dashboard de analítica
│   │   ├── catalog/              # Atractivos turísticos, agencias y categorías
│   │   ├── emergency/            # Reportes SOS, incidentes, contactos e idempotencia
│   │   ├── geo/                  # Georreferenciación y cálculo de distancias
│   │   ├── reviews/              # Reseñas, calificaciones y favoritos
│   │   ├── translation/          # Frasebook oficial con ETag y traducción bilingüe
│   │   ├── users/                # Usuarios, JWT, roles y estrategias OAuth (Google)
│   │   └── weather/              # Clima, pronóstico, alertas de Ica y recomendador IA
│   │       ├── adapters/         # Adaptadores externos (Open-Meteo, etc.)
│   │       ├── ai/               # Motor de IA (prompts XML, schemas, engine Gemini)
│   │       ├── constants.py      # Coordenadas de distritos y umbrales de seguridad
│   │       ├── models.py         # Tablas ORM de mediciones históricas
│   │       ├── rules.py          # Motor de reglas de Ica, alertas y scoring
│   │       ├── schemas.py        # Esquemas de entrada/salida Pydantic
│   │       └── service.py        # Orquestación de caché, anti-stampede y recomendaciones
│   ├── shared/                   # Utilidades y contratos transversales
│   │   ├── exceptions.py         # Manejadores de excepciones HTTP RFC 7807
│   │   ├── http_cache.py         # Generación y validación de ETags (RFC 7232)
│   │   └── idempotency.py        # Procesamiento de cabecera Idempotency-Key (RFC 9535)
│   └── main.py                   # Punto de entrada FastAPI, middlewares y registro de rutas
├── tests/                        # Suite de pruebas automatizadas
│   ├── api_responses_tests/      # Mocks y contratos de APIs meteorológicas
│   └── modules/                  # Pruebas unitarias y de integración por módulo
├── alembic.ini                   # Configuración del entorno de migraciones
├── pytest.ini                    # Configuración de pruebas unitarias
└── requirements.txt              # Dependencias de producción
```

---

## 5. Flujos de Ejecución Detallados Paso a Paso

### 5.1. Flujo del Recomendador Inteligente con Gemini AI y Alertas de Ica

```
[Cliente Móvil]
       │  GET /weather/recommendations?destino=Huacachina&actividades=Sandboarding
       ▼
[Weather Router]
       │
       ▼
[Weather Service] ──► Consulta Caché Redis: "weather:recommendations:Huacachina:..."
       │
       ├─► [Caché HIT]: Devuelve respuesta JSON instantáneamente (< 5ms).
       │
       └─► [Caché MISS]:
             │
             ├─► 1. Obtiene o renueva datos meteorológicos (Open-Meteo Adapter):
             │      Variables ampliadas: velocidad de viento, ráfagas, índice UV,
             │      humedad, temperatura arena, calidad aire PM10, etc.
             │
             ├─► 2. Evalúa Motor de Reglas Locales (`rules.py`):
             │      - Detecta Alerta VIENTO_PARACAS (viento > 30 km/h o ráfagas > 40 km/h).
             │      - Detecta Alerta RADIACION_UV_EXTREMA (índice UV >= 11).
             │      - Calcula Score Determinista de Idoneidad (0.0 a 1.0).
             │
             ├─► 3. Construye Prompt Estructurado XML (`prompt_recomendacion.py`):
             │      Inyecta variables climáticas, alertas activas y continuidad histórica.
             │
             ├─► 4. Invoca API de Gemini (`ai/engine.py`):
             │      Genera justificación narrativa amigable y recomendaciones de horario.
             │
             ├─► 5. Aplica Guardarrail de Seguridad Post-IA:
             │      SI existe alerta severa activa Y la IA sugirió actividad:
             │      - SOBREESCRIBE nivel a "no_recomendado".
             │      - LIMITA score a máx 0.30.
             │      - INYECTA advertencia de seguridad obligatoria.
             │
             ├─► 6. Guarda en Caché Redis con TTL de 30 minutos.
             │
             ▼
[Cliente Móvil] Recibe recomendación 100% segura y contextualizada.
```

---

### 5.2. Flujo de Autenticación Federada con Google (Patrón Strategy)

```
[Cliente Frontend]
       │  1. Autentica al usuario en el SDK de Google y obtiene id_token
       │  2. POST /users/google  { "token": "<google_id_token>", "consentimiento_terminos": true }
       ▼
[Users Router]
       │  Delega en UsersService.social_login(strategy="google", payload)
       ▼
[GoogleAuthStrategy]
       │  3. Valida criptográficamente el token con google-auth (Google certs)
       │  4. Extrae claims: email, given_name, family_name, sub (google_id)
       ▼
[Users Service / Repository]
       │  5. Busca si el usuario ya existe por email o google_id
       │     - Si existe: Asocia cuenta si no estaba enlazada.
       │     - Si no existe: Crea nuevo usuario con rol 'tourist' y flag google_verified.
       │  6. Genera par de tokens JWT de sesión (Access Token + Refresh Token).
       ▼
[Cliente Frontend] Recibe Access Token JWT para consumir la API de Ika Travel.
```

---

### 5.3. Flujo de Optimización de Catálogo con Caché HTTP (ETag / 304 Not Modified)

```
[Cliente] (Petición Inicial)
       │  GET /catalog/attractions?district=Ica
       ▼
[Catalog Router]
       │  Calcula hash criptográfico SHA-256 del contenido devuelto.
       │  Responde con HTTP 200 OK y cabecera: ETag: "a8f3b2c1..."
       ▼
[Cliente] (Peticiones Posteriores)
       │  GET /catalog/attractions?district=Ica
       │  Cabecera: If-None-Match: "a8f3b2c1..."
       ▼
[Catalog Router]
       │  Evalúa si el contenido no ha variado respecto al ETag enviado.
       │  Responde con HTTP 304 Not Modified (cuerpo vacío, 0 bytes transferidos).
       ▼
[Cliente] Utiliza instantáneamente su copia en caché local ahorrando ancho de banda.
```

---

### 5.4. Flujo de Idempotencia en Reportes de Emergencia (SOS)

```
[Cliente Móvil]
       │  POST /emergency/sos
       │  Headers: Idempotency-Key: "550e8400-e29b-41d4-a716-446655440000"
       │  Body: { "latitude": -14.0875, "longitude": -75.7628, "type": "MEDICO" }
       ▼
[Idempotency Middleware / Service]
       │  Consulta tabla `idempotency_records` por (usuario_id, idempotency_key).
       │
       ├─► [Existe Registro]:
       │      Detecta petición duplicada (ej. reintento por pérdida de señal en el desierto).
       │      Retorna respuesta idéntica cacheada con cabecera: Idempotent-Replayed: true.
       │      (NO vuelve a crear un incidente ni duplica llamadas a la policía/ambulancias).
       │
       └─► [No Existe]:
              Crea nuevo incidente de emergencia en la base de datos.
              Encola notificaciones SMS / Push a contactos de emergencia.
              Guarda el resultado en `idempotency_records` dentro de la misma transacción ACID.
              Responde con HTTP 201 Created.
```

---

## 6. Base de Datos y Optimización de Consultas

La base de datos utiliza PostgreSQL 16 con una cadena de migraciones controlada por Alembic. Para garantizar tiempos de respuesta $< 50\text{ ms}$ con alto volumen de turistas, se aplican los siguientes índices estratégicos:

1. **Índice Compuesto en Catálogo:**
   - `idx_attractions_category_published`: Indexa `(category_id, is_published)` permitiendo al turista filtrar por categoría omitiendo registros borrados o no publicados sin recorrer la tabla completa (*Index Scan* directo).
2. **Índice Parcial en Agencias Validadas:**
   - `idx_agencies_active_validated`: Indexa `(id, rating)` aplicando el predicado `WHERE is_validated = true AND is_active = true`. Ahorra espacio y optimiza la visualización de agencias seguras y formales.
3. **Índice B-Tree en Emergencias:**
   - `idx_emergency_user_created_desc`: Indexa `(user_id, created_at DESC)` para consultar el historial de alertas y estados de incidentes del turista en tiempo constante $\mathcal{O}(\log n)$.
4. **Índice Único de Idempotencia:**
   - `uq_idempotency_user_key`: Garantiza la unicidad por `(user_id, idempotency_key)` evitando colisiones entre distintos turistas.

---

## 7. Pruebas y Criterios de Aceptación (DoD)

El backend cuenta con **176 pruebas automatizadas** ejecutadas con `pytest`:
- **Pruebas Unitarias Aisladas:** Pruebas de reglas matemáticas de idoneidad, parsing de esquemas y generación de prompts XML.
- **Pruebas de Integración con Base de Datos:** Pruebas asíncronas de repositorios, consultas con índices y migraciones de Alembic.
- **Control de Regresiones en Migraciones:** El test `tests/modules/test_migrations.py` asegura que `alembic heads` devuelva exactamente **1 única revisión lineal**, impidiendo branches huérfanas en el CI/CD.

```bash
# Para ejecutar la suite completa de pruebas:
cd ika-backend
./venv/bin/pytest -q
```
