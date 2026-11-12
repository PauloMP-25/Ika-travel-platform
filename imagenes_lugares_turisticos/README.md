# Imágenes de lugares turísticos — Ika Travel & Experience

Carpeta de recopilación de las imágenes locales de lugares turísticos utilizadas actualmente por el aplicativo. **Las imágenes originales no fueron movidas, renombradas ni modificadas**; todas las copias se hicieron con operaciones de copia.

## 1. Resumen del análisis

- **Frontend:** aplicación móvil Flutter (`ika_travel_mobile/`). Los recursos se declaran en `ika_travel_mobile/pubspec.yaml` (sección `flutter.assets`, carpeta `assets/images/`).
- **Backend:** API en Python/FastAPI (`ika-backend/`). El catálogo referencia rutas de los assets del frontend en `src/modules/catalog/seed_playas.py` y URLs externas de marcador de posición en `src/modules/catalog/seed.py`.
- **Carpeta de origen de las imágenes locales:** `ika_travel_mobile/assets/images/`.
- **Imágenes locales encontradas:** 18 archivos JPG. Por contenido, 17 son únicos: `carrusel_3_sandboarding.jpg` y `detalle_sandboarding_3.jpg` son byte a byte idénticas, pero se conservaron ambas copias con su nombre original porque el código las referencia por separado.
- **Otras imágenes del repositorio excluidas:** iconos de lanzador de Android (`mipmap-*`), iconos de iOS y web (`AppIcon`, `LaunchImage`, `web/icons`, `favicon.png`). No son imágenes de lugares turísticos.
- **Recursos externos no descargados:** URLs de `placehold.co` usadas por el seed del backend y capas base de OpenStreetMap. Se registran más abajo, pero no se copiaron ni sustituyeron.

## 2. Estructura de la carpeta

```text
imagenes_lugares_turisticos/
├── README.md
├── act_ballestas1.jpg
├── act_buggy1.jpg
├── act_reserva1.jpg
├── act_vinos.jpg
├── carrusel_1_huacachina.jpg
├── carrusel_2_vinos.jpg
├── carrusel_3_sandboarding.jpg
├── detalle_ballestas_2.jpg
├── detalle_ballestas_3.jpg
├── detalle_buggy_2.jpg
├── detalle_buggy_3.jpg
├── detalle_reserva_2.jpg
├── detalle_reserva_3.jpg
├── detalle_sandboarding_1.jpg
├── detalle_sandboarding_2.jpg
├── detalle_sandboarding_3.jpg
├── detalle_vinos_2.jpg
└── detalle_vinos_3.jpg
```

## 3. Inventario de imágenes y lugares turísticos

| # | Lugar turístico representado | Archivo recopilado | Ubicación original | Ubicación de la copia | Dónde se utiliza |
|---|---|---|---|---|---|
| 1 | Oasis / Laguna de Huacachina | `carrusel_1_huacachina.jpg` | `ika_travel_mobile/assets/images/carrusel_1_huacachina.jpg` | `imagenes_lugares_turisticos/carrusel_1_huacachina.jpg` | Pantalla de Inicio (carrusel), Pantalla de Actividades, Pantalla de Mapa, Pantalla de Seguimiento de Destino, catálogo local de `ApiService`, fallback de `AttractionsService`, modelo `AttractionListItemModel`, fallback de Pantalla de Detalle por Día |
| 2 | Sandboarding en Huacachina / Huacachina Sandboarding & Buggy | `detalle_sandboarding_1.jpg` | `ika_travel_mobile/assets/images/detalle_sandboarding_1.jpg` | `imagenes_lugares_turisticos/detalle_sandboarding_1.jpg` | Pantalla de Mapa, detalle de actividades, alternativas recomendadas, fallback de `AttractionListItemModel`, catálogo local de `ApiService` |
| 3 | Sandboarding en Huacachina | `detalle_sandboarding_2.jpg` | `ika_travel_mobile/assets/images/detalle_sandboarding_2.jpg` | `imagenes_lugares_turisticos/detalle_sandboarding_2.jpg` | Pantalla de Mapa y galería de detalle del catálogo local |
| 4 | Sandboarding en Huacachina | `detalle_sandboarding_3.jpg` | `ika_travel_mobile/assets/images/detalle_sandboarding_3.jpg` | `imagenes_lugares_turisticos/detalle_sandboarding_3.jpg` | Pantalla de Mapa (galería de Sandboarding en Huacachina). Archivo idéntico a `carrusel_3_sandboarding.jpg` |
| 5 | Sandboarding en Huacachina / Plaza de Armas de Ica (mapeo local) | `carrusel_3_sandboarding.jpg` | `ika_travel_mobile/assets/images/carrusel_3_sandboarding.jpg` | `imagenes_lugares_turisticos/carrusel_3_sandboarding.jpg` | Carrusel de la Pantalla de Inicio y mapeo local del nombre «Plaza de Armas de Ica» en `ApiService` |
| 6 | Islas Ballestas | `act_ballestas1.jpg` | `ika_travel_mobile/assets/images/act_ballestas1.jpg` | `imagenes_lugares_turisticos/act_ballestas1.jpg` | Pantalla de Mapa, catálogo local de `ApiService`, seguimiento de Paracas, alternativas recomendadas, seed de playas del backend (Playa El Chaco e Islas Ballestas) |
| 7 | Islas Ballestas | `detalle_ballestas_2.jpg` | `ika_travel_mobile/assets/images/detalle_ballestas_2.jpg` | `imagenes_lugares_turisticos/detalle_ballestas_2.jpg` | Pantalla de Mapa y galería de detalle del catálogo local |
| 8 | Islas Ballestas | `detalle_ballestas_3.jpg` | `ika_travel_mobile/assets/images/detalle_ballestas_3.jpg` | `imagenes_lugares_turisticos/detalle_ballestas_3.jpg` | Pantalla de Mapa y galería de detalle del catálogo local |
| 9 | Reserva Nacional de Paracas | `act_reserva1.jpg` | `ika_travel_mobile/assets/images/act_reserva1.jpg` | `imagenes_lugares_turisticos/act_reserva1.jpg` | Pantalla de Mapa, catálogo local de `ApiService`, alternativas recomendadas, seed de playas del backend (Playa La Mina, Playa Roja, Playa Hermosa de Marcona y Reserva Nacional de Paracas) |
| 10 | Reserva Nacional de Paracas | `detalle_reserva_2.jpg` | `ika_travel_mobile/assets/images/detalle_reserva_2.jpg` | `imagenes_lugares_turisticos/detalle_reserva_2.jpg` | Pantalla de Mapa y galería de detalle del catálogo local |
| 11 | Reserva Nacional de Paracas | `detalle_reserva_3.jpg` | `ika_travel_mobile/assets/images/detalle_reserva_3.jpg` | `imagenes_lugares_turisticos/detalle_reserva_3.jpg` | Pantalla de Mapa y galería de detalle del catálogo local |
| 12 | Viñedos y bodegas / Bodega Tacama / Bodegas de Subtanjalla | `act_vinos.jpg` | `ika_travel_mobile/assets/images/act_vinos.jpg` | `imagenes_lugares_turisticos/act_vinos.jpg` | Pantalla de Mapa, catálogo local de `ApiService`, alternativas recomendadas, seguimiento de Ica, fallback de `AlternativaRecomendada`, seed de playas del backend (Viña Tacama) |
| 13 | Viñedos y bodegas / Bodega Tacama | `detalle_vinos_2.jpg` | `ika_travel_mobile/assets/images/detalle_vinos_2.jpg` | `imagenes_lugares_turisticos/detalle_vinos_2.jpg` | Pantalla de Mapa y galería de detalle del catálogo local |
| 14 | Viñedos y bodegas / Bodega Tacama | `detalle_vinos_3.jpg` | `ika_travel_mobile/assets/images/detalle_vinos_3.jpg` | `imagenes_lugares_turisticos/detalle_vinos_3.jpg` | Pantalla de Mapa y galería de detalle del catálogo local |
| 15 | Ica (Campiña y Bodegas), Plaza de Armas de Ica, Pueblo de Cachiche, Santuario del Señor de Luren | `carrusel_2_vinos.jpg` | `ika_travel_mobile/assets/images/carrusel_2_vinos.jpg` | `imagenes_lugares_turisticos/carrusel_2_vinos.jpg` | Carrusel de la Pantalla de Inicio, Pantalla de Mapa, seguimiento de Ica, mapeos locales de «Pueblo de Cachiche», «Plaza de Armas de Ica» y «Santuario del Señor de Luren» |
| 16 | Cañón de los Perdidos / Santuario del Señor de Luren (mapeo local) | `act_buggy1.jpg` | `ika_travel_mobile/assets/images/act_buggy1.jpg` | `imagenes_lugares_turisticos/act_buggy1.jpg` | Pantalla de Mapa, catálogo local de `ApiService`, seguimiento del Santuario del Señor de Luren |
| 17 | Pueblo de Cachiche / Cachiche (Pueblo de las Brujas) | `detalle_buggy_2.jpg` | `ika_travel_mobile/assets/images/detalle_buggy_2.jpg` | `imagenes_lugares_turisticos/detalle_buggy_2.jpg` | Pantalla de Mapa, catálogo local de `ApiService`, mapeo local de «Pueblo de Cachiche» |
| 18 | Cañón de los Perdidos | `detalle_buggy_3.jpg` | `ika_travel_mobile/assets/images/detalle_buggy_3.jpg` | `imagenes_lugares_turisticos/detalle_buggy_3.jpg` | Pantalla de Mapa y galería de detalle del catálogo local |

## 4. Detalle de referencias por archivo

Las rutas de línea corresponden al estado del repositorio al momento de la recopilación.

### `carrusel_1_huacachina.jpg`
- `ika_travel_mobile/lib/services/api_service.dart`: líneas 33, 54, 105 y 107.
- `ika_travel_mobile/lib/services/attractions_service.dart`: líneas 48 y 90.
- `ika_travel_mobile/lib/screens/pantalla_inicio.dart`: líneas 30 y 609.
- `ika_travel_mobile/lib/screens/pantalla_mapa.dart`: líneas 54 y 56.
- `ika_travel_mobile/lib/screens/pantalla_actividades.dart`: línea 289 (imagen de respaldo).
- `ika_travel_mobile/lib/screens/pantalla_detalle_dia.dart`: líneas 109 y 118 (imagen de respaldo).
- `ika_travel_mobile/lib/services/seguimiento_service.dart`: líneas 23 y 277.
- `ika_travel_mobile/lib/models/seguimiento_modelo.dart`: línea 183 (valor por defecto).

### `detalle_sandboarding_1.jpg`
- `ika_travel_mobile/lib/services/api_service.dart`: líneas 35 y 108.
- `ika_travel_mobile/lib/models/attraction_model.dart`: líneas 34 y 36 (valor por defecto).
- `ika_travel_mobile/lib/screens/pantalla_mapa.dart`: líneas 39, 41 y 57.
- `ika_travel_mobile/lib/services/recomendador_service.dart`: líneas 50 y 301.

### `detalle_sandboarding_2.jpg`
- `ika_travel_mobile/lib/services/api_service.dart`: línea 109.
- `ika_travel_mobile/lib/screens/pantalla_mapa.dart`: línea 42.

### `detalle_sandboarding_3.jpg`
- `ika_travel_mobile/lib/screens/pantalla_mapa.dart`: línea 43.
- Contenido idéntico a `carrusel_3_sandboarding.jpg` (mismo SHA-256, mismas dimensiones y tamaño).

### `carrusel_3_sandboarding.jpg`
- `ika_travel_mobile/lib/screens/pantalla_inicio.dart`: línea 32 (carrusel principal).
- `ika_travel_mobile/lib/services/api_service.dart`: línea 39 (mapeo local del nombre «Plaza de Armas de Ica»).
- Contenido idéntico a `detalle_sandboarding_3.jpg`.

### `act_ballestas1.jpg`
- `ika_travel_mobile/lib/services/api_service.dart`: líneas 42, 44, 119 y 121.
- `ika_travel_mobile/lib/screens/pantalla_mapa.dart`: líneas 68 y 70.
- `ika_travel_mobile/lib/services/recomendador_service.dart`: línea 153.
- `ika_travel_mobile/lib/services/seguimiento_service.dart`: línea 93.
- `ika-backend/src/modules/catalog/seed_playas.py`: líneas 30 y 46.

### `detalle_ballestas_2.jpg`
- `ika_travel_mobile/lib/services/api_service.dart`: línea 122.
- `ika_travel_mobile/lib/screens/pantalla_mapa.dart`: línea 71.

### `detalle_ballestas_3.jpg`
- `ika_travel_mobile/lib/services/api_service.dart`: línea 123.
- `ika_travel_mobile/lib/screens/pantalla_mapa.dart`: línea 72.

### `act_reserva1.jpg`
- `ika_travel_mobile/lib/services/api_service.dart`: líneas 40, 41, 43, 45, 133 y 135.
- `ika_travel_mobile/lib/screens/pantalla_mapa.dart`: líneas 83 y 85.
- `ika_travel_mobile/lib/services/recomendador_service.dart`: líneas 75, 103, 204 y 281.
- `ika-backend/src/modules/catalog/seed_playas.py`: líneas 14, 22, 38 y 54.

### `detalle_reserva_2.jpg`
- `ika_travel_mobile/lib/services/api_service.dart`: línea 136.
- `ika_travel_mobile/lib/screens/pantalla_mapa.dart`: línea 86.

### `detalle_reserva_3.jpg`
- `ika_travel_mobile/lib/services/api_service.dart`: línea 137.
- `ika_travel_mobile/lib/screens/pantalla_mapa.dart`: línea 87.

### `act_vinos.jpg`
- `ika_travel_mobile/lib/services/api_service.dart`: líneas 37, 46, 147 y 149.
- `ika_travel_mobile/lib/screens/pantalla_mapa.dart`: líneas 98 y 100.
- `ika_travel_mobile/lib/services/recomendador_service.dart`: líneas 25, 128, 180, 231 y 261.
- `ika_travel_mobile/lib/models/alternativa_modelo.dart`: línea 83 (valor por defecto).
- `ika-backend/src/modules/catalog/seed_playas.py`: línea 62.

### `detalle_vinos_2.jpg`
- `ika_travel_mobile/lib/services/api_service.dart`: línea 150.
- `ika_travel_mobile/lib/screens/pantalla_mapa.dart`: línea 101.

### `detalle_vinos_3.jpg`
- `ika_travel_mobile/lib/services/api_service.dart`: línea 151.
- `ika_travel_mobile/lib/screens/pantalla_mapa.dart`: línea 102.

### `carrusel_2_vinos.jpg`
- `ika_travel_mobile/lib/services/api_service.dart`: líneas 38, 47, 175 y 176.
- `ika_travel_mobile/lib/screens/pantalla_inicio.dart`: línea 31.
- `ika_travel_mobile/lib/screens/pantalla_mapa.dart`: líneas 113 y 114.
- `ika_travel_mobile/lib/services/seguimiento_service.dart`: línea 155.
- `ika_travel_mobile/test/alertas_inteligentes_test.dart`: línea 386 (solo prueba automatizada).

### `act_buggy1.jpg`
- `ika_travel_mobile/lib/services/api_service.dart`: líneas 36, 161 y 163.
- `ika_travel_mobile/lib/screens/pantalla_mapa.dart`: líneas 124, 125, 146 y 148.
- `ika_travel_mobile/lib/services/seguimiento_service.dart`: línea 207.

### `detalle_buggy_2.jpg`
- `ika_travel_mobile/lib/services/api_service.dart`: líneas 185 y 186.
- `ika_travel_mobile/lib/screens/pantalla_mapa.dart`: líneas 135 y 136.

### `detalle_buggy_3.jpg`
- `ika_travel_mobile/lib/services/api_service.dart`: línea 165.
- `ika_travel_mobile/lib/screens/pantalla_mapa.dart`: línea 149.

## 5. Pantallas y secciones que consumen las imágenes

| Pantalla / sección | Archivo(s) | Función |
|---|---|---|
| Pantalla de Inicio | `pantalla_inicio.dart` | Carrusel de imágenes de Huacachina, viñedos y sandboarding; imagen de cabecera del detalle diario |
| Pantalla de Actividades | `pantalla_actividades.dart` | Miniatura de cada actividad y navegación al detalle |
| Pantalla de Detalle | `pantalla_detalle.dart` | Galería de imágenes del lugar turístico |
| Pantalla de Mapa | `pantalla_mapa.dart` | Imagen de tarjeta y galería de cada destino del mapa |
| Pantalla de Detalle de Alternativa | `pantalla_detalle_alternativa.dart` | Imagen de la alternativa recomendada |
| Pantalla de Favoritos | `pantalla_favoritos.dart` | Miniatura de la actividad favorita |
| Pantalla de Detalle por Día | `pantalla_detalle_dia.dart` | Imagen de cabecera del día |
| Pantalla de Seguimiento de Destino | `pantalla_seguimiento_destino.dart` | Imagen del destino monitoreado |
| Catálogo local de actividades | `api_service.dart` | Asigna una imagen local a cada atractivo del catálogo de respaldo y a los nombres recibidos del backend |
| Catálogo de atractivos | `attractions_service.dart` y `attraction_model.dart` | Imagen de portada y valores por defecto |
| Alternativas inteligentes | `recomendador_service.dart` y `alternativa_modelo.dart` | Imágenes de las alternativas recomendadas |
| Seguimiento de destinos | `seguimiento_service.dart` y `seguimiento_modelo.dart` | Imágenes de los destinos monitoreados |
| Backend: seed de playas y destinos | `ika-backend/src/modules/catalog/seed_playas.py` | Rutas de assets locales asociadas a las playas y Viña Tacama |

## 6. Imágenes utilizadas mediante URLs externas

No se descargaron ni sustituyeron. Se registran para conocimiento del equipo.

| Lugar turístico | URL(s) externa(s) | Contexto |
|---|---|---|
| Oasis de Huacachina | `https://placehold.co/800x600?text=Oasis+de+Huacachina+0`<br>`https://placehold.co/800x600?text=Oasis+de+Huacachina+1`<br>`https://placehold.co/800x600?text=Oasis+de+Huacachina+2` | `ika-backend/src/modules/catalog/seed.py` (línea 105): imágenes de marcador de posición generadas para el atractivo |
| Palmera de las 7 Cabezas (Cachiche) | `https://placehold.co/800x600?text=Palmera+de+las+7+Cabezas+(Cachiche)+0`<br>`https://placehold.co/800x600?text=Palmera+de+las+7+Cabezas+(Cachiche)+1`<br>`https://placehold.co/800x600?text=Palmera+de+las+7+Cabezas+(Cachiche)+2` | `ika-backend/src/modules/catalog/seed.py` (línea 105): imágenes de marcador de posición generadas para el atractivo |
| Plaza de Armas de Ica | `https://placehold.co/800x600?text=Plaza+de+Armas+de+Ica+0`<br>`https://placehold.co/800x600?text=Plaza+de+Armas+de+Ica+1`<br>`https://placehold.co/800x600?text=Plaza+de+Armas+de+Ica+2` | `ika-backend/src/modules/catalog/seed.py` (línea 105): imágenes de marcador de posición generadas para el atractivo |
| Bodega y Viñedos Sotelo (Subtanjalla) | `https://placehold.co/800x600?text=Bodega+y+Viñedos+Sotelo+(Subtanjalla)+0`<br>`https://placehold.co/800x600?text=Bodega+y+Viñedos+Sotelo+(Subtanjalla)+1`<br>`https://placehold.co/800x600?text=Bodega+y+Viñedos+Sotelo+(Subtanjalla)+2` | `ika-backend/src/modules/catalog/seed.py` (línea 105): imágenes de marcador de posición generadas para el atractivo |
| Cañón de los Perdidos | `https://placehold.co/800x600?text=Cañón+de+los+Perdidos+0`<br>`https://placehold.co/800x600?text=Cañón+de+los+Perdidos+1`<br>`https://placehold.co/800x600?text=Cañón+de+los+Perdidos+2` | `ika-backend/src/modules/catalog/seed.py` (línea 105): imágenes de marcador de posición generadas para el atractivo |

Notas:

- El frontend también lee `cover_image_url` devuelto por el backend (`api_service.dart`, línea 77) y lo agrega a `imagenes_detalle` cuando existe, por lo que una URL externa podría provenir dinámicamente de la base de datos. Con los datos semilla actuales, las URLs externas conocidas son las de `placehold.co` indicadas arriba.
- Las capas base de OpenStreetMap (`https://tile.openstreetmap.org/{z}/{x}/{y}.png`) usadas en el mapa y la navegación no son imágenes de lugares turísticos y fueron excluidas.

## 7. Imágenes referenciadas pero no encontradas

Estas rutas se referencian en el código, pero los archivos no existen en `ika_travel_mobile/assets/images/`. No se inventaron, descargaron ni sustituyeron.

| Archivo referenciado pero ausente | Lugar turístico asociado | Referencia |
|---|---|---|
| `assets/images/carrusel_2_paracas.jpg` | Islas Ballestas | `ika_travel_mobile/lib/services/attractions_service.dart`, línea 55 (portada del catálogo de respaldo) |
| `assets/images/carrusel_3_lineas.jpg` | Líneas de Nazca | `ika_travel_mobile/lib/services/attractions_service.dart`, línea 62 (portada del catálogo de respaldo) |
| `assets/images/carrusel_4_vinas.jpg` | Ruta del Pisco y Viñedos | `ika_travel_mobile/lib/services/attractions_service.dart`, línea 69 (portada del catálogo de respaldo) |

## 8. Observaciones sobre imágenes duplicadas y reutilizadas

- `carrusel_3_sandboarding.jpg` y `detalle_sandboarding_3.jpg` son idénticas (SHA-256 `3FA54A669E4C3F6B89FBD5A24B30C406238E80AB294E840497BB33FCB42D14D6`; 549 × 364 px; 21 509 bytes). Se conservaron las dos copias con sus nombres originales porque el código las referencia por separado.
- Varias imágenes se reutilizan para representar más de un lugar. Por ejemplo:
  - `carrusel_2_vinos.jpg` se usa para viñedos, Pueblo de Cachiche, Plaza de Armas de Ica y Santuario del Señor de Luren.
  - `act_buggy1.jpg` se usa para el Cañón de los Perdidos y también para el Santuario del Señor de Luren.
  - `act_reserva1.jpg` se usa para la Reserva Nacional de Paracas y las playas La Mina, Roja y Hermosa de Marcona.
  - `act_ballestas1.jpg` se usa para las Islas Ballestas y la Playa El Chaco.
- El detalle completo de esas referencias figura en la sección 4.

## 9. Verificación de la recopilación

- Se copiaron los 18 archivos locales de `ika_travel_mobile/assets/images/` a `imagenes_lugares_turisticos/`.
- Se comprobó que cada copia conserva el mismo tamaño y hash SHA-256 que su original.
- Los archivos originales permanecen intactos en `ika_travel_mobile/assets/images/`.
- No se modificaron componentes, rutas, configuraciones, dependencias ni archivos del backend.
- El único cambio introducido en el repositorio es esta carpeta nueva y su contenido.
