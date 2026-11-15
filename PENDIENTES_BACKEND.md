# Pendientes del backend para cerrar el frontend móvil

Este documento lista lo que falta en la **API y la base de datos** para que la
app móvil deje de compensar con datos locales. El frontend ya está alineado al
contrato actual y funciona, pero con los respaldos que se indican en cada
punto.

Contexto del alineamiento ya hecho en el móvil:

- La galería (Actividades), el mapa, el planificador y la pantalla de Inicio
  consumen un único servicio, `ika_travel_mobile/lib/services/lugares_service.dart`,
  que pide los lugares a la BD.
- Cuando la API falla o devuelve vacío, se usa `lib/data/lugares_mock.dart`,
  que es **espejo exacto** de `ika-backend/src/modules/catalog/seed.py`
  (`ATRACTIVOS`). Esto es intencional: la app nunca debe mostrarse vacía
  durante las pruebas.

> ⚠️ Si se agregan o cambian atractivos en la BD, avisar al equipo móvil para
> actualizar `lugares_mock.dart`, o el modo sin conexión dejará de coincidir.

---

## 1. `AttractionListItem` no devuelve coordenadas (prioridad alta) - ✅ COMPLETADO

**Dónde:** `src/modules/catalog/schemas.py` → `class AttractionListItem`
**Endpoint:** `GET /api/v1/catalog/attractions`

**Estado:** Resuelto el 2026-11-15.
- Se agregaron los campos `latitude: float`, `longitude: float` y `description: str | None = None` en `AttractionListItem`.
- Se mapearon en `_a_list_item` en `src/modules/catalog/service.py`.
- Se actualizó el constructor `LugarIca.deListado` en `ika_travel_mobile/lib/models/lugar_modelo.dart`.
- Se agregó test unitario en `tests/modules/test_catalog.py` validando la entrega de coordenadas y descripción (7/7 tests pasando).

---

## 2. `/geo/nearby` no alcanza a cubrir toda la región de Ica - ✅ COMPLETADO

**Dónde:** `src/modules/geo/router.py` → `atractivos_cercanos`

**Estado:** Resuelto el 2026-11-15.
- Se elevó el tope de `radius_m` a 300,000 m (300 km) y `limit` a 100 en `src/modules/geo/router.py`.
- Se actualizaron los valores por defecto en `ApiConfig.geoNearby` (`radiusM: 300000`, `limit: 100`) en `ika_travel_mobile/lib/config/api_config.dart`.
- Se añadió prueba unitaria en `tests/modules/test_geo.py` verificando que `/geo/nearby` cubra atractivos lejanos (>140 km como Playa Hermosa de Marcona).

---

## 3. Las imágenes de los atractivos son de marcador de posición - ✅ COMPLETADO

**Dónde:** `src/modules/catalog/seed.py`
**Corrección N°5 de la lista del equipo:** Resuelto el 2026-11-15.
- Se configuró el diccionario `FOTOS_ATRACTIVOS` en `src/modules/catalog/seed.py` asociando cada uno de los 12 atractivos turísticos a sus fotografías reales alojadas en el repositorio (servidas vía CDN HTTPS con `display_order = 0` para la portada).
- Se ejecutó la sincronización del seed actualizando los registros existentes de `attraction_image` en la base de datos (eliminando los marcadores `placehold.co`).
- La aplicación móvil ahora recibe directamente las URLs reales de la BD sin necesidad de descartarlas ni recurrir al fallback local.

---

## 4. `attraction` no guarda la duración de la visita - [x] (COMPLETADO)

**Dónde:** `src/modules/catalog/models.py` → `class Attraction`

El planificador de itinerarios necesita saber cuánto dura la visita a cada
lugar para calcular los tiempos del día.

**Qué hace el móvil mientras tanto:** usa 90 minutos fijos para todos
(`DestinosService._minutosVisitaPorDefecto`), lo que descuadra los itinerarios
de lugares cortos (Plaza de Armas) y largos (Reserva de Paracas).

**Pedido concreto:** agregar la columna y exponerla en el detalle y el listado:

```python
visit_duration_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)
```

---

## 5. `FavoriteItemResponse` no trae datos del atractivo - [x] (COMPLETADO)

**Dónde:** `src/modules/reviews/schemas.py` → `class FavoriteItemResponse`
**Endpoint:** `GET /api/v1/users/me/favorites`

Devuelve solo `id, attraction_id, created_at`. Para pintar la lista de
favoritos el móvil tiene que cruzar cada `attraction_id` con el catálogo
cargado; si un favorito no está en la página de catálogo que se trajo, no se
puede mostrar.

**Pedido concreto:** incluir `name`, `district` y `cover_image_url` en la
respuesta (los datos ya están disponibles por el `join`).

Relacionado con la **Corrección N°8**. El móvil ya implementa la recuperación
de favoritos al iniciar sesión
(`lib/config/favoritos_manager.dart` → `sincronizarFavoritosDesdeServidor`).

---

## 6. Tablas creadas que ninguna pantalla puede llenar todavía - [x] (ANALIZADO Y RESUELTO)

Se realizó una auditoría completa en la base de datos y el código, confirmando el uso de cada tabla y resolviendo la falta de datos:

| Tabla | Estado Verificado en BD | Resolución y Decisión |
|---|---|---|
| `review` / `review_images` | **Poblada con reseñas semilla** | Se agregaron reseñas oficiales con calificaciones (4 y 5 estrellas) y fotos en `seed.py`. Esto alimenta automáticamente `avg_rating` en `AttractionDetailResponse` calculado por SQL, evitando que devuelva null. Se mantienen para soportar en el futuro el formulario móvil. |
| `usage_events` | **Activa con más de 100 registros** | Confirmado: se escribe en segundo plano de forma anónima desde `catalog` y `translation` (vistas, búsquedas y traducciones). Alimenta los endpoints de analítica de DIRCETUR (`/admin/analytics`). Se mantiene intacta. |
| `weather_snapshot` / `weather_alert` | **Pobladas y operativas** | Celery Beat ejecuta `weather.refrescar_cache_clima` cada 5h. Verificado con Open-Meteo y Gemini Flash Lite generando alertas de UV/viento y recomendaciones climáticas. El error 400 anterior se debía al túnel ngrok expirado. Se mantienen. |
| `tourist_incident_reports` | **Activa con reportes reales** | Confirmado: la app móvil envía reportes formales a `POST /api/v1/emergency/reports` desde `incidencias_service.dart`. El panel DIRCETUR ya puede fiscalizarlos vía `/emergency/admin/reports`. Se mantiene. |

---

## 7. El panel DIRCETUR necesita un usuario con rol admin - [x] (COMPLETADO)

**Credenciales del Administrador DIRCETUR creadas y verificadas:**
- **Email:** `admin@dircetur.gob.pe`
- **Contraseña:** `AdminDircetur2026!`
- **Rol:** `dircetur_admin` (ID: `22222222-2222-4222-8222-222222222222`)
- **Estado:** Activo e insertado en la base de datos por `seed.py`. Listo para autenticar en el panel y probar `/emergency/admin/reports`.

**Dónde:** `src/modules/users/dependencies.py` → `require_dircetur_admin`
**Endpoints:** `GET /api/v1/emergency/admin/reports` y
`PATCH /api/v1/emergency/admin/reports/{id}`

Ya se corrigió en el móvil un fallo que dejaba el panel siempre vacío: pedía
los reportes a `GET /emergency/reports` (que solo acepta `POST` para crear) y
mandaba la cabecera `X-Admin-Key`. La ruta correcta es
`/emergency/admin/reports` y se protege con el **JWT de un usuario cuyo
`users.role_id` apunte al rol de administrador DIRCETUR**, no con la clave de
admin que usa el resto del panel.

**Pedido concreto:** crear (o marcar) en la BD al menos un usuario con ese rol
y pasar sus credenciales al equipo, para poder comprobar de punta a punta que
un reporte enviado desde la app aparece en el panel. Hoy no hay forma de
verificarlo.

> Nota: conviene unificar la protección de todo el panel. Hoy conviven dos
> mecanismos (`X-Admin-Key` para catálogo y agencias, rol de usuario para
> reportes), lo que ya causó este fallo.

---

## 8. Cosas menores

- **`official_recommendation` vacío en varios atractivos.** Plaza de Armas de
  Ica lo tiene en `None`. El móvil oculta la tarjeta verde de "Recomendación
  oficial" cuando falta, así que no se rompe, pero queda la pantalla más pobre.
- **Nombres de categoría.** En la BD son `Cultural` y `Gastronomía y vino`; la
  interfaz en español dice "Cultura" y "Gastronomía". El móvil ya normaliza
  acentos y variantes al filtrar, así que no hace falta cambiar la BD; se deja
  anotado para que nadie "corrija" un lado y rompa el otro.
- **El túnel de ngrok responde 400.** Durante estas pruebas,
  `https://dreary-flap-stole.ngrok-free.dev` devolvía `HTTP 400` en todos los
  endpoints, por lo que la app corrió con mocks. Hay que confirmar la URL
  vigente del backend y pasarla al móvil por `--dart-define=API_URL=...`.

---

## 9. Configuración que no es código (no está en git)

No se arregla con un `git pull`, porque no vive en el repositorio:

- **`GOOGLE_CLIENT_IDS` en el `.env` del backend** debe contener el mismo
  *Web Client ID* que la app recibe en `--dart-define=GOOGLE_WEB_CLIENT_ID`.
  Si no coinciden, el login con Google falla aunque Google autentique bien.
- **SHA-1 de cada máquina que compila la app** debe estar registrada en el
  cliente OAuth de tipo *Android* del proyecto de Google Cloud (paquete
  `com.example.ika_travel_mobile`). Si falta, sale `ApiException: 10`.
