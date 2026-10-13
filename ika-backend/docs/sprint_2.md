# Plan de Ejecución del Sprint 2 - Ika Travel Backend

Este documento es la **guía oficial de tareas** para el Sprint 2. Reemplaza cualquier documento de tareas del Sprint 1. 
La infraestructura base (Redis, Celery y Docker) ya está configurada en la rama `develop`.

---

## Reglas Generales para el Equipo
1. **Ramas:** Creen sus ramas a partir de `develop` con el formato `feature/<nombre-tarea>`.
2. **Dependencias:** Asegúrense de hacer `git pull origin develop` y luego `pip install -r requirements.txt` para obtener las nuevas librerías (Celery, Redis).
3. **Contenedores:** Para probar localmente de forma idéntica a producción, usen `docker compose up -d redis db`.
4. **Test Driven:** Ningún PR será aceptado si no incluye los tests unitarios descritos en sus respectivas secciones.

---

## 🧑‍💻 Sección Francis: Módulo de Reseñas y Favoritos (`reviews`)

### 👏 Reconocimiento y Evaluación del Sprint 1
* ¡Excelente trabajo en la arquitectura inicial de `users`! Destacamos el uso impecable del **Repository Pattern** (`users/repository.py`), que desvinculó de forma limpia las consultas a la base de datos del módulo de negocio, así como la estricta separación de **DTOs** utilizando Pydantic en `schemas.py` y la seguridad con hashing de contraseñas y JWT.

### 💡 Propuesta de Mejora (Patrones del Sprint 1 para incorporar en Sprint 2)
Para elevar la mantenibilidad de la aplicación a nivel profesional, incluiremos las siguientes mejoras de patrones durante este sprint:

1. **Strategy Pattern (para Subida de Archivos / Almacenamiento):**
   - **Por qué usarlo:** En la tarea 2 (`storage.py`), necesitamos guardar imágenes de reseñas. Si escribimos código que guarde directo en el disco local (`LocalStorage`), cuando despleguemos en AWS/GCP a producción usando Amazon S3 tendremos que reescribir todo el servicio.
   - **Beneficios:** Implementar una interfaz `StorageStrategy` con clases como `LocalStorageStrategy` y `S3StorageStrategy`. Permite cambiar de disco local a la nube con 1 sola línea de configuración en `.env` y facilita hacer testing con un `MockStorageStrategy` sin tocar el sistema de archivos real.
2. **Strategy Pattern (para Autenticación Multiproveedor):**
   - **Por qué usarlo:** Actualmente el login valida únicamente `Email/Password`. 
   - **Beneficios:** Preparar la lógica de autenticación con el patrón Strategy facilitará que en el siguiente sprint agreguemos login social con Google o Facebook sin llenar el `service.py` con bloques `if/else`.

---

### Contexto del Módulo
El objetivo es permitir a los turistas autenticados calificar los atractivos turísticos (de 1 a 5 estrellas), dejar comentarios con fotos y guardar atractivos como favoritos. Esto impactará directamente al Catálogo, ya que las tarjetas de los atractivos ahora mostrarán un rating real.

### Tareas Paso a Paso

#### 1. Modelos de Base de Datos (`src/modules/reviews/models.py`)
- Crear `Review`:
  - Relación FK hacia el usuario y FK hacia el atractivo.
  - Columna `rating` (Integer). Asegúrate de añadir un `CheckConstraint` para limitar el valor entre 1 y 5.
  - Columna `comment` (String, nullable).
  - Un `UniqueConstraint` por usuario y atractivo (un usuario solo puede dejar 1 reseña por lugar).
- Crear `ReviewImage`:
  - FK a `Review` con `ondelete="CASCADE"`.
  - Columna `url` (String).
- Crear `Favorite`:
  - FK hacia usuario y atractivo, con `UniqueConstraint` para que no se dupliquen favoritos.

#### 2. Subida de Archivos con Patrón Strategy (`src/shared/storage.py`)
- Crear la interfaz abstracta `StorageStrategy` y su implementación concreta `LocalStorageStrategy`.
- Recibir un archivo (`UploadFile` de FastAPI).
- Validar que sea una imagen (MIME type `image/jpeg`, `image/png`) y que pese menos de 5MB (usando `config.MAX_UPLOAD_MB`).
- Guardar el archivo en disco (usando `config.UPLOADS_DIR`) y devolver la URL pública.

#### 3. Esquemas de Datos (`src/modules/reviews/schemas.py`)
- Crear `ReviewCreate`: Valida que `rating` esté entre 1 y 5 usando Pydantic `Field(ge=1, le=5)`.
- Crear los esquemas de respuesta para reseñas y favoritos, cuidando de NO exponer información sensible del usuario (ej. email o hash de contraseña).

#### 4. Lógica de Negocio (`src/modules/reviews/service.py`)
- Función `create_review`: Insertar la reseña y sus fotos usando el servicio de almacenamiento.
- Función `delete_review`: Verificar que el usuario que intenta borrar la reseña sea realmente el dueño (`User.id == Review.user_id`).
- Función `toggle_favorite`: Si el registro en `Favorite` ya existe, eliminarlo. Si no existe, crearlo.
- **Integración:** Crear `calculate_average_rating(db, attraction_id) -> float`. 

#### 5. Integración con el Catálogo (`src/modules/catalog/service.py`)
- Importar tu nueva función `calculate_average_rating` y reemplazar el valor fijo (`None`) que actualmente tiene `get_attraction_detail` en el módulo de catálogo.

#### 6. Router (`src/modules/reviews/router.py`)
- Exponer los endpoints POST y DELETE protegidos por JWT (`Depends(get_current_user)`).

### Criterios de Aceptación (Tests Obligatorios en `test_reviews.py`)
- [ ] Intentar crear una reseña con calificación `0` o `6` debe fallar (HTTP 422).
- [ ] Intentar publicar una segunda reseña en el mismo lugar debe fallar (HTTP 409).
- [ ] Borrar una reseña usando un usuario distinto al autor original debe fallar (HTTP 403).
- [ ] Llamar a `toggle_favorite` dos veces seguidas sobre el mismo lugar debe crear el registro en el primer intento y borrarlo en el segundo.
- [ ] Intentar subir un PDF o una foto mayor a 5MB debe devolver un error 422.

---

## 🧑‍💻 Sección Gabriel: Módulo de Emergencias SOS (`emergency`)

### 👏 Reconocimiento y Evaluación del Sprint 1
* ¡Gran trabajo en la estructuración de `catalog`! Destacamos el uso sobresaliente del **Repository Pattern** para manejar consultas complejas (paginación, joins de imágenes y categorías), la implementación impecable del **Service Layer Pattern** para aislar las reglas de negocio (slugs, normalización de textos, reglas RN-01) y la claridad en las funciones Data Mapper para convertir entidades ORM a DTOs.

### 💡 Propuesta de Mejora (Patrones del Sprint 1 para incorporar en Sprint 2)
Aprovechando este sprint, refactorizaremos y aplicaremos los siguientes patrones clave:

1. **Adapter Pattern (para Integración con DIRCETUR y Notificaciones Externas):**
   - **Por qué usarlo:** En el Sprint 1 la descarga del padrón DIRCETUR (`_descargar_padron`) ejecutaba peticiones HTTP incrustadas directamente dentro de `catalog/service.py`. 
   - **Beneficios:** Extraer esa lógica a un `DirceturClientAdapter` (en `catalog/adapters/`) desacopla las peticiones HTTP del servicio de negocio. Si DIRCETUR cambia su endpoint o formato JSON, solo se modifica el Adapter sin tocar el servicio. Además, permite hacer *mocking* perfecto en los unit tests sin depender de internet.
2. **Observer / Dispatcher Pattern (para Eventos SOS de Emergencia):**
   - **Por qué usarlo:** En el módulo de emergencia SOS, tras registrar un incidente se deben ejecutar múltiples acciones (notificar autoridades, enviar emails, registrar auditoría).
   - **Beneficios:** Encapsular el dispatch de notificaciones Celery tras el registro del SOS evita acoplar el servicio de emergencia con los canales de notificación individuales.

---

### Contexto del Módulo
El objetivo es implementar un "Botón de Pánico". Es altamente crítico que este módulo sea resiliente (**Offline-First**). El turista que se pierde en el desierto enviará múltiples SOS cuando recupere la señal a medias. Para evitar saturar a la policía con duplicados, el celular enviará un ID único (`client_reference_id`). 

### Tareas Paso a Paso

#### 1. Modelos de Base de Datos (`src/modules/emergency/models.py`)
- Crear `SOSReport`:
  - `client_reference_id` (UUID, unique=True). Este es el pilar de la idempotencia.
  - `latitude` y `longitude` (Float).
  - `status` (Enum: pending, dispatched, resolved).
- Crear `EmergencyNotification`:
  - Para auditar si el correo o alerta ya fue enviado a las autoridades (relacionada al reporte SOS).

#### 2. Esquemas de Datos (`src/modules/emergency/schemas.py`)
- Crear `SOSCreate`: Usar Pydantic para validar estrictamente que la `latitude` esté entre -90 y 90, y la `longitude` entre -180 y 180.

#### 3. Lógica Transaccional (`src/modules/emergency/service.py`)
- Función `create_sos_report`:
  - Buscar en la tabla por `client_reference_id`. Si ya existe, **NO devolver error**. Devolver HTTP 200 y el reporte existente.
  - Si es nuevo, hacer `db.add()` y obligatoriamente un `db.commit()`.
  - **Crítico:** Solo después del commit, enviar la notificación asíncrona llamando a `enviar_notificaciones_sos.delay(report.id)`.

#### 4. Refactorización del Adaptador DIRCETUR (`src/modules/catalog/adapters/dircetur.py`)
- Mover la función `_descargar_padron` a un `DirceturAdapter` utilizando el patrón **Adapter**.
- Actualizar `sync_dircetur_registry` en `catalog/service.py` para usar este adaptador.

#### 5. Tareas en Segundo Plano (`src/modules/emergency/tasks.py`)
- En el archivo `tasks.py` (que ya está creado), implementar la lógica real de `enviar_notificaciones_sos()`.
- Puedes imprimir un log detallado o configurar un envío de email falso/simulado si el SMTP no está listo. 
- Implementar los reintentos (`autoretry_for`) nativos de Celery por si el envío falla.

#### 6. Router (`src/modules/emergency/router.py`)
- Crear `POST /api/v1/emergency/sos` protegido con JWT.
- Crear `GET /api/v1/emergency/sos/history` protegido con JWT (valida que devuelva solo el historial de ese usuario).

### Criterios de Aceptación (Tests Obligatorios en `test_emergency.py`)
- [ ] Enviar un payload de SOS sin latitud o longitud debe fallar (HTTP 422).
- [ ] Enviar **dos peticiones POST seguidas exactamente con el mismo `client_reference_id`**. Debe insertar solo 1 fila en la BD, y el segundo POST debe devolver HTTP 200 (idempotencia comprobada).
- [ ] Intentar acceder al historial de emergencias de *otro* usuario diferente al autenticado debe fallar (HTTP 403).
- [ ] Simular el endpoint SOS con `mock` y verificar que la tarea `enviar_notificaciones_sos.delay()` fue llamada correctamente 1 vez tras el commit.

---

## 🧑‍💻 Sección Paulo: Módulo Clima Completo y Handlers Globales
- Integración de los modelos y persistencia en DB para el clima (`WeatherSnapshot`, `WeatherAlert`).
- Aplicación de Regla RN-03 usando Redis (Caché por 6 horas).
- Integración del recomendador basado en Gemini AI (`ai_recommender.py`).
- Implementación de Handlers Globales en `core/exceptions.py` para mapeo automático de HTTP Status Codes.
