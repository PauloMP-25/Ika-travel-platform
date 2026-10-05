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

## Sección Francis: Módulo de Reseñas y Favoritos (`reviews`)

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

#### 2. Subida de Archivos (`src/shared/storage.py`)
- Crear un módulo utilitario que reciba un archivo (`UploadFile` de FastAPI).
- Validar que sea una imagen (MIME type `image/jpeg`, `image/png`) y que pese menos de 5MB (usando `config.MAX_UPLOAD_MB`).
- Guardar el archivo en disco (usando `config.UPLOADS_DIR`) y devolver la URL pública.

#### 3. Esquemas de Datos (`src/modules/reviews/schemas.py`)
- Crear `ReviewCreate`: Valida que `rating` esté entre 1 y 5 usando Pydantic `Field(ge=1, le=5)`.
- Crear los esquemas de respuesta para reseñas y favoritos, cuidando de NO exponer información sensible del usuario (ej. email o hash de contraseña).

#### 4. Lógica de Negocio (`src/modules/reviews/service.py`)
- Función `create_review`: Insertar la reseña y sus fotos.
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

## Sección Gabriel: Módulo de Emergencias SOS (`emergency`)

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

#### 4. Tareas en Segundo Plano (`src/modules/emergency/tasks.py`)
- En el archivo `tasks.py` (que ya está creado), implementar la lógica real de `enviar_notificaciones_sos()`.
- Puedes imprimir un log detallado o configurar un envío de email falso/simulado si el SMTP no está listo. 
- Implementar los reintentos (`autoretry_for`) nativos de Celery por si el envío falla.

#### 5. Router (`src/modules/emergency/router.py`)
- Crear `POST /api/v1/emergency/sos` protegido con JWT.
- Crear `GET /api/v1/emergency/sos/history` protegido con JWT (valida que devuelva solo el historial de ese usuario).

### Criterios de Aceptación (Tests Obligatorios en `test_emergency.py`)
- [ ] Enviar un payload de SOS sin latitud o longitud debe fallar (HTTP 422).
- [ ] Enviar **dos peticiones POST seguidas exactamente con el mismo `client_reference_id`**. Debe insertar solo 1 fila en la BD, y el segundo POST debe devolver HTTP 200 (idempotencia comprobada).
- [ ] Intentar acceder al historial de emergencias de *otro* usuario diferente al autenticado debe fallar (HTTP 403).
- [ ] Simular el endpoint SOS con `mock` y verificar que la tarea `enviar_notificaciones_sos.delay()` fue llamada correctamente 1 vez tras el commit.

---

## Sección Paulo: Módulo Clima Completo y Handlers Globales
- Integración de los modelos y persistencia en DB para el clima (`WeatherSnapshot`, `WeatherAlert`).
- Aplicación de Regla RN-03 usando Redis (Caché por 6 horas).
- Integración del recomendador basado en Gemini AI (`ai_recommender.py`).
- Implementación de Handlers Globales en `core/exceptions.py` para mapeo automático de HTTP Status Codes.
