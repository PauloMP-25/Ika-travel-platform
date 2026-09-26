# Guía de Desarrollo y Asignación de Tareas — Backend

Este documento establece las responsabilidades, estándares de calidad y flujo de trabajo para el equipo de desarrollo backend del proyecto **Ika Travel & Experience**.

## 1. Organización del Equipo (Backend)

Para esta fase del proyecto (MVP), el trabajo de programación se dividirá entre los dos Desarrolladores Backend. Paulo asumirá el rol de Líder Técnico / QA, encargándose de las revisiones de código, pruebas de integración (Testing), control de calidad e infraestructura.

### 🧑‍💻 Desarrollador 1 (Enfoque en Identidad y Transacciones)
**Responsabilidades principales:**
1. **Módulo `users` (Auth):** Modelos, DTOs y Servicios para registro, login y dependencias de seguridad (JWT). *(Prioridad 1 - Bloqueante para el resto)*.
2. **Módulo `emergency` (SOS):** Reportes geolocalizados y sistema de notificaciones.
3. **Módulo `reviews` (Reseñas y Favoritos):** Calificación de atractivos y gestión de itinerarios.

### 🧑‍💻 Desarrollador 2 (Enfoque en Catálogo e Inteligencia)
**Responsabilidades principales:**
1. **Módulo `catalog` (Catálogo):** Modelos, DTOs y Servicios para Atractivos, Categorías, Agencias y Tours. *(Prioridad 1)*.
2. **Módulo `weather` (Clima e IA):** Integración de APIs meteorológicas, caché de datos climáticos y algoritmo de recomendación de IA.
3. **Módulo `geo`:** Trazado de rutas y validaciones de proximidad.

### 🕵️‍♂️ QA y Testing (Paulo)
- Revisión estricta de Pull Requests (PRs).
- Creación de pruebas unitarias y de integración (`pytest`).
- Pruebas de estrés y seguridad en los endpoints.
- Gestión de la base de datos y migraciones complejas de Alembic.

---

## 2. Flujo de Trabajo y Buenas Prácticas (Git)

Trabajaremos utilizando la estrategia **Git Flow simplificada**. Está estrictamente prohibido hacer commits directos a las ramas `main` o `develop`.

1. **Ramas de Funcionalidad (Feature Branches):**
   Cada nueva tarea o módulo debe realizarse en una rama propia creada a partir de `develop`.
   - *Formato:* `feature/nombre-del-modulo` (Ej. `feature/auth-jwt`, `feature/catalog-models`).

2. **Commits Convencionales (En español):**
   Cada commit debe describir exactamente qué cambió usando un prefijo válido:
   - `feat:` (nueva característica o modelo).
   - `fix:` (corrección de un error o bug).
   - `refactor:` (mejoras de código sin cambiar funcionalidad).
   - `chore:` (mantenimiento, configuración).
   - *Ejemplo:* `git commit -m "feat: crear modelo de base de datos para usuarios y roles"`

3. **Pull Requests (PR):**
   - Una vez finalizada la tarea, se debe abrir un PR hacia la rama `develop`.
   - **Obligatorio:** Solicitar revisión a Paulo (QA).
   - Paulo probará el código localmente, verificará las buenas prácticas y, si todo está correcto, aprobará y hará el "Merge".

---

## 3. Estándares de Calidad del Código (Python + FastAPI)

Para mantener el código limpio y escalable a microservicios, el código debe respetar la siguiente arquitectura de capas:

1. **Tipado Estricto (Type Hints):** 
   Todo el código Python debe llevar tipado (`def get_user(db: Session, user_id: UUID) -> User:`).
   
2. **Separación de Responsabilidades:**
   - **`router.py`:** SOLO recibe la petición, llama al servicio y devuelve la respuesta. **Prohibido** poner lógica de negocio o consultas SQL aquí.
   - **`service.py`:** Contiene toda la lógica (Ej. validar si el email existe, hashear contraseñas).
   - **`models.py`:** Solo declaraciones de SQLAlchemy.
   - **`schemas.py`:** Solo validaciones de Pydantic. Las contraseñas NUNCA deben ir en los esquemas de respuesta (Response).

3. **Manejo de Errores:**
   No utilicen `try/except` que oculten errores silenciosamente. Si una regla de negocio se rompe, lancen una excepción personalizada desde la capa de servicio y atrápenla con un manejador global en FastAPI (Ej. lanzando `HTTPException` con estado 400 o 404 de forma clara).

---
*Cualquier duda arquitectónica o bloqueo técnico deberá ser revisado en conjunto con el Líder de QA antes de avanzar.*
