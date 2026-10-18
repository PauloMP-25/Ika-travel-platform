# Modelo de Dominio y Capa de Datos — Backend
## Ika Travel & Experience

**Alcance actual:**
- **Usuarios & Autenticación (`users`)**: Cuentas, roles (`tourist`, `dircetur_admin`), idioma preferido (`es`, `en`), preferencias turísticas de Ica y autenticación JWT / OAuth.
- **Catálogo (`catalog`)**: Atractivos turísticos, agencias formales validadas por DIRCETUR (RN-01), tours y categorías.
- **Clima & IA (`weather`)**: Integración con Aggregator Pattern (Open-Meteo, OpenWeatherMap, WeatherAPI), regla RN-03 (caché Redis 6h + persistencia de snapshots en DB), recomendador IA con Google Gemini con afinidad personalizada y alertas meteorológicas.
- **Asistencia SOS & Fiscalización DIRCETUR (`emergency`)**: Botón de pánico geolocalizado (RN-04) con despacho Celery multicanal, directorio oficial de llamadas de emergencia en Ica y denuncias de informalidad turística (RF-05 / CUN06).
- **Reseñas, Fotos & Favoritos (`reviews`)**: Calificaciones 1 a 5 estrellas con `CheckConstraint`, unicidad 1 reseña por usuario por atractivo, fotos con Patrón Strategy (`LocalStorageStrategy`, `MockStorageStrategy`) y toggle de favoritos (RN-02).
- **Geolocalización (`geo`)**: Trazado de rutas y proximidad con OSRM.

---

## 1. Módulo: Auth & Usuarios (`users`)

### 1.1 Entidades (SQLAlchemy)

**`User`**
| Campo | Tipo | Notas |
|---|---|---|
| `id` | UUID (PK) | Generado automáticamente con `uuid4` |
| `email` | String(255), unique, indexed | Email principal de acceso |
| `password_hash` | String(255), nullable | Hash con bcrypt. Null si es OAuth |
| `full_name` | String(120) | Nombre completo del usuario |
| `phone` | String(32), nullable | Para notificaciones SMS de emergencia |
| `auth_provider` | Enum(`email`, `google`, `facebook`) | Proveedor de autenticación |
| `provider_id` | String(255), nullable | Identificador externo OAuth |
| `role` | Enum(`tourist`, `dircetur_admin`) | Rol para permisos de fiscalización |
| `preferred_language` | String(5), default `"es"` | `"es"` o `"en"` para internacionalización |
| `preferences` | JSON, default `[]` | Lista de categorías de interés en Ica |
| `is_active` | Boolean, default `True` | Estado de la cuenta |
| `created_at` / `updated_at` | DateTime (tz) | Auditoría temporal |

**Relaciones:**
- `User` 1:N `Review`
- `User` 1:N `Favorite`
- `User` 1:N `SOSReport`
- `User` 1:N `TouristIncidentReport`

---

## 2. Módulo: Catálogo y Servicios Formalizados (`catalog`)

### 2.1 Entidades (SQLAlchemy)

**`Attraction`**
- `id` (UUID PK), `name` (String), `description` (Text), `latitude` (Float), `longitude` (Float), `district` (String), `official_recommendation` (Text), `is_active` (Boolean).
- Relaciones: 1:N `AttractionImage`, N:M `Category`, 1:N `Tour`, 1:N `Review`, 1:N `Favorite`.

**`Agency`**
- `id` (UUID PK), `name` (String), `ruc` (String 11, Unique), `dircetur_registry_number` (String, Nullable), `is_validated` (Boolean, RN-01), `validated_at` (DateTime), `contact_phone`, `contact_email`.
- Relaciones: 1:N `Tour`.

**`Tour`**
- `id` (UUID PK), `agency_id` (FK `agency.id`), `attraction_id` (FK `attraction.id`, Nullable), `name`, `description`, `price` (Numeric 10,2), `duration_hours` (Integer).

---

## 3. Módulo: Clima y Recomendaciones IA (`weather`)

### 3.1 Entidades (SQLAlchemy)

**`WeatherSnapshot`**
- `id` (UUID PK), `attraction_id` (FK `attraction.id`), `temperature_c` (Float), `humidity` (Integer), `wind_speed_kmh` (Float), `uv_index` (Float), `condition_code` (String), `condition_text` (String), `source_provider` (String), `captured_at` (DateTime tz).

**`WeatherAlert`**
- `id` (UUID PK), `attraction_id` (FK `attraction.id`), `alert_type` (Enum: `paracas_wind`, `extreme_uv`, `high_temperature`, `rain_hazard`), `severity` (Enum: `advisory`, `warning`, `danger`), `title`, `message`, `is_active`, `starts_at`, `expires_at`.

---

## 4. Módulo: Emergencia y Fiscalización (`emergency`)

### 4.1 Entidades (SQLAlchemy)

**`SOSReport`**
- `id` (UUID PK), `user_id` (FK `users.id`), `latitude` (Float, RN-04), `longitude` (Float, RN-04), `description` (Text), `status` (Enum: `pending`, `dispatched`, `resolved`), `created_at`, `resolved_at`.
- Relaciones: 1:N `EmergencyNotification`.

**`EmergencyNotification`**
- `id` (UUID PK), `sos_report_id` (FK `sos_reports.id`), `channel` (Enum: `push`, `email`, `sms`), `recipient` (String), `status` (Enum: `queued`, `sent`, `failed`), `sent_at`.

**`TouristIncidentReport`** (RF-05 / CUN06)
- `id` (UUID PK), `user_id` (FK `users.id`), `incident_type` (Enum: `informal_service`, `information_error`, `route_obstruction`, `safety_hazard`, `other`), `title`, `description`, `latitude` (Float, Nullable), `longitude` (Float, Nullable), `agency_name` (String, Nullable), `status` (Enum: `received`, `in_review`, `resolved`, `dismissed`), `admin_notes` (Text, Nullable), `created_at`, `updated_at`.

---

## 5. Módulo: Reseñas, Fotos y Favoritos (`reviews`)

### 5.1 Entidades (SQLAlchemy)

**`Review`**
- `id` (UUID PK), `user_id` (FK `users.id`), `attraction_id` (FK `attraction.id`), `rating` (Integer, CheckConstraint `1 <= rating <= 5`), `comment` (Text, Nullable), `created_at`, `updated_at`.
- Constraints: `UniqueConstraint("user_id", "attraction_id", name="uq_user_attraction_review")`.
- Relaciones: 1:N `ReviewImage`.

**`ReviewImage`**
- `id` (UUID PK), `review_id` (FK `reviews.id`), `image_url` (String 500), `storage_provider` (String, ej. `local`, `mock`, `s3`), `created_at`.

**`Favorite`**
- `id` (UUID PK), `user_id` (FK `users.id`), `attraction_id` (FK `attraction.id`), `created_at`.
- Constraints: `UniqueConstraint("user_id", "attraction_id", name="uq_user_attraction_favorite")`.

---

## 6. Módulo: Geolocalización (`geo`)

- Operaciones geoespaciales basadas en distancia Haversine y trazado de rutas con el servicio OSRM (`/route/v1/driving/`).
