#!/usr/bin/env bash
set -e

echo "==> [Ika Travel] Verificando disponibilidad de la base de datos..."
python3 -c "
import socket
import sys
import urllib.parse
import os

url = os.environ.get('URL_BASE_DATOS', '')
host = 'db'
port = 5432

if url:
    # Formato: postgresql+asyncpg://user:pass@host:port/dbname
    try:
        clean_url = url.replace('postgresql+asyncpg://', 'http://')
        parsed = urllib.parse.urlparse(clean_url)
        if parsed.hostname:
            host = parsed.hostname
        if parsed.port:
            port = parsed.port
    except Exception:
        pass

import time
for i in range(30):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(2.0)
        s.connect((host, port))
        s.close()
        print(f'Conexión exitosa a Postgres en {host}:{port}')
        sys.exit(0)
    except Exception:
        time.sleep(1)

print(f'Tiempo de espera agotado para conectar a Postgres en {host}:{port}', file=sys.stderr)
sys.exit(1)
"

echo "==> [Ika Travel] Aplicando migraciones de Alembic (upgrade head)..."
alembic upgrade head

echo "==> [Ika Travel] Ejecutando sincronización de datos semilla y usuario DIRCETUR..."
python3 -m src.modules.catalog.seed || echo "Advertencia en seed: continuando..."

echo "==> [Ika Travel] Iniciando servicio..."
exec "$@"
