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

## 1. `AttractionListItem` no devuelve coordenadas (prioridad alta)

**Dónde:** `src/modules/catalog/schemas.py` → `class AttractionListItem`
**Endpoint:** `GET /api/v1/catalog/attractions`

Hoy devuelve solo `id, name, district, cover_image_url, categories`. Sin
`latitude`/`longitude`, el listado de la galería no puede dibujar los pines del
mapa ni habilitar el botón "Ver en el mapa".

**Qué hace el móvil mientras tanto:** pide las coordenadas a
`GET /api/v1/geo/nearby` y las une por `id`. Es una llamada extra y tiene el
límite del punto 2.

**Pedido concreto:**

```python
class AttractionListItem(BaseModel):
    id: UUID
    name: str
    district: str
    cover_image_url: str | None
    categories: list[str]
    latitude: float      # <- agregar
    longitude: float     # <- agregar
    description: str | None = None   # <- deseable (evita pedir el detalle)
```

Hay que reflejarlo también en `src/modules/catalog/service.py`
(`get_paginated_attractions`), que es donde se construye el ítem.

---

## 2. `/geo/nearby` no alcanza a cubrir toda la región de Ica

**Dónde:** `src/modules/geo/router.py` → `atractivos_cercanos`

Los topes actuales son `radius_m ≤ 100_000` (100 km) y `limit ≤ 50`. Desde el
centro de Ica, **Playa Hermosa de Marcona** (`-15.3583, -75.1750`) queda a más
de 100 km, así que no entra en la respuesta y ese lugar se queda sin
coordenadas.

**Opciones (en orden de preferencia):**

1. Resolver el punto 1 y dejar `/geo/nearby` solo para "cerca de mí" (su
   propósito real).
2. Subir el tope de `radius_m` a 300 000 m y `limit` a 100.

---

## 3. Las imágenes de los atractivos son de marcador de posición

**Dónde:** `src/modules/catalog/seed.py:188`

```python
AttractionImage(url=f"https://placehold.co/800x600?text={texto_img}+{n}", ...)
```

La tabla `attraction_image` se llena con URLs de `placehold.co`, que son
rectángulos grises con texto.

**Qué hace el móvil mientras tanto:** descarta cualquier URL que contenga
`placehold.co` y usa las fotos locales de `assets/images/`. Por eso la app se
ve bien, pero las fotos **no vienen de la BD**.

**Pedido concreto:** cargar URLs reales en `attraction_image.url` (CDN, bucket
o lo que se decida), con `display_order = 0` para la portada. En cuanto haya
URLs reales, el móvil las usará automáticamente sin cambiar código.

Corresponde a la **Corrección N°5** de la lista del equipo.

---

## 4. `attraction` no guarda la duración de la visita

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

## 5. `FavoriteItemResponse` no trae datos del atractivo

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

## 6. Tablas creadas que ninguna pantalla puede llenar todavía

Estas tablas existen en el modelo pero no tienen endpoints públicos que el
móvil pueda usar, o los tiene y no están poblados. Hay que decidir: **usarlas
o quitarlas** del modelo para no cargar deuda.

| Tabla | Estado | Qué falta |
|---|---|---|
| `review` / `review_images` | Endpoints existen; sin datos | Definir si la app móvil permite dejar reseñas. Hoy el móvil solo lee `avg_rating` del detalle (**Corrección N°9**) |
| `usage_events` | Se escribe desde `analytics` | Confirmar que los eventos de búsqueda y vista se están registrando con datos reales (**Corrección N°13**) |
| `weather_snapshot` / `weather_alert` | Tablas creadas | Confirmar que `refresh_weather_cache` corre y las puebla; el móvil consume `/weather/alerts` y recibe 400 en el túnel actual (**Corrección N°15**) |
| `tourist_incident_reports` | El móvil ya publica aquí | Verificar que los reportes enviados desde `incidencias_service` están llegando a la tabla (**Corrección N°12**) |

---

## 7. El panel DIRCETUR necesita un usuario con rol admin

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
