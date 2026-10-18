# Plan de Trabajo Operativo — Sprint 3 (Translation & Analytics DIRCETUR)

**Proyecto:** Ika Travel & Experience — Backend  
**Rama Base Obligatoria:** `develop`  
**Equipo Responsable:** Francis (Desarrollador Backend) y Paulo (Lead Developer / Arquitecto)  
**Documentos de Referencia:** [`docs/sprint_3.md`](file:///home/paulo/Documentos/Cursos/Ciclo08/Diseño%20de%20Software/codigo_fuente/ika-backend/docs/sprint_3.md) y [`docs/plan_arquitectura_sprint3.md`](file:///home/paulo/Documentos/Cursos/Ciclo08/Diseño%20de%20Software/codigo_fuente/ika-backend/docs/plan_arquitectura_sprint3.md)

---

## 1. Reglas Estrictas de Desarrollo y Git

1. **Creación de Ramas a partir de `develop`:**
   - Todo trabajo del Sprint 3 debe originarse estrictamente desde la rama `develop` (`git checkout develop && git pull origin develop`).
   - Se crean dos ramas de trabajo aisladas:
     - Francis: `feature/translation-module`
     - Paulo: `feature/analytics-dircetur`
   - Queda terminantemente prohibido hacer commits directos sobre `develop` o `main`.

2. **Limpieza de Ramas Obsoletas:**
   - Las ramas fusionadas de sprints o features previas deben ser eliminadas local y remotamente para mantener un historial limpio (`git branch -d <rama>`). Solo permanecen activas `main`, `develop` y las ramas activas del sprint actual.

3. **Commits Convencionales en Español:**
   - Todo commit debe respetar rigurosamente la especificación de **Conventional Commits en español**.
   - Prefijos permitidos: `feat:`, `fix:`, `docs:`, `style:`, `refactor:`, `test:`, `chore:`.
   - Para cambios importantes o estructurales, incluir descripción detallada:
     ```bash
     git commit -m "prefijo: mensaje corto" -m "Descripción detallada del cambio realizado.\nFecha y hora: $(date +'%Y-%m-%d %H:%M:%S')"
     ```

4. **Regla de Aceptación del 100% de Pruebas (DoD):**
   - **Ninguna tarea o parte de un compañero se considera "Terminada" (Done) si no pasa el 100% de los tests automatizados.**
   - La suite parte de **76 tests exitosos** y debe finalizar el sprint con **≥ 125 tests al 100%** (`pytest`).
   - Antes de abrir un Pull Request hacia `develop`, el desarrollador debe ejecutar la suite completa en su entorno y certificar 0 fallos, 0 regresiones y cobertura ≥ 85% en el código nuevo.

---

## 2. Ajustes Pre-flight Confirmados sobre la Arquitectura de Claude

Al contrastar el documento de Claude con el código fuente real del proyecto, se determinaron los siguientes ajustes exactos:

| Elemento | Supuesto de Claude | Realidad en el Código Fuente | Ajuste a Aplicar |
|---|---|---|---|
| **Excepciones** | `ErrorDeNegocio(detail, codigo, status_code)` | `ErrorDeNegocio` usa atributos de clase `codigo_http`, `codigo` y constructor `__init__(mensaje)` | Subclases definen `codigo_http = ...`, `codigo = "..."` y heredan limpiamente de `ErrorDeNegocio` (ej. como en `src/modules/reviews/exceptions.py`). |
| **Cliente Redis** | Función `obtener_redis()` | `src/redis_client.py` expone `obtener_cliente_redis()` y funciones helper `cache_obtener_json` / `cache_guardar_json` | Inyectar `obtener_cliente_redis` en las dependencias de FastAPI. |
| **Configuración** | `GEMINI_MODEL` | `src/core/config.py` define `GEMINI_MODELO = "gemini-2.5-flash"` | Usar `configuracion.GEMINI_MODELO` en el proveedor de traducción. |
| **Tablas** | Nombre singular/plural | `attraction` (singular), `users` (plural), `reviews` (plural), `favorites` (plural) | Respetar las claves foráneas exactas: `ForeignKey("attraction.id")` y `ForeignKey("users.id")`. |
| **Roles y Permisos** | `require_dircetur_admin` | Ubicado en `src/modules/users/dependencies.py` | Importar `from src.modules.users.dependencies import require_dircetur_admin`. |

---

## 3. Matriz de Asignación y Secuencia de Ejecución

### 👤 Francis (Desarrollador Backend) — Rama `feature/translation-module`
- **F-1**: Esquemas Pydantic v2 (`Language`, `PhraseCategory`, `TranslationRequest`, `TranslationResponse`) y catálogo inmutable del Frasebook oficial es↔en (32 frases en 8 categorías con hash SHA-256 para `ETag`).
- **F-2**: Normalizadores de texto (`normalize_for_lookup` y `normalize_for_cache`) y caché Redis con doble TTL (7 días clave principal, 30 días copia de respaldo).
- **F-3**: Proveedor Gemini (`GeminiTranslationProvider`) con prompt de sistema inmutable, `temperature=0.0` y timeout de 8s, junto a `MockTranslationProvider` para pruebas.
- **F-4**: Servicio `TranslationService` (flujo: Frasebook → Caché → Gemini → Respaldo → Error 503) y endpoints `/api/v1/translation/translate` y `/api/v1/translation/phrases`.
- **F-5**: Integración de métricas de incidencias turísticas (`analytics/repository.py` sección `# --- Incidentes ---`) para fiscalización DIRCETUR.
- **F-Tests**: 29 pruebas unitarias y de integración (`tests/modules/test_translation.py` y `test_analytics_incidents.py`).

### 👤 Paulo (Lead Developer / Arquitecto) — Rama `feature/analytics-dircetur`
- **P-1 (Día 1-2, Bloqueante)**: Modelo `UsageEvent` en `analytics/models.py` (anonimizado, sin IP, sin `user_id`, sin texto libre según Ley N° 29733), migración Alembic reversible y protocolo `UsageRecorder` en `src/shared/usage_events.py`.
- **P-2**: Middleware / Fábrica de Rate Limiting por IP (`src/core/rate_limit.py`) y nueva excepción `RateLimitExceededException` (429).
- **P-3**: Repositorio y Servicio de Analítica (`analytics/repository.py`, `service.py`):
  - Idiomas más demandados (`/admin/analytics/languages`).
  - Preferencias de turistas registradas vs categorías buscadas (`/admin/analytics/preferences`).
  - Ranking de atractivos por vistas, favoritos y reseñas sin producto cartesiano (`/admin/analytics/attractions/top`).
- **P-4**: Instrumentación desacoplada del catálogo mediante `BackgroundTasks` en `catalog/router.py`.
- **P-5**: Resumen ejecutivo consolidado (`/admin/analytics/summary`) con caché Redis de 300 segundos.
- **P-Tests**: 20 pruebas unitarias y de integración (`tests/modules/test_analytics.py` y `test_usage_events.py`).

---

## 4. Criterio de Integración Final
1. Paulo finaliza y fusiona `feature/analytics-dircetur` (entregando la base de `UsageRecorder`).
2. Francis rebasea sobre `develop` para conectar el registrador de eventos de traducción en `feature/translation-module`.
3. Francis abre Pull Request; revisión cruzada obligatoria entre ambos.
4. Ejecución del 100% de la suite: **125 tests aprobados** (`pytest`).
5. Merge final `--no-ff` a `develop`, etiquetado Git `v0.3.0-sprint3` y entrega de contratos OpenAPI al equipo Frontend.
