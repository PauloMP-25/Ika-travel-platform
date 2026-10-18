"""Genera `docs/optimizacion_bd.md` con los `EXPLAIN (ANALYZE, BUFFERS)`.

Reproduce el apartado F2 del Sprint 4 de forma reproducible:

1. Crea una BD aislada (`ika_travel_explain`) y la deja en el esquema
   **anterior** a los índices del sprint (`alembic upgrade a50e921e5758`).
2. Siembra datos sintéticos con volumen suficiente para que el planificador
   tenga alternativas reales.
3. Ejecuta las consultas representativas del catálogo, la analítica y las
   emergencias y guarda su plan.
4. Aplica los índices (`alembic upgrade head`) y repite las consultas.
5. Escribe el documento comparativo.

Uso (desde `ika-backend/`):

    python scripts/explicar_optimizacion.py

No toca la BD de desarrollo ni la de pruebas.
"""

from __future__ import annotations

import asyncio
import os
import random
import subprocess
import sys
import urllib.parse as up
from datetime import datetime, timedelta, timezone
from pathlib import Path

import asyncpg

RAIZ = Path(__file__).resolve().parents[1]
BD_SCRATCH = os.getenv("BD_EXPLAIN", "ika_travel_explain")
REVISION_SIN_INDICES = "a50e921e5758"
MARCADOR = datetime.now(tz=timezone.utc)

DISTRITOS = ["Ica", "Paracas", "Nazca", "Pisco", "Chincha", "Palpa"]
CATEGORIAS = [
    "sandboarding", "buggy", "enoturismo", "pisco", "gastronomia", "museo",
    "historia", "naturaleza-marina", "islas-ballestas", "arqueologia", "nasca", "cultural",
]

# (título, SQL) de las consultas que F2 pretende acelerar. Se generan con
# `construir_consultas` para resolver antes los ids y no medir subconsultas
# auxiliares (con `OFFSET`, que el planificador resuelve con Seq Scan).
def construir_consultas(
    id_categoria: str, id_atractivo: str, id_usuario: str
) -> list[tuple[str, str]]:
    return [
        (
            "Catálogo: conteo de atractivos por categoría (filtro público)",
            f"""
            SELECT count(*) FROM attraction a
            WHERE a.is_active = true
              AND EXISTS (SELECT 1 FROM attraction_category ac
                          WHERE ac.attraction_id = a.id
                            AND ac.category_id = '{id_categoria}')
            """,
        ),
        (
            "Catálogo: primera página por categoría, ordenada por nombre",
            f"""
            SELECT a.id, a.name FROM attraction a
            WHERE a.is_active = true
              AND EXISTS (SELECT 1 FROM attraction_category ac
                          WHERE ac.attraction_id = a.id
                            AND ac.category_id = '{id_categoria}')
            ORDER BY a.name, a.id LIMIT 20
            """,
        ),
        (
            "Detalle: promedio de calificaciones de un atractivo",
            f"SELECT avg(rating) FROM reviews WHERE attraction_id = '{id_atractivo}'",
        ),
        (
            "Catálogo: listado por distrito entre atractivos activos",
            "SELECT id, name FROM attraction WHERE is_active = true AND lower(district) = 'ica' ORDER BY name LIMIT 50",
        ),
        (
            "Geo: prefiltro por bounding box antes del Haversine",
            """
            SELECT id, name, latitude, longitude FROM attraction
            WHERE latitude BETWEEN -14.2 AND -13.8 AND longitude BETWEEN -76.4 AND -75.5
            """,
        ),
        (
            "RN-01: agencias validadas por nombre (catálogo público)",
            "SELECT id, name FROM agency WHERE is_validated ORDER BY name LIMIT 50",
        ),
        (
            "Analítica: eventos de un tipo en los últimos 7 días",
            """
            SELECT event_type, count(*) FROM usage_events
            WHERE event_type = 'attraction_view' AND created_at >= now() - interval '7 days'
            GROUP BY event_type
            """,
        ),
        (
            "Emergencias: historial SOS del usuario, más reciente primero",
            f"""
            SELECT id, status, created_at FROM sos_reports
            WHERE user_id = '{id_usuario}'
            ORDER BY created_at DESC LIMIT 20
            """,
        ),
        (
            "DIRCETUR: panel de incidencias recibidas, más recientes primero",
            """
            SELECT id, title, created_at FROM tourist_incident_reports
            WHERE status = 'received' ORDER BY created_at DESC LIMIT 50
            """,
        ),
    ]


def _url_bd(nombre_bd: str) -> tuple[str, int, str, str, str]:
    base = os.getenv("URL_BASE_DATOS")
    if not base:
        for linea in (RAIZ / ".env").read_text(encoding="utf-8").splitlines():
            if linea.startswith("URL_BASE_DATOS="):
                base = linea.split("=", 1)[1].strip()
    u = up.urlparse(base)
    return u.hostname, u.port, u.username, up.unquote(u.password), nombre_bd


def _url_completa(nombre_bd: str) -> str:
    base = os.getenv("URL_BASE_DATOS")
    if not base:
        for linea in (RAIZ / ".env").read_text(encoding="utf-8").splitlines():
            if linea.startswith("URL_BASE_DATOS="):
                base = linea.split("=", 1)[1].strip()
    return base.rsplit("/", 1)[0] + "/" + nombre_bd


def _alembic(*args: str) -> None:
    entorno = {**os.environ, "URL_BASE_DATOS": _url_completa(BD_SCRATCH)}
    resultado = subprocess.run(
        [sys.executable, "-m", "alembic", *args],
        cwd=RAIZ,
        env=entorno,
        capture_output=True,
        text=True,
    )
    if resultado.returncode != 0:
        raise RuntimeError(f"alembic {' '.join(args)} falló:\n{resultado.stderr}")


async def _recrear_bd() -> None:
    host, puerto, usuario, clave, _ = _url_bd(BD_SCRATCH)
    admin = await asyncpg.connect(host=host, port=puerto, user=usuario, password=clave, database="postgres")
    await admin.execute(
        f"""
        SELECT pg_terminate_backend(pid) FROM pg_stat_activity
        WHERE datname = '{BD_SCRATCH}' AND pid <> pg_backend_pid()
        """
    )
    await admin.execute(f'DROP DATABASE IF EXISTS "{BD_SCRATCH}"')
    await admin.execute(f'CREATE DATABASE "{BD_SCRATCH}"')
    await admin.close()


async def _siembra(conn: "asyncpg.Connection") -> None:
    """Datos sintéticos con volumen suficiente para que merezca la pena indexar."""
    rng = random.Random(42)

    usuarios = [(f"u{i}@ika.pe", f"Usuario {i}") for i in range(600)]
    await conn.executemany(
        "INSERT INTO users (id, email, password_hash, full_name, auth_provider, role, preferred_language, preferences, is_active, created_at, updated_at) "
        "VALUES (gen_random_uuid(), $1, 'x', $2, 'email', 'tourist', 'es', '[]', true, now(), now())",
        usuarios,
    )

    await conn.executemany(
        "INSERT INTO category (id, name, slug) VALUES (gen_random_uuid(), initcap($1), $1)",
        [(c,) for c in CATEGORIAS],
    )
    categorias = await conn.fetch("SELECT id, slug FROM category")
    ids_cat = [f["id"] for f in categorias]

    attrs = [
        (
            f"Atractivo {i:05d}",
            "Descripción de prueba para el análisis de rendimiento.",
            -14.0 - rng.random(),
            -75.7 - rng.random(),
            rng.choice(DISTRITOS),
        )
        for i in range(30000)
    ]
    await conn.executemany(
        "INSERT INTO attraction (id, name, description, latitude, longitude, district, is_active, created_at, updated_at) "
        "VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, true, now(), now())",
        attrs,
    )
    ids_attr = [f["id"] for f in await conn.fetch("SELECT id FROM attraction")]

    pares = {(rng.choice(ids_attr), rng.choice(ids_cat)) for _ in range(90000)}
    await conn.executemany(
        "INSERT INTO attraction_category (attraction_id, category_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
        list(pares),
    )

    ids_usuario = [f["id"] for f in await conn.fetch("SELECT id FROM users")]

    # Pares (usuario, atractivo) únicos: la tabla tiene restricción única.
    reseñas = [
        (ids_usuario[i % len(ids_usuario)], ids_attr[(i // len(ids_usuario)) % len(ids_attr)],
         rng.choice([1, 2, 3, 4, 5]))
        for i in range(150000)
    ]
    await conn.executemany(
        "INSERT INTO reviews (id, user_id, attraction_id, rating, created_at) "
        "VALUES (gen_random_uuid(), $1, $2, $3, now())",
        reseñas,
    )

    agencias = [
        (f"Agencia {i:04d}", str(20000000000 + i), i % 5 == 0) for i in range(400)
    ]
    await conn.executemany(
        "INSERT INTO agency (id, name, ruc, is_validated, created_at) "
        "VALUES (gen_random_uuid(), $1, $2, $3, now())",
        agencias,
    )
    ids_agencia = [f["id"] for f in await conn.fetch("SELECT id FROM agency")]

    await conn.executemany(
        "INSERT INTO tour (id, agency_id, name, description, price, duration_hours) "
        "VALUES (gen_random_uuid(), $1, 'Tour', 'Descripcion', 100, 2)",
        [(rng.choice(ids_agencia),) for _ in range(1200)],
    )

    await conn.executemany(
        "INSERT INTO sos_reports (id, user_id, latitude, longitude, status, created_at) "
        "VALUES (gen_random_uuid(), (SELECT id FROM users OFFSET $1 LIMIT 1), -14.1, -75.7, 'pending', "
        "now() - make_interval(hours => $2))",
        [(i % 600, i % 200) for i in range(20000)],
    )

    await conn.executemany(
        "INSERT INTO tourist_incident_reports (id, user_id, incident_type, title, description, status, created_at) "
        "VALUES (gen_random_uuid(), (SELECT id FROM users OFFSET $1 LIMIT 1), 'informal_service', 'Titulo', 'Descripcion', $2, "
        "now() - make_interval(hours => $3))",
        [(i % 600, ["received", "in_review", "resolved"][i % 3], i % 500) for i in range(10000)],
    )

    await conn.execute(
        """
        INSERT INTO usage_events (id, event_type, ui_language, created_at)
        SELECT gen_random_uuid(),
               (ARRAY['attraction_view','attraction_search','translation'])[1 + (i % 3)]::usage_event_type,
               'es',
               now() - (random() * interval '30 days')
        FROM generate_series(1, 300000) AS s(i)
        """
    )


async def _explicar(conn: "asyncpg.Connection") -> list[tuple[str, str, bool]]:
    id_categoria = await conn.fetchval("SELECT id FROM category WHERE slug = 'sandboarding'")
    id_atractivo = await conn.fetchval("SELECT id FROM attraction WHERE name = 'Atractivo 00010'")
    id_usuario = await conn.fetchval("SELECT id FROM users WHERE email = 'u10@ika.pe'")

    resultados = []
    for titulo, sql in construir_consultas(str(id_categoria), str(id_atractivo), str(id_usuario)):
        await conn.fetch(sql)  # calienta el búfer compartido: mide el plan, no el disco frío
        filas = await conn.fetch(f"EXPLAIN (ANALYZE, BUFFERS) {sql}")
        plan = "\n".join(f["QUERY PLAN"] for f in filas)
        seq_scan = "Seq Scan" in plan
        resultados.append((titulo, plan, seq_scan))
    return resultados


def _tiempo_ms(plan: str) -> float:
    for linea in plan.splitlines():
        if linea.strip().startswith("Execution Time:"):
            return float(linea.split(":")[1].replace("ms", "").strip())
    return 0.0


def _tabla_markdown(resultados: list[tuple[str, str, bool]]) -> str:
    lineas = []
    for titulo, plan, _ in resultados:
        lineas.append(f"### {titulo}\n")
        lineas.append("```")
        lineas.append(plan)
        lineas.append("```\n")
    return "\n".join(lineas)


async def main() -> None:
    print(f"Recreando BD aislada '{BD_SCRATCH}' ...")
    await _recrear_bd()

    print("Aplicando migraciones hasta la revisión previa al sprint ...")
    _alembic("upgrade", REVISION_SIN_INDICES)

    host, puerto, usuario, clave, _ = _url_bd(BD_SCRATCH)
    conn = await asyncpg.connect(host=host, port=puerto, user=usuario, password=clave, database=BD_SCRATCH)
    try:
        print("Sembrando datos sintéticos ...")
        await _siembra(conn)
        print("Capturando planes ANTES de los índices ...")
        antes = await _explicar(conn)
    finally:
        await conn.close()

    print("Aplicando los índices del Sprint 4 ...")
    _alembic("upgrade", "head")

    conn = await asyncpg.connect(host=host, port=puerto, user=usuario, password=clave, database=BD_SCRATCH)
    try:
        print("Capturando planes DESPUÉS de los índices ...")
        despues = await _explicar(conn)
    finally:
        await conn.close()

    volumenes = """
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
"""

    resumen = [
        "## Resumen",
        "",
        "| Consulta | Seq Scan antes | Seq Scan después | Tiempo antes | Tiempo después |",
        "|---|---|---|---|---|",
    ]
    for (titulo, plan_antes, antes_seq), (_, plan_despues, despues_seq) in zip(antes, despues):
        resumen.append(
            f"| {titulo} | {'sí' if antes_seq else 'no'} | {'sí' if despues_seq else 'no'} "
            f"| {_tiempo_ms(plan_antes):.2f} ms | {_tiempo_ms(plan_despues):.2f} ms |"
        )
    resumen.append("")

    documento = f"""# Optimización de PostgreSQL — Sprint 4 (F2)

**Generado por** `scripts/explicar_optimizacion.py` el
{MARCADOR.strftime('%Y-%m-%d %H:%M')} con `EXPLAIN (ANALYZE, BUFFERS)` real.

Cada índice se aplicó con la migración `f1a2b3c4d5e6` (`rev_1_indices_sprint4`).

**Elección sobre `CREATE INDEX CONCURRENTLY`:** para el volumen del MVP se
usan índices normales (DDL transaccional, más simple en Alembic). El coste
es una breve exclusión de escrituras sobre la tabla durante la creación. Si
la tabla crece en producción, la siguiente migración puede recrearlos con
`CONCURRENTLY` dentro de `op.get_context().autocommit_block()`.

{volumenes}
## Planes ANTES de los índices del sprint

{_tabla_markdown(antes)}
## Planes DESPUÉS de los índices del sprint

{_tabla_markdown(despues)}
{chr(10).join(resumen)}
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
"""

    destino = RAIZ / "docs" / "optimizacion_bd.md"
    destino.write_text(documento, encoding="utf-8")
    print(f"Documento escrito en {destino}")


if __name__ == "__main__":
    asyncio.run(main())
