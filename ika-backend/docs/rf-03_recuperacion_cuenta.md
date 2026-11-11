# RF-03 · Recuperación de cuenta por correo

Documento de cambios del módulo RF-03. Se actualiza **al final de cada etapa**.

- **Rama:** `feature/rf-03-password-reset` (creada desde `origin/main@9ba5592`)
- **Head de Alembic al inicio:** `d4af4f66c370`
- **Restricciones:** sin commits ni push, sin credenciales reales, sin tocar el
  módulo meteorológico ni las migraciones existentes, sin reutilizar las
  migraciones incompatibles de `backend-francis`.

---

## Decisiones funcionales confirmadas

| # | Decisión |
|---|----------|
| 1 | El enlace abre una pantalla de la app móvil |
| 2 | Esquema configurable: `ikatravel://reset-password?token={token}` |
| 3 | Duración del token: **30 minutos** |
| 4 | Token aleatorio, **de un solo uso**, nunca en texto claro en PostgreSQL |
| 5 | En PostgreSQL solo se guarda el **hash SHA-256** del token |
| 6 | Al cambiar la contraseña se invalidan **todos** los JWT emitidos antes |
| 7 | Correo vía **Gmail SMTP**: `smtp.gmail.com:587`, STARTTLS, credenciales solo de variables de entorno, **contraseña de aplicación** de Google |
| 8 | Cuentas creadas exclusivamente con Google no pueden fijar contraseña local |
| 9 | Respuesta HTTP **idéntica** para correos existentes, inexistentes, inactivos o solo-Google → **202** con mensaje genérico |
| 10 | Rate limit: **5 por IP cada 15 min** y **3 por correo cada hora** |
| 11 | La IP solo vive temporalmente en **Redis**; jamás en PostgreSQL |
| 12 | Correos en **es/en** según `preferred_language` |
| 13 | Logs sin tokens, enlaces completos, contraseñas, credenciales SMTP ni cuerpos |
| 14 | El enlace se construye **únicamente** con `PASSWORD_RESET_URL_TEMPLATE` (nunca la cabecera `Host`) |
| 15 | Token inválido/vencido/usado/invalidado → **HTTP 400** + `{"detail": "El enlace de recuperación no es válido o ha expirado.", "codigo": "RESET_TOKEN_INVALIDO"}` |
| 16 | Éxito de `/reset` → **HTTP 200** + `{"detail": "Tu contraseña ha sido restablecida correctamente."}` (no fijado por el RF; pendiente de confirmación) |

---

## Estado por etapas

- [x] **Etapa 1** — Configuración SMTP + servicio de correo (`EmailSender`, `SMTPEmailSender`, `MockEmailSender`)
- [x] **Etapa 2** — Persistencia: `PasswordResetToken`, `password_changed_at`, migración Alembic reversible, repositorio
- [x] **Etapa 3** — Endpoints `forgot`/`reset`, rate limit, tokens de un solo uso, invalidación de JWT, cuentas Google
- [x] **Etapa 4** — Batería completa de pruebas y revisión final

---

## Etapa 1 — Servicio de correo

### Archivos creados

| Archivo | Contenido |
|---|---|
| `src/modules/users/email.py` | `EmailSender` (ABC), `SMTPEmailSender`, `Correo`, `validar_configuracion_email()`, `contenido_plantilla()` (ES/EN, `reset` y aviso `google`), `construir_enlace_reset()`, `_enmascarar()` para logs |
| `tests/modules/fakes.py` | `MockEmailSender` (captura mensajes, sin red) |
| `tests/modules/test_password_reset.py` | Pruebas de la Etapa 1 |

### Archivos modificados

| Archivo | Cambio |
|---|---|
| `src/core/config.py` | `SMTP_HOST/PORT/STARTTLS/USER/PASSWORD/FROM/TIMEOUT_SEGUNDOS`, `PASSWORD_RESET_URL_TEMPLATE`, `PASSWORD_RESET_TOKEN_TTL_MINUTES` |
| `.env.example` | Mismas variables documentadas, sin credenciales reales |

### Comportamiento clave

- Validación de configuración **al iniciar** (`__init__` del sender): el error
  nombra solo **variables**, nunca valores.
- `smtplib` corre en el pool de hilos de `anyio.to_thread` (no bloquea el loop).
- STARTTLS con `ssl.create_default_context()`.
- El enlace sale **solo** de `PASSWORD_RESET_URL_TEMPLATE`.
- Los logs registran el destino **enmascarado** (`v***@ika.pe`).

### Pruebas de la etapa

`tests/modules/test_password_reset.py` → **19 passed**.

---

## Etapa 2 — Persistencia

### Archivos creados

| Archivo | Contenido |
|---|---|
| `alembic/versions/e5c1a7b93f28_add_password_reset_tokens.py` | Migración reversible encadenada a `d4af4f66c370` (head nuevo) |

### Archivos modificados

| Archivo | Cambio |
|---|---|
| `src/modules/users/models.py` | Columna `users.password_changed_at` (anulable, `timestamptz`) + modelo `PasswordResetToken` |
| `src/modules/users/repository.py` | `add_password_reset_token`, `get_password_reset_token_by_hash`, `invalidate_active_tokens`, `mark_token_used` |
| `tests/modules/test_migrations.py` | Head actualizado a `e5c1a7b93f28` (antes fallaba por esperar `8db9ab3bcce4`) |
| `tests/modules/test_password_reset.py` | +8 pruebas de la Etapa 2 |

### Esquema resultante

```
password_reset_tokens
  id            UUID PK
  user_id       UUID NOT NULL  → users.id ON DELETE CASCADE
  token_hash    VARCHAR(64) NOT NULL  UNIQUE  (uq_password_reset_tokens_token_hash)
  created_at    timestamptz NOT NULL  default now()
  expires_at    timestamptz NOT NULL
  used_at       timestamptz NULL
  índice: ix_password_reset_tokens_user_id (user_id)

users.password_changed_at  timestamptz NULL
```

- **Solo el hash SHA-256** del token se persiste; el valor en claro jamás llega a PostgreSQL.
- `invalidate_active_tokens()` lanza **un único `UPDATE`** dentro de la misma
  transacción que inserta el token nuevo → siempre queda **un solo token activo**.
- `mark_token_used()` es un **compare-and-set** (`UPDATE … WHERE used_at IS NULL`):
  ante dos peticiones simultáneas con el mismo token, solo una obtiene
  `rowcount == 1`.
- `used_at` se marca también al **invalidar** por una solicitud posterior (no
  existe otra columna de estado y la respuesta de error es idéntica en ambos casos).

### Verificación de la migración (una vez, en BD desechable)

Aplicada con `alembic upgrade head` sobre `ika_travel_migracion_check`:
columnas y restricciones **coinciden con los modelos** (PK, `UNIQUE (token_hash)`,
FK `ON DELETE CASCADE`, `users.password_changed_at`), y `alembic downgrade -1`
elimina la tabla y la columna. La BD desechable se borró al terminar.

### Pruebas de la etapa

`tests/modules/test_password_reset.py` → **27 passed** (19 + 8).

---

## Etapa 3 — Endpoints, rate limit, tokens y JWT

### Archivos modificados

| Archivo | Cambio |
|---|---|
| `src/core/config.py` | Límites: `PASSWORD_RESET_MAX_POR_IP=5`, `VENTANA_IP_SEGUNDOS=900`, `MAX_POR_CORREO=3`, `VENTANA_CORREO_SEGUNDOS=3600` |
| `.env.example` | Mismas variables documentadas |
| `src/core/rate_limit.py` | Nuevo `limit_by_key(redis, scope, clave, max, ventana)`; `limit_requests` queda como envoltorio por IP |
| `src/core/security.py` | `segundos_enteros()`, `hash_token_reset()` (SHA-256 hex), `decode_access_token_payload()` (expone `iat`) |
| `src/modules/users/dependencies.py` | `jwt_valido_para_el_usuario()` + rechazo en `get_current_user`; `limit_password_reset_ip` |
| `src/modules/users/schemas.py` | `ForgotPasswordRequest`, `ResetPasswordRequest` |
| `src/modules/users/exceptions.py` | `ResetTokenInvalidoException` (400, `RESET_TOKEN_INVALIDO`) |
| `src/modules/users/service.py` | `solicitar_recuperacion()`, `restablecer_password()`, `admite_password_local()`, `MENSAJE_RECUPERACION_GENERICO` |
| `src/modules/users/router.py` | `POST /auth/password/forgot` (202) y `POST /auth/password/reset` |
| `tests/modules/fakes.py` | `FakeRedis` (contadores de ventana fija en memoria) |
| `tests/modules/test_password_reset.py` | +15 pruebas de la Etapa 3 |

### Comportamiento clave

**`POST /api/v1/auth/password/forgot` → 202 siempre**

```
dependencies=[Depends(limit_password_reset_ip)]   # 5/IP/15 min
→ limit_by_key por correo (3/hora)                # clave solo en Redis
→ usuario inexistente / inactiva → sin token, sin correo, mismo 202
→ cuenta exclusivamente Google  → sin token, aviso informativo, mismo 202
→ cuenta elegible               → token (30 min), invalida previos, correo
```

- Respuesta **idéntica** en los cuatro casos:
  `{"detail": "Si el correo está registrado, recibirás instrucciones para recuperar tu cuenta."}`
- Un fallo de SMTP **no cambia** la respuesta (solo se loguea el *tipo* de
  excepción): si el envío falla también se responde 202.
- El enlace sale **solo** de `PASSWORD_RESET_URL_TEMPLATE`.

**`POST /api/v1/auth/password/reset`**

- Token no encontrado / vencido / ya usado / invalidado → **400**
  `{"detail": "El enlace de recuperación no es válido o ha expirado.", "codigo": "RESET_TOKEN_INVALIDO"}` (el token nunca aparece en la respuesta).
- Éxito → **200** `{"detail": "Tu contraseña ha sido restablecida correctamente."}` *(estado no fijado por el RF; comentar si se prefiere otro)*.
- `mark_token_used()` es un **compare-and-set**: ante dos peticiones
  simultáneas con el mismo token solo una gana (probado con `asyncio.gather`).
- Tras el cambio: `password_hash` nuevo, `password_changed_at = now`, y se
  invalidan los tokens restantes.

**Invalidación de JWT**

- `get_current_user` rechaza cualquier JWT cuyo `iat` (segundos enteros) sea
  anterior a `users.password_changed_at` → 401 `credenciales_invalidas`.
- La comparación usa `segundos_enteros()` (truncado, no redondeo) para no
  rechazar tokens emitidos en el mismo segundo del cambio.

### Pruebas de la etapa

`tests/modules/test_password_reset.py` → **42 passed** (27 + 15).

Cubren: 202 con correo existente + hash SHA-256 en BD + TTL 30 min; 202
idéntico para inexistente/inactiva/Google-only (misma respuesta en los 4
casos); reset correcto con login nuevo y rechazo de la contraseña antigua;
token vencido/reutilizado/invalidado → 400 genérico; carrera de dos
peticiones simultáneas; JWT anterior rechazado y posterior aceptado; rate
limit por IP (429 al 6º) y por correo (429 al 4º).

---

## Etapa 4 — Batería completa y revisión final

### Archivos modificados

| Archivo | Cambio |
|---|---|
| `tests/modules/test_password_reset.py` | +13 pruebas de la Etapa 4 (total del archivo: **55**) |
| `docs/rf-03_recuperacion_cuenta.md` | Cierre de la Etapa 4 |

### Pruebas añadidas (cubren los huecos de la lista requerida)

| Requisito | Prueba |
|---|---|
| Fallo de SMTP mantiene el 202 | `test_fallo_de_envio_sigue_respondiendo_202` |
| Payload inválido (`forgot`) → 422 | `test_payload_invalido_de_forgot_devuelve_422` |
| Payload inválido (`reset`) → 422 | `test_payload_invalido_de_reset_devuelve_422` |
| Mensaje de éxito exacto de `/reset` | `test_respuesta_de_exito_de_reset` |
| `password_changed_at` se fija al cambiar | `test_reset_actualiza_password_changed_at` |
| Correo en español según `preferred_language` | `test_correo_en_espanol_por_preferred_language` |
| Correo en inglés según `preferred_language` | `test_correo_en_ingles_por_preferred_language` |
| Idioma desconocido cae a `es` (fin a fin) | `test_idioma_desconocido_usa_espanol_en_el_flujo` |
| Enlace = `PASSWORD_RESET_URL_TEMPLATE` (fin a fin, ignorando `Host`) | `test_enlace_del_correo_sale_de_la_plantilla_de_entorno` |
| Sin token/contraseña/enlace en logs (flujo completo + ruta de error) | `test_logs_del_flujo_no_contienen_token_ni_password` |
| Sin credenciales SMTP en logs | `test_logs_no_contienen_credenciales_smtp_durante_el_flujo` |
| La IP no se persiste en PostgreSQL | `test_la_ip_no_se_persiste_en_postgresql` |
| La migración no toca tablas ajenas (clima, etc.) | `test_migracion_no_modifica_tablas_ajenas` |

### Notas de diseño de los tests de logs

- `test_logs_del_flujo_no_contiene_token_ni_password` fuerza `caplog` en
  `DEBUG` sobre **todo** el flujo (solicitud → reset → token inválido) y
  además ejercita el registro real del sender (con `SMTPFalso`, sin red) para
  que el test no pueda pasar de forma vacía (`assert caplog.records`).
- `test_enlace_del_correo_sale_de_la_plantilla_de_entorno` envía una
  petición con la cabecera `Host: atacante.ejemplo` y verifica que el enlace
  emitido sigue saliendo solo de la variable de entorno.

### Revisión final (restricciones cumplidas)

- [x] Rama creada desde la última versión de `origin/main` (`9ba5592`)
- [x] Sin commits ni push en este cambio
- [x] Sin credenciales reales (`.env.example` con valores vacíos)
- [x] No se modificaron migraciones existentes (solo se añade `e5c1a7b93f28`)
- [x] No se mezclan migraciones de `backend-francis`
- [x] Módulo meteorológico intacto (la migración RF-03 solo toca `users` + crea `password_reset_tokens`)
- [x] Sin dependencias nuevas instaladas (`smtplib`/`ssl`/`anyio`/`hashlib` son de la stdlib o ya presentes)
- [x] IP solo en Redis con TTL; ninguna columna de IP en PostgreSQL
- [x] Logs sin tokens, enlaces, contraseñas, credenciales SMTP ni cuerpos

### Pruebas de la etapa

`tests/modules/test_password_reset.py` → **55 passed** (42 + 13).
Suite completa → **236 passed, 0 failed** (1 deseccionado: test `live` de la suite preexistente).

---

## Entorno (reparaciones, no son cambios de código)

1. **`ika_travel_test` tenía esquema obsoleto** respecto a los modelos
   (`weather_alert` con columnas antiguas `attraction_id`/`is_active` y sin
   `read`/`read_at`). La FK sobrante impedía el `drop_all` del conftest y
   producía **67 errores** en toda la suite. Reparado con
   `DROP SCHEMA public CASCADE; CREATE SCHEMA public;`.
2. **Redis no corre en local** → los tests de rate limit inyectan un doble vía
   `app.dependency_overrides[obtener_cliente_redis]`.
3. `test_migrations.py::test_la_ultima_revision_es_la_del_sprint_4` **ya
   fallaba en `origin/main`** (esperaba `8db9ab3bcce4`, el head era
   `d4af4f66c370`). **Actualizado en la Etapa 2** a `e5c1a7b93f28` y renombrado
   a `test_la_ultima_revision_es_la_del_rf_03`.

### Baseline de la suite

| Momento | Resultado |
|---|---|
| `origin/main` + Etapa 1, antes de reparar la BD | 1 failed, 132 passed, **67 errors** |
| Tras reparar la BD (fin de la Etapa 1) | 1 failed, **199 passed**, 0 errors |
| Fin de la Etapa 2 | **208 passed, 0 failed** |
| Fin de la Etapa 3 | **223 passed, 0 failed** |

---

## Registro de cambios

| Fecha | Etapa | Detalle |
|---|---|---|
| 2026-11-11 | — | Rama `feature/rf-03-password-reset` creada desde `origin/main@9ba5592`; verificación de árbol limpio, head de Alembic y revisión de `users`/JWT/Redis/Celery/config/excepciones/pruebas |
| 2026-11-11 | 1 | Configuración SMTP + `EmailSender`/`SMTPEmailSender`/`MockEmailSender` + plantillas ES/EN + 19 pruebas |
| 2026-11-11 | 2 | Modelo `PasswordResetToken` + `users.password_changed_at` + migración reversible `e5c1a7b93f28` + repositorio + 8 pruebas; test de head actualizado |
| 2026-11-11 | — | Reparación del esquema obsoleto de `ika_travel_test` (67 errores → 0) |
| 2026-11-11 | 3 | Endpoints `forgot`/`reset`, rate limit por IP y por correo, tokens de un solo uso, invalidación de JWT por `iat`, cuentas Google + 15 pruebas |
| 2026-11-11 | 4 | Batería final: 13 pruebas (logs del flujo, idioma ES/EN fin a fin, enlace desde variable con `Host` hostil, 422, fallo SMTP → 202, `password_changed_at`, IP ausente de PG, migración sin tablas ajenas); suite completa 236 passed |
