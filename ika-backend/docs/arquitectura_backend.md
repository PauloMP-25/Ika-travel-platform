# Guía y Documentación Integral del Backend - Ika Travel Platform

Esta guía detalla la arquitectura de software, patrones de diseño, estructura modular, flujos de ejecución paso a paso, stack tecnológico, APIs integradas y su justificación, modelos de Inteligencia Artificial utilizados, y la matriz de trazabilidad con Requerimientos Funcionales (RF), No Funcionales (RNF), Reglas de Negocio Institucionales (RN) y Restricciones Estrictas de Alcance extraídas de la memoria del proyecto (`.agents/memoria/contexto_especificacion_producto.md` y `capitulo4_analisis_negocio.md`).

---

## 1. Visión General del Sistema y Destinos Soportados

El backend de **Ika Travel** es una plataforma orientada a servicios RESTful y asíncronos diseñada para actuar como el **Hub Oficial de Información y Asistencia Turística de la DIRCETUR Ica** en el departamento de Ica, Perú.

### 1.1. Restricciones y Exclusiones Estrictas de Alcance (Definidas por DIRCETUR Ica)
En concordancia estricta con la memoria oficial del producto:
1. **NO REGISTRO DE RESERVAS:** La plataforma es estrictamente informativa, orientativa y de asistencia. En ninguna circunstancia gestiona, almacena ni procesa reservas de tours, hoteles o transportes.
2. **NO PROCESAMIENTO DE PAGOS:** El sistema NO cuenta con pasarelas de pago ni procesa transacciones monetarias ni comercio electrónico de ningún tipo.
3. **NO SUSTITUCIÓN DE E-COMMERCE PRIVADO:** La plataforma no interviene en las operaciones comerciales ni de agenda interna de las agencias privadas. Toda contratación se realiza fuera de la plataforma por los medios oficiales del prestador verificado.
4. **NO ATENCIÓN DE EMERGENCIAS POLICIALES O MÉDICAS DIRECTAS:** La funcionalidad de asistencia/SOS canaliza y facilita la llamada o envío de datos hacia las instituciones competentes (PNP Turismo, Bomberos, SAMU), sin reemplazar sus centrales operativas.

### 1.2. Destinos y Atractivos Turísticos Piloto Incorporados en Base de Datos:
1. **Oasis de Huacachina (Ica):** Laguna natural rodeada de dunas desérticas para sandboarding y buggies.
2. **Plaza de Armas de Ica (Ica):** Centro cívico e histórico de la capital provincial.
3. **Pueblo de Cachiche (Ica):** Turismo místico y cultural (palmera de 7 cabezas y monumento a las brujas).
4. **Bodegas y Viñedos de Subtanjalla y Tacama:** Tradición vitivinícola y ruta oficial del pisco.
5. **Cañón de los Perdidos (Ocucaje):** Formación geológica desértica para trekking y turismo de aventura.
6. **Plaza de Armas de Pisco (Pisco):** Plaza histórica que conmemora la expedición libertadora de San Martín.
7. **Plaza de Armas de Chincha Alta (Chincha):** Centro cultural afroperuano, danzas y gastronomía típica (carapulcra con sopa seca).
8. **Playa La Mina (Paracas - Reserva Nacional):** Playa de aguas turquesas y mansas protegida por altos acantilados.
9. **Playa Roja (Paracas - Reserva Nacional):** Paisaje protegido único famoso por su arena de color rojizo volcánico.
10. **Playa El Chaco (Paracas):** Balneario principal y muelle turístico desde donde zarpan las lanchas hacia las Islas Ballestas.
11. **Playa Hermosa de Marcona (Nasca):** Litoral agreste de aguas cristalinas con formaciones rocosas esculpidas por el mar y fauna marina.

---

## 2. Matriz de Requerimientos y Reglas de Negocio (Trazabilidad Oficial)

Extraído textualmente de `.agents/memoria/contexto_especificacion_producto.md` y verificado contra la implementación actual en el backend:

### 2.1. Requerimientos Funcionales (RF)
| Código | Requerimiento Funcional | Prioridad | Estado | Implementación / Justificación Técnica en Backend |
| :---: | :--- | :---: | :---: | :--- |
| **RF-01** | **Gestión de Autenticación y Perfil de Turista:** Registro e inicio de sesión mediante correo electrónico o credenciales de redes sociales. Selección de idioma preferido (español/inglés) y categorías de interés turístico. | **Must Have (M)** | [x] | Implementado con JWT Bearer stateless, contraseñas Bcrypt (`passlib`), login federado con Google OAuth mediante el Patrón Strategy (`src/modules/users/auth_strategies/google.py`) y persistencia de favoritos. |
| **RF-02** | **Exploración y Visualización de Atractivos Turísticos:** Catálogo oficial de atractivos de la DIRCETUR Ica, imágenes, descripción histórica/cultural, nivel de accesibilidad y coordenadas georreferenciadas. | **Must Have (M)** | [x] | Módulo `src/modules/catalog/` con endpoints paginados, filtros por categoría y optimización de caché HTTP mediante ETag (`304 Not Modified`). |
| **RF-03** | **Búsqueda y Filtrado de Catálogo de Servicios Formalizados:** Explorar agencias de viajes empadronadas por DIRCETUR Ica y sus tours, mostrando medios de contacto oficiales para contratación externa (sin pasarela de pago). | **Must Have (M)** | [x] | Implementado con el índice parcial `idx_agencies_validated` que filtra en base de datos únicamente agencias con `is_validated = true` e insignias oficiales. |
| **RF-04** | **Geolocalización, Rutas y Asistencia Offline Básica:** Uso de GPS para mostrar la posición respecto a los atractivos. Copia en caché local de la cartografía básica y datos para consulta sin señal. | **Should Have (S)** | [x] | Módulo `src/modules/geo/` con cálculo Haversine y prefiltro por bounding box (`ix_attraction_lat_lon`). En la app móvil Flutter se provee fallback local offline con marcadores en `flutter_map`. |
| **RF-05** | **Emisión de Alertas SOS y Reporte de Incidencias:** Módulo de asistencia para llamadas rápidas a números de emergencia (PNP Turismo, SAMU, Bomberos) y envío de formularios de incidencias o informalidad a DIRCETUR Ica. | **Should Have (S)** | [x] | Módulo `src/modules/emergency/` con soporte de cabecera `Idempotency-Key` (RFC 9535), colas de notificación y validación estricta de coordenadas GPS. |
| **RF-06** | **Panel Administrativo y Analítica Turística DIRCETUR:** Dashboard web restringido para gestión de contenidos (atractivos, padrón de agencias) y reportes estadísticos agregados sobre búsquedas, idiomas y flujos. | **Could Have (C)** | [x] | Módulo `src/modules/analytics/` con agregaciones SQL sin producto cartesiano, métricas de incidentes, idiomas y eventos de uso del catálogo. |

### 2.2. Requerimientos No Funcionales (RNF)
| Código | Requerimiento No Funcional | Estado | Justificación / Mecanismo Técnico |
| :---: | :--- | :---: | :--- |
| **RNF-01** | **Rendimiento y Tiempos de Respuesta:** Las consultas de búsqueda y carga de fichas turísticas no deben exceder 3.0 segundos bajo condiciones normales 4G/Wi-Fi. | [x] | Respuestas en caché Redis $< 5\text{ ms}$, índices compuestos en Postgres B-tree e índice parcial en agencias. |
| **RNF-02** | **Disponibilidad y Concurrencia:** Garantizar 99.9% de disponibilidad y soportar al menos 1,000 usuarios concurrentes sin degradación. | [x] | Servidor ASGI Uvicorn asíncrono sobre event loop `uvloop`, driver `asyncpg` no bloqueante y cerrojo anti-estampida en Redis (`SET NX EX`). |
| **RNF-03** | **Seguridad, Cifrado y Privacidad:** Protocolo HTTPS/TLS 1.3 en comunicaciones. Cifrado de credenciales y cumplimiento estricto de la Ley N° 29733 (Protección de Datos Personales). | [x] | Hashing seguro Bcrypt con sal aleatoria, tokens JWT firmados criptográficamente y validación de consentimientos informados en registro social. |
| **RNF-04** | **Usabilidad, Accesibilidad y Multilingüismo:** Interfaz accesible UX/UI y conmutación dinámica e instantánea de lenguaje entre Español e Inglés en todas las pantallas. | [x] | Módulo `src/modules/translation/` con frasebook oficial bilingüe versionado por ETag (8 categorías temáticas) y traductor libre ES↔EN. |
| **RNF-05** | **Arquitectura de Software e Interoperabilidad:** Arquitectura orientada a servicios e independientes comunicados vía APIs RESTful con intercambio en formato JSON. | [x] | FastAPI con tipado estricto Pydantic v2, generación automática de OpenAPI v3 / Swagger UI y soporte multiplataforma (Android/iOS). |

### 2.3. Reglas de Negocio Institucionales (RN)
| Código | Nombre de la Regla | Estado | Implementación / Control en Código |
| :---: | :--- | :---: | :--- |
| **RN-01** | **Validación de Prestadores Formales:** Solo las agencias inscritas y verificadas en el Padrón Oficial de la DIRCETUR Ica podrán ser visibilizadas en el catálogo. | [x] | Forzado en base de datos mediante `agency.is_validated == true` y el índice parcial `idx_agencies_validated`. |
| **RN-02** | **Autenticación Gradual para Interacciones Avanzadas:** Navegación libre y pública de catálogo, mapa y clima. Registro obligatorio solo para guardar favoritos, preferencias y emitir SOS/incidencias. | [x] | Endpoints públicos sin token (`/catalog/attractions`, `/weather/current`, `/translation/phrases`), y endpoints privados protegidos por `Depends(get_current_user)` (`/emergency/sos`, `/catalog/attractions/{id}/favorite`). |
| **RN-03** | **Vigencia y Cumplimiento de Datos:** Toda recomendación climática debe basarse en datos frescos (máx 6 horas) y cumplir la Ley N° 29733. | [x] | Caché Redis con TTL de 30 minutos (12 veces más fresco que el límite de 6 horas) y validación de consentimiento en esquemas. |
| **RN-04** | **Sincronización y Disponibilidad Offline:** Datos esenciales (atractivos principales, coordenadas, contactos de emergencia y guía de frases) deben guardarse localmente para consulta sin señal. | [x] | Cliente móvil `ApiClient`, `WeatherService`, `AttractionsService` y `TranslationService` con semillas locales (*offline seed/fallback*) y cabeceras ETag (`304 Not Modified`). |

---

## 3. Integración de APIs Externas y su Justificación

En lugar de acoplarse a un único proveedor meteorológico monolítico, el sistema adopta una **arquitectura multi-proveedor desacoplada mediante el Patrón Adapter**.

### ¿Qué APIs están integradas y por qué más de una?
1. **Open-Meteo API (Proveedor Principal):**
   - *Ventajas:* Sin costo por API key comercial, modelado meteorológico horario de alta resolución para coordenadas desérticas y rurales, y acceso a variables especializadas: **temperatura superficial del suelo/arena**, **ráfagas de viento**, **radiación solar directa** y **calidad del aire PM10** (fundamentales para las dunas de Huacachina y el Cañón de los Perdidos).
2. **OpenWeatherMap API (Proveedor Secundario / Fallback):**
   - *Ventajas:* Cobertura global de condiciones actuales, iconografía estandarizada y descripciones textuales en español peruano.
3. **WeatherAPI (Proveedor de Respaldo Terciario):**
   - *Ventajas:* Respaldo para índices UV máximos y avisos meteorológicos regionales.
4. **Google Identity Services (OAuth 2.0 API):**
   - *Propósito:* Verificación criptográfica de tokens ID de Google para registro e inicio de sesión federado sin fricción.

### Justificación Técnica de la Integración Multi-API (vs. Una Sola API):
1. **Alta Disponibilidad y Tolerancia a Fallos:** Las APIs externas gratuitas o estándar sufren caídas esporádicas o imponen cuotas estrictas de peticiones (*rate limits*). Al estructurar adaptadores intercambiables bajo una misma interfaz, si Open-Meteo devuelve un error `503` o `429`, el sistema conmuta automáticamente al siguiente proveedor sin interrumpir al turista.
2. **Especialización Geográfica por Entorno:** Ninguna API meteorológica individual cubre todas las necesidades extremas de la región de Ica. Mientras los proveedores convencionales reportan temperatura ambiental en sombra (a 2 metros de altura), las dunas de Huacachina superan los $45^\circ\text{C}$ en la arena. La combinación multi-API permite fusionar variables críticas como vientos Paracas, ráfagas, radiación UV y estado marítimo.
3. **Optimización de Costos:** Permite balancear peticiones entre servicios con soporte de **Caché en Redis (30 min)** y cerrojo anti-estampida (*mutex lock*), operando a costo $0 en infraestructura de datos externos.

---

## 4. Modelo de Inteligencia Artificial Utilizado

### Modelo: **Google Gemini Flash (`gemini-flash-latest`)**
Se utiliza la API oficial de **Google GenAI SDK** configurada en `src/modules/weather/ai/engine.py`.

### Justificación de la Elección:
1. **Baja Latencia de Inferencia:** Gemini Flash responde en menos de $800\text{ ms}$, ideal para aplicaciones móviles donde el usuario requiere recomendaciones ágiles en pantalla.
2. **Procesamiento de Prompts Estructurados en XML:** Gemini procesa de manera sobresaliente instrucciones delimitadas con etiquetas XML (`<contexto_geografico>`, `<variables_climaticas>`, `<alertas_activas>`, `<reglas_seguridad>`), garantizando respuestas JSON estructuradas sin alucinaciones.
3. **Guardarrailes Post-IA Deterministas:** El backend no delega la seguridad física del turista al modelo generativo. Si la IA recomendara realizar una actividad pero el motor de reglas de Ica detecta viento Paracas $> 35\text{ km/h}$, el **guardarrail post-IA en Python sobreescribe deterministamente** el resultado a `"no_recomendado"` y limita el score a $\le 0.30$.

---

## 5. Arquitectura de Software y Estructura Modular

El backend sigue una arquitectura **Modular Monolithic en Capas (Layered Modular Architecture)** con separación estricta:

```
ika-backend/src/
├── core/                         # Configuración central (Pydantic Settings, DB, Redis)
├── modules/                      # Módulos desacoplados del dominio
│   ├── analytics/                # Métricas y eventos de uso de la DIRCETUR
│   ├── catalog/                  # Atractivos turísticos, agencias formales y categorías
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
3. Si la clave ya fue procesada, responde de inmediato con el resultado previo y la cabecera `Idempotent-Replayed: true` (evita duplicar avisos a la policía o SAMU).
4. Si es nueva, registra el incidente, encola avisos y almacena la clave atómicamente en la misma transacción ACID.

---

## 7. Garantías de Calidad y Pruebas (DoD)

- **176 pruebas automatizadas (`pytest`)** pasando al **100%** (0 fallos, 0 errores).
- **Alembic:** Verificación de grafo de migraciones con **1 solo head lineal** (`8db9ab3bcce4`).
- **Frontend Móvil:** Pruebas de integración (`flutter test`) aprobadas al 100%.
