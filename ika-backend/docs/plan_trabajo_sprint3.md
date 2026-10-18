# Plan de Trabajo Operativo — Sprint 4 (Hardening Total del Backend, IA Gemini, Google Login y Optimización)

**Proyecto:** Ika Travel & Experience — Backend  
**Rama Base Obligatoria:** `develop`  
**Equipo Responsable:** Francis (Desarrollador Backend) y Paulo (Lead Developer / Arquitecto)  
**Documentos de Referencia:** [`docs/sprint_4.md`](file:///home/paulo/Documentos/Cursos/Ciclo08/Diseño%20de%20Software/codigo_fuente/ika-backend/docs/sprint_4.md) y [`docs/plan_arquitectura_sprint3.md`](file:///home/paulo/Documentos/Cursos/Ciclo08/Diseño%20de%20Software/codigo_fuente/ika-backend/docs/plan_arquitectura_sprint3.md)

---

## 1. Reglas Estrictas de Desarrollo y Git

1. **Creación de Ramas a partir de `develop`:**
   - Todo trabajo del Sprint 4 debe originarse estrictamente desde la rama `develop` (`git checkout develop && git pull origin develop`).
   - Se crean ramas temáticas de trabajo aisladas:
     - Paulo: `feature/weather-aggregator-alerts` y `feature/gemini-ai-recommender`
     - Francis: `feature/google-social-login`, `feature/db-optimization-indexes` y `feature/offline-idempotency-contracts`
   - Queda terminantemente prohibido hacer commits directos sobre `develop` o `main`.

2. **Limpieza de Ramas Obsoletas:**
   - Las ramas fusionadas de sprints previos deben mantenerse eliminadas para conservar un historial limpio (`git branch -d <rama>`). Solo permanecen activas `main`, `develop` y las ramas de feature del sprint en curso.

3. **Commits Convencionales en Español:**
   - Todo commit debe respetar rigurosamente la especificación de **Conventional Commits en español**.
   - Prefijos permitidos: `feat:`, `fix:`, `docs:`, `style:`, `refactor:`, `test:`, `chore:`.
   - Formato requerido para cambios importantes:
     ```bash
     git commit -m "prefijo: mensaje corto" -m "Descripción detallada en español del cambio realizado.\nFecha y hora: $(date +'%Y-%m-%d %H:%M:%S')"
     ```

4. **Regla de Aceptación del 100% de Pruebas (DoD):**
   - **Ninguna tarea se considera terminada (Done) si no pasa el 100% de las pruebas automatizadas.**
   - Línea base de partida: **119 tests exitosos** en `pytest`.
   - Meta mínima de finalización del Sprint 4: **≥ 135 tests (objetivo recomendado: ~150 tests al 100%)**.
   - Cero regresiones en módulos existentes (`users`, `catalog`, `emergency`, `reviews`, `geo`, `translation`, `analytics`). Cobertura ≥ 85% en componentes nuevos/modificados.

---

## 2. Ajustes Pre-flight y Decisiones Técnicas Confirmadas

| Elemento | Realidad en Código / Arquitectura | Decisión Operativa para Sprint 4 |
|---|---|---|
| **Manejo de Errores** | `ErrorDeNegocio` base con `codigo_http`, `codigo` y mensaje en español | Crear subclases específicas (`StaleWeatherDataException`, `SocialAuthInvalidTokenException`, `ConsentRequiredException`, etc.) con códigos de error claros. |
| **Respaldo de Clima (RN-03)** | Snapshot en PostgreSQL y caché Redis (TTL 6 h = 21 600 s) | Control estricto anti-stampede con lock Redis. Si un dato tiene > 6 h en BD y los proveedores fallan, devolver 503 `CLIMA_DESACTUALIZADO`. |
| **Latencia del Fallback IA** | Cálculo algorítmico determinista puro sin I/O | Garantizar tiempo de ejecución p95 < 150 ms en test de rendimiento con 1 000 ejecuciones. |
| **Google Login & Ley 29733** | Verificación de ID Token OAuth2 | Validar `id_token` en hilo asíncrono con `anyio.to_thread.run_sync`. Exigir consentimiento expreso de política de datos si el usuario es nuevo. |
| **Idempotencia en Emergencias** | Header `Idempotency-Key` en `/sos` y `/reports` | Evitar duplicación de registros y despachos Celery ante reintentos por conectividad intermitente en Ica. |
| **Optimización de BD** | Escaneos secuenciales en filtros y analítica | Crear 8 índices en migración Alembic única y documentar antes/después con `EXPLAIN (ANALYZE, BUFFERS)`. |

---

## 3. Matriz de Asignación y Secuencia de Ejecución

### 👤 Paulo (Lead Developer / Arquitecto) — Clima, Alertas e IA Gemini

- **P1 — Auditoría y Resiliencia del Aggregator Multiventana (`weather/`):**
  - Timeout individual de 3 s por proveedor (`WEATHER_PROVIDER_TIMEOUT_SECONDS`).
  - Quórum mínimo de 1 proveedor exitoso; manejo de errores parciales sin degradar la respuesta completa.
  - Normalización unificada de unidades meteorológicas.
- **P2 — Motor Puro de Alertas Meteorológicas de Ica:**
  - Función pura `evaluar_alertas(snapshot, zona) -> list[AlertaCandidata]` testeable sin base de datos ni I/O.
  - Detección de Viento Paracas (≥ 25, ≥ 35, ≥ 50 km/h), Radiación UV extrema (escala OMS 8-10, 11, ≥ 12), altas temperaturas desérticas (≥ 33, ≥ 37, ≥ 40 °C) y lluvia.
  - Upsert de alertas activas en BD con expiración alineada a 6 horas.
- **P3 — Cache-Aside RN-03 en Redis & Celery Beat:**
  - Claves `weather:snapshot:{id}` y `weather:alerts:{id}` con TTL de 21 600 s (6 horas).
  - Mecanismo anti-stampede con lock Redis (`weather:lock:{id}`).
  - Celery Beat cada 3 horas para refresco proactivo antes de expiración.
- **P4 — Recomendador Dinámico con Google Gemini AI:**
  - Salida estructurada Pydantic v2 `RecomendacionEnriquecida` con SDK `google-genai`.
  - Mapeo de las 5 categorías oficiales PERTUR/PROMPERÚ y los 5 atractivos piloto (Huacachina, Paracas, Ocucaje, Nazca, Centro Histórico).
  - Guardarraíl de seguridad: si existe alerta `danger`, el score se acota a ≤ 0.3 y se fuerza la advertencia climática.
  - Timeout de Gemini fijado en 2.5 s con degradación limpia.
- **P5 — Fallback Determinista < 150 ms:**
  - Generador determinista de recomendaciones en base a reglas climáticas de Ica cuando la IA falle o demore.
  - Marcado explícito de `source="fallback"`.
- **P6 — Formato Enriquecido Bilingüe (`es`/`en`):**
  - Justificación climática, indumentaria requerida, precauciones y nivel de visibilidad adaptados al idioma del turista.
- **P7 — Suite de Validación Meteorológica e IA:**
  - Pruebas parametrizadas de umbrales y escenarios reales de Ica (~16 tests nuevos).

### 👤 Francis (Desarrollador Backend) — Auth Social, BD & Contratos Offline

- **F1 — Autenticación Social con Google (`users/`):**
  - Patrón Strategy para autenticación social (`GoogleAuthStrategy` bajo `EstrategiaAutenticacionSocial`).
  - Endpoint `POST /api/v1/auth/login/google` validando `id_token` de Google (firma, expiración, emisor, audiencia y correo verificado).
  - Cumplimiento de Ley N° 29733: solicitud de consentimiento informado si el usuario es nuevo (código `CONSENTIMIENTO_REQUERIDO`).
  - Vinculación transparente con cuentas locales existentes por correo verificado sin duplicar usuarios.
  - Emisión de JWT estándar con rol `tourist` y persistencia limpia sin almacenar credenciales externas sensibles.
- **F2 — Optimización de Base de Datos PostgreSQL:**
  - Creación de 8 índices estratégicos para acelerar consultas críticas (categorías de atractivos, promedio de calificaciones en reseñas, orden cronológico de eventos analíticos, reportes DIRCETUR y búsqueda espacial).
  - Medición y documentación formal de mejoras con `EXPLAIN (ANALYZE, BUFFERS)` en `docs/optimizacion_bd.md`.
- **F3 — Contratos de Caché HTTP con ETag (304 Not Modified):**
  - Generación de ETag basada en contenido para `/catalog/attractions` y `/catalog/agencies`.
  - Soporte de header `If-None-Match` para permitir validación condicional offline-first sin retransferir datos.
- **F4 — Soporte de Idempotencia en Reportes Críticos:**
  - Manejo de cabecera `Idempotency-Key` en `POST /emergency/sos` y `POST /emergency/reports`.
  - Detección de peticiones repetidas, respuesta idéntica con header `Idempotent-Replayed: true` y bloqueo de duplicación en tareas Celery.
- **F5 — Migraciones y Control de Esquema Alembic:**
  - Consolidación de migraciones de índices y esquemas bajo una única línea de revisión (`alembic heads` = 1 línea).
- **F-Tests — Pruebas Automatizadas:**
  - Tests unitarios y de integración para Google Auth, ETag, Idempotencia y verificación de índices (~18 tests nuevos).

---

## 4. Criterio de Integración y Cierre del Sprint 4 (DoD)

1. Revisión cruzada obligatoria de Pull Requests entre Paulo y Francis.
2. Ejecución integral de la suite de pruebas automatizadas: **≥ 135 tests en verde (meta ~150)** con 0 regresiones.
3. Verificación de migraciones: `alembic upgrade head` y `downgrade -1` limpios sobre base de datos aislada.
4. Documento `docs/optimizacion_bd.md` completo con métricas de rendimiento reales.
5. Fusión formal hacia `develop`, creación de la etiqueta Git `sprint-4` y preparación de la base técnica para el Sprint 5 (Integración con Flutter Mobile).
