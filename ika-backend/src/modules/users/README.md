# Módulo `users` — Autenticación y perfil

Estado: **funcional** (registro, login JWT, perfil). Autor: Dev 1.

## Endpoints

| Método | Ruta | Acceso | Descripción |
|---|---|---|---|
| POST | `/api/v1/auth/register` | público | Registro con email/contraseña → 201 |
| POST | `/api/v1/auth/login` | público | Devuelve `TokenResponse` (JWT) |
| GET | `/api/v1/users/me` | JWT | Perfil del usuario autenticado |
| PUT | `/api/v1/users/me` | JWT | Actualiza `full_name` / `phone` |

## Estructura

- `models.py` → `User` (usa la `Base` compartida de `src/core/database.py`)
- `schemas.py` → DTOs de Pydantic (**nunca** exponen `password_hash`)
- `exceptions.py` → excepciones de dominio + su manejador HTTP (autocontenido)
- `repository.py` → consultas `AsyncSession` puras, sin lógica de negocio
- `service.py` → toda la lógica de negocio (registro, autenticación, perfil)
- `dependencies.py` → `oauth2_scheme`, `get_current_user`, `CurrentUser`, `DbSession`
- `router.py` → solo recibe, delega en `service` y responde
- `../security.py` (en `core/`) → hashing bcrypt y firma/validación de JWT

---

## ⚠️ Ajustes pendientes de Paulo (no los he tocado)

### 1. `src/main.py` — registrar el módulo (2 líneas)
```python
from src.modules.users.router import users_router
from src.modules.users.exceptions import register_users_exception_handlers

app.include_router(users_router, prefix="/api/v1", tags=["users"])
register_users_exception_handlers(app)   # sin esto, las excepciones dan 500
```
> El `prefix="/api/v1"` es obligatorio: `oauth2_scheme` apunta a
> `/api/v1/auth/login` para el botón "Authorize" de Swagger.

### 2. `src/core/config.py` — ampliar `Settings`
`DATABASE_URL` es **obligatoria** para importar cualquier módulo (si no hay
`.env`, `Settings()` falla al arrancar la app y al recoger los tests).
Además, `src/core/security.py` hoy lee estas tres variables del entorno
(marcado con `TODO(Paulo)`); cuando existan en `Settings`, se sustituye el
`os.getenv`:
```python
SECRET_KEY: str
ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440
JWT_ALGORITHM: str = "HS256"
```

### 3. `requirements.txt` — dependencias que necesita este módulo
`passlib[bcrypt]`, `bcrypt`, `PyJWT`, `email-validator` (para `EmailStr`);
y para tests: `pytest`, `httpx`.

### 4. Alembic — migración de la tabla `users`
No he creado migraciones (son infraestructura general). La tabla definida en
`models.py` es `users`: `id (uuid PK)`, `email (unique, index)`,
`password_hash (nullable)`, `full_name`, `phone (nullable)`,
`auth_provider (enum: email|google|facebook)`, `provider_id (nullable)`,
`is_active (bool)`, `created_at`, `updated_at`.

### 5. Bases de datos creadas por mí (constancia)
Antes de conocer el reparto de responsabilidades creé con `postgres:admin`:
`ika_travel` y `ika_travel_test`. **No he tocado PostgreSQL desde entonces.**
La URL oficial del equipo es la de `.env.example`
(`ika_user:ika_password@.../ika_travel_db`), así que queda a criterio de
Paulo eliminarlas o reutilizarlas.

---

## Notas de implementación

- **Persistencia asíncrona:** todo el módulo usa `AsyncSession` (asyncpg),
  en línea con `src/core/database.py`.
- **Excepciones:** `UsersException` (base) con `status_code` → `409` /
  `401` / `403`, traducidas por `register_users_exception_handlers`.
  El módulo **no** depende de `src/core/exceptions.py`.
- **Tests:** `tests/modules/test_users.py` son unitarios aislados (sin BD,
  sin red): usan un `FakeSession` y repositorios parcheados.
- **Pendiente (fuera de este sprint):** login social OAuth
  (`service.authenticate_oauth`) y las relationships `reviews` / `favorites`
  / `sos_reports`, que se añadirán cuando existan esos modelos.
