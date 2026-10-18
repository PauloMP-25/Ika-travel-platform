"""Crea (si no existe) la BD aislada usada para probar las migraciones."""

import asyncio
import os
import urllib.parse as up
from pathlib import Path

import asyncpg

BD_OBJETIVO = os.getenv("BD_MIGRACION", "ika_travel_mig")


def _url_bd() -> tuple[str, int, str, str, str]:
    base = os.getenv("URL_BASE_DATOS")
    if not base:
        for linea in Path(".env").read_text(encoding="utf-8").splitlines():
            if linea.startswith("URL_BASE_DATOS="):
                base = linea.split("=", 1)[1].strip()
    u = up.urlparse(base)
    return u.hostname, u.port, u.username, up.unquote(u.password), u.path.lstrip("/")


async def main() -> None:
    host, port, user, pw, _ = _url_bd()
    admin = await asyncpg.connect(host=host, port=port, user=user, password=pw, database="postgres")
    existe = await admin.fetchval("SELECT 1 FROM pg_database WHERE datname = $1", BD_OBJETIVO)
    if not existe:
        await admin.execute(f'CREATE DATABASE "{BD_OBJETIVO}"')
        print(f"BD {BD_OBJETIVO} creada")
    else:
        print(f"BD {BD_OBJETIVO} ya existia")
    await admin.close()


if __name__ == "__main__":
    asyncio.run(main())
