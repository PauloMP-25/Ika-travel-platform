# Guía y Documentación Integral del Backend - Ika Travel Platform

Esta guía detalla la arquitectura de software, patrones de diseño, estructura modular, flujos de ejecución paso a paso, stack tecnológico, APIs integradas y su justificación, modelos de Inteligencia Artificial utilizados, y la matriz de trazabilidad con Requerimientos Funcionales (RF), No Funcionales (RNF) y Reglas de Negocio (RN) con su estado de implementación en **Ika Travel & Experience**.

---

## 1. Visión General del Sistema y Destinos Soportados

El backend de **Ika Travel** es una plataforma orientada a servicios RESTful y asíncronos diseñada para brindar a turistas y operadores turísticos una experiencia enriquecida y segura en el departamento de Ica, Perú.

### Destinos y Atractivos Turísticos Piloto Incorporados en Base de Datos:
1. **Oasis de Huacachina (Ica):** Laguna natural rodeada de dunas desérticas para sandboarding y buggies.
2. **Plaza de Armas de Ica (Ica):** Centro cívico e histórico de la capital provincial.
3. **Pueblo de Cachiche (Ica):** Turismo místico y cultural (palmera de 7 cabezas y brujas de Cachiche).
4. **Bodegas y Viñedos de Subtanjalla y Tacama:** Tradición vitivinícola y ruta oficial del pisco.
5. **Cañón de los Perdidos (Ocucaje):** Formación geológica desértica para trekking y aventura.
6. **Plaza de Armas de Pisco (Pisco):** Plaza histórica que conmemora la expedición libertadora de San Martín.
7. **Plaza de Armas de Chincha Alta (Chincha):** Centro cultural afroperuano y gastronomía típica (carapulcra con sopa seca).
8. **Playa La Mina (Paracas - Reserva Nacional):** Playa de aguas turquesas y mansas protegida por acantilados.
9. **Playa Roja (Paracas - Reserva Nacional):** Paisaje protegido famoso por su arena de color rojizo.
10. **Playa El Chaco (Paracas):** Balneario principal y embarcadero hacia las Islas Ballestas.
11. **Playa Hermosa de Marcona (Nasca):** Litoral agreste de aguas cristalinas con formaciones rocosas y fauna marina.

---

## 2. Requerimientos y Reglas de Negocio (Matriz de Cumplimiento)

Alineado con los documentos oficiales del proyecto de diseño (`documentos_proyecto/avance_proyecto_diseño.md`), a continuación se presenta la matriz de requerimientos con su estado verificado:

### 2.1. Requerimientos Funcionales (RF)
| Código | Requerimiento Funcional | Estado | Justificación / Implementación en Backend |
| :---: | :--- | :---: | :--- |
| **RF-01** | **Registro y autenticación de usuarios:** Permitir registro e inicio de sesión con correo, contraseña cifrada o redes sociales. | [x] | Implementado con JWT Bearer stateless, hashing Bcrypt (`passlib`) y login federado con Google OAuth mediante el Patrón Strategy (`src/modules/users/`). |
| **RF-02** | **Exploración de atractivos turísticos:** Catálogo digital con galerías fotográficas, recomendaciones oficiales y filtros. | [x] | Módulo `src/modules/catalog/` con endpoints paginados, filtros por categoría y optimización de caché HTTP mediante ETag (`304 Not Modified`). |
| **RF-03** | **Búsqueda de servicios formalizados:** Exposición exclusiva de agencias y tours formales autorizados por DIRCETUR. | [x] | Implementado mediante el índice parcial `idx_agencies_validated` que filtra en base de datos únicamente agencias con `is_validated = true`. |
| **RF-04** | **Geolocalización en tiempo real y mapas:** Ubicación exacta respecto a atractivos y cálculo de distancias. | [x] | Módulo `src/modules/geo/` con cálculo Haversine y prefiltro por bounding box mediante índice compuesto `ix_attraction_lat_lon`. Marcadores interactivos GPS en Flutter. |
| **RF-05** | **Emisión de incidencias y SOS geolocalizado:** Botón de pánico o formulario de incidencias ante situaciones de riesgo. | [x] | Módulo `src/modules/emergency/` con soporte de cabecera `Idempotency-Key` (RFC 9535), colas asíncronas de notificación y validación estricta de coordenadas GPS. |
| **RF-06** | **Planificación basada en clima y alertas:** Pronóstico en tiempo real y recomendaciones adaptadas al clima local. | [x] | Módulo `src/modules/weather/` con 7 variables climáticas de Ica, detección de vientos Paracas / radiación UV y generación de itinerarios inteligentes con IA Gemini. |

### 2.2. Requerimientos No Funcionales (RNF)
| Código | Requerimiento No Funcional | Estado | Justificación / Mecanismo Técnico |
| :---: | :--- | :---: | :--- |
| **RNF-01** | **Disponibilidad y Concurrencia:** Soportar al menos 1,000 usuarios concurrentes sin degradación. | [x] | Servidor ASGI Uvicorn asíncrono con `asyncpg` y cerrojo anti-estampida en Redis (`SET NX EX`) que previene colapso ante peticiones masivas. |
| **RNF-02** | **Rendimiento y Tiempo de Respuesta:** Respuestas $< 3\text{ s}$ en condiciones normales. | [x] | Caché Redis en memoria ($< 5\text{ ms}$ en hits), índices compuestos en Postgres y ETag HTTP 304 que evita reenviar datos que no han variado. |
| **RNF-03** | **Seguridad y Protección de Datos:** Encriptación, tokens seguros y cumplimiento de Ley N° 29733. | [x] | Contraseñas con sal y hash Bcrypt, tokens JWT firmados, validación criptográfica de firmas Google y CORS restrictivo. |
| **RNF-04** | **Usabilidad y Accesibilidad Multilingüe:** Interfaz intuitiva y soporte para turistas extranjeros (ES/EN). | [x] | Módulo `src/modules/translation/` con frasebook oficial bilingüe (32 frases en 8 categorías) y traductor libre bidireccional ES↔EN. |
| **RNF-05** | **Interoperabilidad y Compatibilidad:** Exposición RESTful estándar e integración móvil multiplataforma. | [x] | API RESTful documentada con OpenAPI/Swagger, compatible con Android, iOS y Web mediante el cliente `ApiClient` en Flutter. |

### 2.3. Reglas de Negocio (RN)
| Código | Regla de Negocio | Estado | Implementación / Control en Código |
| :---: | :--- | :---: | :--- |
| **RN-01** | **Exclusividad de oferta formal:** Solo mostrar agencias empadronadas y validadas por DIRCETUR. | [x] | Forzado en base de datos (`agency.is_validated == true`) con índice parcial `idx_agencies_validated` que excluye cualquier agencia no validada. |
| **RN-02** | **Autenticación obligatoria para transacciones:** Consulta libre de catálogo/clima, pero autenticación obligatoria para reservas o SOS. | [x] | Dependencia `get_current_user` inyectada en endpoints transaccionales (`/emergency/sos`, `/catalog/attractions/{id}/favorite`). |
| **RN-03** | **Vigencia de datos climáticos:** Datos no mayores a 6 horas de antigüedad. | [x] | Caché en Redis con TTL de 30 minutos (12 veces más restrictivo que la regla de negocio), garantizando datos meteorológicos siempre frescos. |
| **RN-04** | **Privacidad y permisos de geolocalización:** Reportes SOS y cálculo de rutas exigen coordenadas válidas otorgadas por el usuario. | [x] | Validación estricta en esquemas Pydantic (`ck_attraction_latitude` entre -90 y 90, `ck_attraction_longitude` entre -180 y 180). |

---

## 3. Integración de APIs Externas y su Justificación

En lugar de depender de una única API meteorológica monolítica o frágil, el sistema adopta una **arquitectura multi-proveedor desacoplada mediante el Patrón Adapter**.

### ¿Qué APIs están integradas y por qué más de una?
1. **Open-Meteo API (Proveedor Principal):**
   - *Ventajas:* No requiere API key comercial, ofrece datos horarios de alta precisión geográfica para coordenadas rurales y desérticas, y expone variables especializadas como **temperatura superficial del suelo/arena**, **ráfagas de viento**, **radiación solar directa** y **calidad del aire PM10** (fundamentales para las dunas de Huacachina y el Cañón de los Perdidos).
2. **OpenWeatherMap API (Proveedor Secundario / Fallback):**
   - *Ventajas:* Excelente cobertura global de condiciones actuales, iconografía meteorológica estandarizada y descripciones textuales en español peruano.
3. **WeatherAPI (Proveedor de Respaldo Terciario):**
   - *Ventajas:* Respaldo para índices UV máximos y avisos meteorológicos regionales.
4. **Google Identity Services (OAuth 2.0 API):**
   - *Propósito:* Verificación criptográfica de tokens ID de Google para registro e inicio de sesión sin fricción del turista.

### Justificación Técnica de la Integración Multi-API (vs. Una Sola API):
1. **Alta Disponibilidad y Tolerancia a Fallos:** Las APIs gratuitas o de nivel estándar imponen cuotas de consumo (*rate limits*) o sufren caídas esporádicas. Al tener adaptadores modulares, si Open-Meteo devuelve un error `503` o `429`, el sistema puede conmutar de inmediato sin interrumpir el servicio al turista.
2. **Especialización de Variables por Entorno Geográfico:** Ninguna API meteorológica individual cubre todas las necesidades extremas de Ica. Mientras los proveedores convencionales reportan temperatura ambiental estándar (en sombra a 2 metros de altura), las dunas de Ica alcanzan más de $45^\circ\text{C}$ en la arena. La combinación permite fusionar variables críticas como vientos Paracas, ráfagas, radiación UV y estado marítimo.
3. **Optimización de Costos y Cuotas:** Permite balancear peticiones entre servicios sin incurrir en planes de facturación corporativos prohibitivos para un MVP.

---

## 4. Modelo de Inteligencia Artificial Utilizado

### Modelo: **Google Gemini Flash (`gemini-flash-latest` / `gemini-2.5-flash`)**
Se utiliza la API oficial de **Google GenAI SDK** configurada en `src/modules/weather/ai/engine.py`.

### Justificación de la Elección:
1. **Baja Latencia de Inferencia:** Gemini Flash responde en menos de $800\text{ ms}$, ideal para aplicaciones móviles donde el usuario espera una recomendación instantánea al abrir la pantalla.
2. **Comprensión Semántica de Prompts Estructurados en XML:** Gemini procesa de manera sobresaliente instrucciones complejas delimitadas con etiquetas XML (`<contexto_geografico>`, `<variables_climaticas>`, `<alertas_activas>`, `<reglas_seguridad>`), respetando esquemas JSON estrictos sin alucinaciones.
3. **Soporte de Guardarrailes Post-IA:** El backend no confía ciegamente en la salida del modelo generativo. Si la IA recomendara realizar sandboarding pero el motor de reglas de Ica detecta viento Paracas $> 35\text{ km/h}$, el **guardarrail post-IA en Python sobreescribe deterministamente** el resultado a `"no_recomendado"`, anteponiendo la seguridad física del turista.

---

## 5. Arquitectura de Software y Estructura Modular

El backend sigue una arquitectura **Modular Monolithic en Capas (Layered Modular Architecture)** con separación estricta:

```
ika-backend/src/
├── core/                         # Configuración central (Pydantic Settings, DB, Redis)
├── modules/                      # Módulos desacoplados del dominio
│   ├── analytics/                # Métricas y eventos de uso (RFC)
│   ├── catalog/                  # Atractivos turísticos, agencias y categorías
│   ├── emergency/                # Reportes SOS, incidentes e Idempotency-Key
│   ├── geo/                      # Cálculo geográfico y Haversine
│   ├── reviews/                  # Reseñas, calificaciones y favoritos
│   ├── translation/              # Frasebook oficial con ETag y traductor bilingüe
│   ├── users/                    # JWT, roles y estrategias OAuth (Google)
│   └── weather/                  # Clima, pronóstico, alertas de Ica y recomendador IA
│       ├── adapters/             # Adaptadores desacoplados de APIs meteorológicas
│       ├── ai/                   # Engine Gemini, esquemas y prompts XML
│       ├── constants.py          # Coordenadas y umbrales de alerta de Ica
│       ├── models.py             # Histórico de mediciones climáticas
│       ├── rules.py              # Motor de reglas determinista de Ica
│       └── service.py            # Orquestador con caché Redis y anti-stampede
├── shared/                       # Componentes transversales
│   ├── exceptions.py             # Respuestas de error RFC 7807
│   ├── http_cache.py             # Manejo de ETag y 304 Not Modified
│   └── idempotency.py            # Contrato RFC 9535 para peticiones seguras
└── main.py                       # Servidor FastAPI, CORS y registro de routers
```

---

## 6. Flujos de Ejecución Paso a Paso

### 6.1. Flujo del Recomendador con IA y Alertas de Ica
1. **Petición del Turista:** El cliente solicita `GET /api/v1/weather/recommendations?destino=Paracas&actividades=Tour Islas Ballestas`.
2. **Evaluación de Caché:** El servicio consulta Redis (`weather:recommendations:Paracas:...`). Si hay un hit, retorna inmediatamente ($< 5\text{ ms}$).
3. **Consulta de Variables Ampliadas:** En caso de miss, el adaptador obtiene las 7 variables climáticas de Ica (viento, ráfagas, UV, humedad, oleaje, etc.).
4. **Motor de Reglas Determinista:** Evalúa umbrales locales. Si el viento supera 35 km/h, activa la alerta `VIENTO_PARACAS`.
5. **Generación con Gemini AI:** Construye el prompt XML inyectando las condiciones reales y solicita a Gemini Flash la narrativa y el mejor horario.
6. **Guardarrail de Seguridad:** Si hay alerta de alta severidad, el guardarrail fuerza el nivel a `"no_recomendado"` y limita el score a $\le 0.30$.
7. **Persistencia y Respuesta:** Almacena en Redis con TTL de 30 minutos y responde al cliente móvil.

### 6.2. Flujo de Idempotencia en Emergencias (SOS)
1. El turista presiona el botón SOS en zona sin buena cobertura: envía `POST /api/v1/emergency/sos` con cabecera `Idempotency-Key: <UUID>`.
2. El servicio consulta la tabla `idempotency_records` por `(user_id, idempotency_key)`.
3. Si la clave ya fue procesada, responde de inmediato con el resultado previo y la cabecera `Idempotent-Replayed: true` (evita despachar dos ambulancias o duplicar alertas a la policía).
4. Si es nueva, registra el incidente, encola avisos y almacena la clave atómicamente en la misma transacción ACID.

---

## 7. Garantías de Calidad y Pruebas (DoD)

- **176 pruebas automatizadas (`pytest`)** pasando al **100%** (0 fallos, 0 errores).
- **Alembic:** Verificación de grafo de migraciones con **1 solo head lineal** (`8db9ab3bcce4`).
- **Frontend Móvil:** Pruebas de integración (`flutter test`) aprobadas al 100%.
