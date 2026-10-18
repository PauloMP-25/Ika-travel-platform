# Optimización de PostgreSQL — Sprint 4 (F2)

**Generado por** `scripts/explicar_optimizacion.py` el
2026-10-18 18:25 con `EXPLAIN (ANALYZE, BUFFERS)` real.

Cada índice se aplicó con la migración `f1a2b3c4d5e6` (`rev_1_indices_sprint4`).

**Elección sobre `CREATE INDEX CONCURRENTLY`:** para el volumen del MVP se
usan índices normales (DDL transaccional, más simple en Alembic). El coste
es una breve exclusión de escrituras sobre la tabla durante la creación. Si
la tabla crece en producción, la siguiente migración puede recrearlos con
`CONCURRENTLY` dentro de `op.get_context().autocommit_block()`.


## Volumen de datos de la prueba

Se usa una BD aislada (`ika_travel_explain`) con datos sintéticos, para no
depender del estado de la BD de desarrollo:

| Tabla | Filas |
|---|---|
| users | 600 |
| category | 12 |
| attraction | 30 000 |
| attraction_category | ~90 000 |
| reviews | 150 000 |
| agency | 400 (20 % validadas) |
| tour | 1 200 |
| sos_reports | 20 000 |
| tourist_incident_reports | 10 000 |
| usage_events | 300 000 |

Reproducir: `python scripts/explicar_optimizacion.py` (desde `ika-backend/`).

## Planes ANTES de los índices del sprint

### Catálogo: conteo de atractivos por categoría (filtro público)

```
Aggregate  (cost=1876.01..1876.02 rows=1 width=8) (actual time=7.736..7.738 rows=1 loops=1)
  Buffers: shared hit=1245
  ->  Hash Join  (cost=828.87..1859.63 rows=6552 width=0) (actual time=2.046..7.512 rows=6531 loops=1)
        Hash Cond: (a.id = ac.attraction_id)
        Buffers: shared hit=1245
        ->  Seq Scan on attraction a  (cost=0.00..952.00 rows=30000 width=16) (actual time=0.011..2.926 rows=30000 loops=1)
              Filter: is_active
              Buffers: shared hit=652
        ->  Hash  (cost=746.97..746.97 rows=6552 width=16) (actual time=2.020..2.021 rows=6531 loops=1)
              Buckets: 8192  Batches: 1  Memory Usage: 371kB
              Buffers: shared hit=593
              ->  Bitmap Heap Scan on attraction_category ac  (cost=79.07..746.97 rows=6552 width=16) (actual time=0.207..1.467 rows=6531 loops=1)
                    Recheck Cond: (category_id = 'aefb106b-d9db-4dd3-99a0-b5af5e565efd'::uuid)
                    Heap Blocks: exact=586
                    Buffers: shared hit=593
                    ->  Bitmap Index Scan on ix_attraction_category_category_id  (cost=0.00..77.43 rows=6552 width=0) (actual time=0.158..0.158 rows=6531 loops=1)
                          Index Cond: (category_id = 'aefb106b-d9db-4dd3-99a0-b5af5e565efd'::uuid)
                          Buffers: shared hit=7
Planning:
  Buffers: shared hit=14
Planning Time: 0.291 ms
Execution Time: 7.830 ms
```

### Catálogo: primera página por categoría, ordenada por nombre

```
Limit  (cost=3.33..56.57 rows=20 width=32) (actual time=0.149..0.151 rows=20 loops=1)
  Buffers: shared hit=275
  ->  Incremental Sort  (cost=3.33..17445.03 rows=6552 width=32) (actual time=0.149..0.150 rows=20 loops=1)
        Sort Key: a.name, a.id
        Presorted Key: a.name
        Full-sort Groups: 1  Sort Method: quicksort  Average Memory: 26kB  Peak Memory: 26kB
        Buffers: shared hit=275
        ->  Nested Loop  (cost=0.70..17150.19 rows=6552 width=32) (actual time=0.021..0.135 rows=21 loops=1)
              Buffers: shared hit=275
              ->  Index Scan using ix_attraction_name on attraction a  (cost=0.29..1573.29 rows=30000 width=32) (actual time=0.005..0.020 rows=90 loops=1)
                    Filter: is_active
                    Buffers: shared hit=4
              ->  Index Only Scan using attraction_category_pkey on attraction_category ac  (cost=0.42..0.52 rows=1 width=16) (actual time=0.001..0.001 rows=0 loops=90)
                    Index Cond: ((attraction_id = a.id) AND (category_id = 'aefb106b-d9db-4dd3-99a0-b5af5e565efd'::uuid))
                    Heap Fetches: 0
                    Buffers: shared hit=271
Planning:
  Buffers: shared hit=14
Planning Time: 0.149 ms
Execution Time: 0.166 ms
```

### Detalle: promedio de calificaciones de un atractivo

```
Aggregate  (cost=1219.58..1219.59 rows=1 width=32) (actual time=0.108..0.108 rows=1 loops=1)
  Buffers: shared hit=9
  ->  Bitmap Heap Scan on reviews  (cost=8.93..1218.08 rows=598 width=4) (actual time=0.030..0.069 rows=600 loops=1)
        Recheck Cond: (attraction_id = '39eec50a-2a9a-4086-a3d1-eb1a23b601da'::uuid)
        Heap Blocks: exact=7
        Buffers: shared hit=9
        ->  Bitmap Index Scan on ix_reviews_attraction_id  (cost=0.00..8.78 rows=598 width=0) (actual time=0.022..0.022 rows=600 loops=1)
              Index Cond: (attraction_id = '39eec50a-2a9a-4086-a3d1-eb1a23b601da'::uuid)
              Buffers: shared hit=2
Planning Time: 0.064 ms
Execution Time: 0.122 ms
```

### Catálogo: listado por distrito entre atractivos activos

```
Limit  (cost=0.29..574.62 rows=50 width=32) (actual time=0.010..0.106 rows=50 loops=1)
  Buffers: shared hit=10
  ->  Index Scan using ix_attraction_name on attraction  (cost=0.29..1723.29 rows=150 width=32) (actual time=0.009..0.103 rows=50 loops=1)
        Filter: (is_active AND (lower((district)::text) = 'ica'::text))
        Rows Removed by Filter: 271
        Buffers: shared hit=10
Planning Time: 0.048 ms
Execution Time: 0.116 ms
```

### Geo: prefiltro por bounding box antes del Haversine

```
Bitmap Heap Scan on attraction  (cost=216.63..953.91 rows=4264 width=48) (actual time=0.389..1.093 rows=4195 loops=1)
  Recheck Cond: ((latitude >= '-14.2'::double precision) AND (latitude <= '-13.8'::double precision) AND (longitude >= '-76.4'::double precision) AND (longitude <= '-75.5'::double precision))
  Heap Blocks: exact=652
  Buffers: shared hit=687
  ->  Bitmap Index Scan on ix_attraction_lat_lon  (cost=0.00..215.56 rows=4264 width=0) (actual time=0.336..0.336 rows=4195 loops=1)
        Index Cond: ((latitude >= '-14.2'::double precision) AND (latitude <= '-13.8'::double precision) AND (longitude >= '-76.4'::double precision) AND (longitude <= '-75.5'::double precision))
        Buffers: shared hit=35
Planning:
  Buffers: shared hit=3
Planning Time: 0.073 ms
Execution Time: 1.214 ms
```

### RN-01: agencias validadas por nombre (catálogo público)

```
Limit  (cost=11.60..11.69 rows=35 width=434) (actual time=0.076..0.081 rows=50 loops=1)
  Buffers: shared hit=5
  ->  Sort  (cost=11.60..11.69 rows=35 width=434) (actual time=0.076..0.078 rows=50 loops=1)
        Sort Key: name
        Sort Method: quicksort  Memory: 30kB
        Buffers: shared hit=5
        ->  Seq Scan on agency  (cost=0.00..10.70 rows=35 width=434) (actual time=0.006..0.040 rows=80 loops=1)
              Filter: is_validated
              Rows Removed by Filter: 320
              Buffers: shared hit=5
Planning Time: 0.042 ms
Execution Time: 0.089 ms
```

### Analítica: eventos de un tipo en los últimos 7 días

```
GroupAggregate  (cost=13.01..219.83 rows=1 width=12) (actual time=6.078..6.078 rows=1 loops=1)
  Buffers: shared hit=2628
  ->  Bitmap Heap Scan on usage_events  (cost=13.01..219.67 rows=58 width=4) (actual time=1.270..5.256 rows=23473 loops=1)
        Recheck Cond: ((event_type = 'attraction_view'::usage_event_type) AND (created_at >= (now() - '7 days'::interval)))
        Heap Blocks: exact=2500
        Buffers: shared hit=2628
        ->  Bitmap Index Scan on ix_usage_events_type_created_at  (cost=0.00..13.00 rows=58 width=0) (actual time=1.060..1.060 rows=23473 loops=1)
              Index Cond: ((event_type = 'attraction_view'::usage_event_type) AND (created_at >= (now() - '7 days'::interval)))
              Buffers: shared hit=128
Planning Time: 0.090 ms
Execution Time: 6.097 ms
```

### Emergencias: historial SOS del usuario, más reciente primero

```
Limit  (cost=160.31..160.36 rows=20 width=28) (actual time=0.029..0.031 rows=20 loops=1)
  Buffers: shared hit=36
  ->  Sort  (cost=160.31..160.49 rows=72 width=28) (actual time=0.029..0.030 rows=20 loops=1)
        Sort Key: created_at DESC
        Sort Method: quicksort  Memory: 27kB
        Buffers: shared hit=36
        ->  Bitmap Heap Scan on sos_reports  (cost=4.84..158.39 rows=72 width=28) (actual time=0.012..0.024 rows=34 loops=1)
              Recheck Cond: (user_id = '3e0a0bd2-6d3f-4f3c-aa6e-2e70b5ad8042'::uuid)
              Heap Blocks: exact=34
              Buffers: shared hit=36
              ->  Bitmap Index Scan on ix_sos_reports_user_id  (cost=0.00..4.83 rows=72 width=0) (actual time=0.005..0.005 rows=34 loops=1)
                    Index Cond: (user_id = '3e0a0bd2-6d3f-4f3c-aa6e-2e70b5ad8042'::uuid)
                    Buffers: shared hit=2
Planning Time: 0.036 ms
Execution Time: 0.044 ms
```

### DIRCETUR: panel de incidencias recibidas, más recientes primero

```
Limit  (cost=21.54..21.55 rows=5 width=442) (actual time=0.856..0.861 rows=50 loops=1)
  Buffers: shared hit=138
  ->  Sort  (cost=21.54..21.55 rows=5 width=442) (actual time=0.855..0.857 rows=50 loops=1)
        Sort Key: created_at DESC
        Sort Method: top-N heapsort  Memory: 28kB
        Buffers: shared hit=138
        ->  Bitmap Heap Scan on tourist_incident_reports  (cost=4.32..21.48 rows=5 width=442) (actual time=0.089..0.578 rows=3334 loops=1)
              Recheck Cond: (status = 'received'::incident_status)
              Heap Blocks: exact=134
              Buffers: shared hit=138
              ->  Bitmap Index Scan on ix_tourist_incident_reports_status  (cost=0.00..4.31 rows=5 width=0) (actual time=0.069..0.069 rows=3334 loops=1)
                    Index Cond: (status = 'received'::incident_status)
                    Buffers: shared hit=4
Planning Time: 0.144 ms
Execution Time: 0.877 ms
```

## Planes DESPUÉS de los índices del sprint

### Catálogo: conteo de atractivos por categoría (filtro público)

```
Aggregate  (cost=1408.12..1408.13 rows=1 width=8) (actual time=7.332..7.334 rows=1 loops=1)
  Buffers: shared hit=695
  ->  Hash Join  (cost=360.98..1391.74 rows=6552 width=0) (actual time=1.134..7.103 rows=6531 loops=1)
        Hash Cond: (a.id = ac.attraction_id)
        Buffers: shared hit=695
        ->  Seq Scan on attraction a  (cost=0.00..952.00 rows=30000 width=16) (actual time=0.009..3.260 rows=30000 loops=1)
              Filter: is_active
              Buffers: shared hit=652
        ->  Hash  (cost=279.08..279.08 rows=6552 width=16) (actual time=1.116..1.117 rows=6531 loops=1)
              Buckets: 8192  Batches: 1  Memory Usage: 371kB
              Buffers: shared hit=43
              ->  Index Only Scan using idx_attraction_category_category on attraction_category ac  (cost=0.42..279.08 rows=6552 width=16) (actual time=0.011..0.520 rows=6531 loops=1)
                    Index Cond: (category_id = 'aefb106b-d9db-4dd3-99a0-b5af5e565efd'::uuid)
                    Heap Fetches: 0
                    Buffers: shared hit=43
Planning:
  Buffers: shared hit=14
Planning Time: 0.225 ms
Execution Time: 7.403 ms
```

### Catálogo: primera página por categoría, ordenada por nombre

```
Limit  (cost=3.25..54.95 rows=20 width=32) (actual time=0.143..0.145 rows=20 loops=1)
  Buffers: shared hit=275
  ->  Incremental Sort  (cost=3.25..16937.04 rows=6552 width=32) (actual time=0.143..0.144 rows=20 loops=1)
        Sort Key: a.name, a.id
        Presorted Key: a.name
        Full-sort Groups: 1  Sort Method: quicksort  Average Memory: 26kB  Peak Memory: 26kB
        Buffers: shared hit=275
        ->  Nested Loop  (cost=0.70..16642.20 rows=6552 width=32) (actual time=0.017..0.129 rows=21 loops=1)
              Buffers: shared hit=275
              ->  Index Scan using ix_attraction_name on attraction a  (cost=0.29..1573.29 rows=30000 width=32) (actual time=0.006..0.020 rows=90 loops=1)
                    Filter: is_active
                    Buffers: shared hit=4
              ->  Index Only Scan using idx_attraction_category_category on attraction_category ac  (cost=0.42..0.50 rows=1 width=16) (actual time=0.001..0.001 rows=0 loops=90)
                    Index Cond: ((category_id = 'aefb106b-d9db-4dd3-99a0-b5af5e565efd'::uuid) AND (attraction_id = a.id))
                    Heap Fetches: 0
                    Buffers: shared hit=271
Planning:
  Buffers: shared hit=14
Planning Time: 0.134 ms
Execution Time: 0.160 ms
```

### Detalle: promedio de calificaciones de un atractivo

```
Aggregate  (cost=16.26..16.27 rows=1 width=32) (actual time=0.072..0.072 rows=1 loops=1)
  Buffers: shared hit=4
  ->  Index Only Scan using idx_reviews_attraction_rating on reviews  (cost=0.29..14.76 rows=598 width=4) (actual time=0.010..0.043 rows=600 loops=1)
        Index Cond: (attraction_id = '39eec50a-2a9a-4086-a3d1-eb1a23b601da'::uuid)
        Heap Fetches: 0
        Buffers: shared hit=4
Planning Time: 0.098 ms
Execution Time: 0.088 ms
```

### Catálogo: listado por distrito entre atractivos activos

```
Limit  (cost=0.29..574.62 rows=50 width=32) (actual time=0.016..0.124 rows=50 loops=1)
  Buffers: shared hit=10
  ->  Index Scan using ix_attraction_name on attraction  (cost=0.29..1723.29 rows=150 width=32) (actual time=0.016..0.121 rows=50 loops=1)
        Filter: (is_active AND (lower((district)::text) = 'ica'::text))
        Rows Removed by Filter: 271
        Buffers: shared hit=10
Planning Time: 0.069 ms
Execution Time: 0.133 ms
```

### Geo: prefiltro por bounding box antes del Haversine

```
Bitmap Heap Scan on attraction  (cost=216.63..953.91 rows=4264 width=48) (actual time=0.405..1.339 rows=4195 loops=1)
  Recheck Cond: ((latitude >= '-14.2'::double precision) AND (latitude <= '-13.8'::double precision) AND (longitude >= '-76.4'::double precision) AND (longitude <= '-75.5'::double precision))
  Heap Blocks: exact=652
  Buffers: shared hit=687
  ->  Bitmap Index Scan on ix_attraction_lat_lon  (cost=0.00..215.56 rows=4264 width=0) (actual time=0.351..0.351 rows=4195 loops=1)
        Index Cond: ((latitude >= '-14.2'::double precision) AND (latitude <= '-13.8'::double precision) AND (longitude >= '-76.4'::double precision) AND (longitude <= '-75.5'::double precision))
        Buffers: shared hit=35
Planning:
  Buffers: shared hit=3
Planning Time: 0.099 ms
Execution Time: 1.466 ms
```

### RN-01: agencias validadas por nombre (catálogo público)

```
Limit  (cost=0.14..7.74 rows=50 width=434) (actual time=0.010..0.018 rows=50 loops=1)
  Buffers: shared hit=4
  ->  Index Scan using idx_agencies_validated on agency  (cost=0.14..30.54 rows=200 width=434) (actual time=0.010..0.015 rows=50 loops=1)
        Buffers: shared hit=4
Planning Time: 0.047 ms
Execution Time: 0.024 ms
```

### Analítica: eventos de un tipo en los últimos 7 días

```
GroupAggregate  (cost=13.01..219.83 rows=1 width=12) (actual time=7.159..7.160 rows=1 loops=1)
  Buffers: shared hit=2628
  ->  Bitmap Heap Scan on usage_events  (cost=13.01..219.67 rows=58 width=4) (actual time=1.661..6.377 rows=23473 loops=1)
        Recheck Cond: ((event_type = 'attraction_view'::usage_event_type) AND (created_at >= (now() - '7 days'::interval)))
        Heap Blocks: exact=2500
        Buffers: shared hit=2628
        ->  Bitmap Index Scan on ix_usage_events_type_created_at  (cost=0.00..13.00 rows=58 width=0) (actual time=1.423..1.424 rows=23473 loops=1)
              Index Cond: ((event_type = 'attraction_view'::usage_event_type) AND (created_at >= (now() - '7 days'::interval)))
              Buffers: shared hit=128
Planning Time: 0.122 ms
Execution Time: 7.234 ms
```

### Emergencias: historial SOS del usuario, más reciente primero

```
Limit  (cost=0.29..67.84 rows=20 width=28) (actual time=0.009..0.020 rows=20 loops=1)
  Buffers: shared hit=22
  ->  Index Scan using idx_sos_reports_user_created on sos_reports  (cost=0.29..338.04 rows=100 width=28) (actual time=0.008..0.018 rows=20 loops=1)
        Index Cond: (user_id = '3e0a0bd2-6d3f-4f3c-aa6e-2e70b5ad8042'::uuid)
        Buffers: shared hit=22
Planning Time: 0.051 ms
Execution Time: 0.030 ms
```

### DIRCETUR: panel de incidencias recibidas, más recientes primero

```
Limit  (cost=105.63..105.76 rows=50 width=442) (actual time=0.721..0.726 rows=50 loops=1)
  Buffers: shared hit=140
  ->  Sort  (cost=105.63..105.76 rows=50 width=442) (actual time=0.721..0.722 rows=50 loops=1)
        Sort Key: created_at DESC
        Sort Method: top-N heapsort  Memory: 28kB
        Buffers: shared hit=140
        ->  Bitmap Heap Scan on tourist_incident_reports  (cost=4.67..104.22 rows=50 width=442) (actual time=0.075..0.453 rows=3334 loops=1)
              Recheck Cond: (status = 'received'::incident_status)
              Heap Blocks: exact=134
              Buffers: shared hit=140
              ->  Bitmap Index Scan on idx_incident_reports_status_created  (cost=0.00..4.66 rows=50 width=0) (actual time=0.060..0.060 rows=3334 loops=1)
                    Index Cond: (status = 'received'::incident_status)
                    Buffers: shared hit=6
Planning Time: 0.061 ms
Execution Time: 0.736 ms
```

## Resumen

| Consulta | Seq Scan antes | Seq Scan después | Tiempo antes | Tiempo después |
|---|---|---|---|---|
| Catálogo: conteo de atractivos por categoría (filtro público) | sí | sí | 7.83 ms | 7.40 ms |
| Catálogo: primera página por categoría, ordenada por nombre | no | no | 0.17 ms | 0.16 ms |
| Detalle: promedio de calificaciones de un atractivo | no | no | 0.12 ms | 0.09 ms |
| Catálogo: listado por distrito entre atractivos activos | no | no | 0.12 ms | 0.13 ms |
| Geo: prefiltro por bounding box antes del Haversine | no | no | 1.21 ms | 1.47 ms |
| RN-01: agencias validadas por nombre (catálogo público) | sí | no | 0.09 ms | 0.02 ms |
| Analítica: eventos de un tipo en los últimos 7 días | no | no | 6.10 ms | 7.23 ms |
| Emergencias: historial SOS del usuario, más reciente primero | no | no | 0.04 ms | 0.03 ms |
| DIRCETUR: panel de incidencias recibidas, más recientes primero | no | no | 0.88 ms | 0.74 ms |

## Notas

- El **conteo total por categoría** mantiene `Seq Scan` incluso con el índice:
  el planificador prefiere recorrer la tabla una vez (30 000 filas, < 1 ms)
  antes que 30 000 accesos al índice; es una decisión correcta. La consulta
  que la API usa de verdad —la **página** del listado con `LIMIT`— sí va por
  índice.
- `ix_attraction_lat_lon` (attraction) y `ix_usage_events_type_created_at`
  (usage_events) ya existían de iteraciones previas y siguen cubriendo el
  bounding box geográfico y la analítica.
- El índice `idx_attractions_category_rating` del pedido original no existe
  en el modelo: `Attraction` no tiene `rating` (se calcula desde `reviews`)
  y la categoría es N:M. Queda cubierto por
  `idx_attraction_category_category` + `idx_reviews_attraction_rating`.
- El índice antiguo `ix_attraction_category_category_id` era prefijo del
  compuesto, así que la migración lo elimina para no duplicar escrituras.
