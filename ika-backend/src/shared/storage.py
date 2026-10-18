"""Almacenamiento de archivos subidos por el usuario (patrón Strategy).

`StorageStrategy` define el contrato y `LocalStorageStrategy` lo implementa
sobre el disco. En producción (AWS S3 / GCP) basta con escribir una
`S3StorageStrategy` y cambiar `STORAGE_BACKEND` en `.env` (una línea), sin
tocar el módulo `reviews` ni el resto del código.

También se pueden inyectar dobles de prueba (`MockStorageStrategy` en los
tests) para no escribir en el sistema de archivos real.
"""

from abc import ABC, abstractmethod
from pathlib import Path
from uuid import uuid4

from fastapi import UploadFile

from src.core.config import configuracion

# MIME types aceptados para las fotos de reseñas.
TIPOS_IMAGEN_PERMITIDOS = {"image/jpeg", "image/png"}

# Extensión resultante por tipo de contenido (el nombre del cliente se
# descarta: evita path traversal y colisiones).
_EXTENSIONES = {"image/jpeg": ".jpg", "image/png": ".png"}


class StorageError(Exception):
    """Base de los errores de almacenamiento de archivos."""


class InvalidUploadError(StorageError):
    """El archivo no es una imagen permitida o supera el tamaño máximo.

    Se traduce a HTTP 422 vía el manejador global de `core/exceptions.py`.
    """


class StorageStrategy(ABC):
    """Contrato común para guardar archivos y devolver su URL pública."""

    @abstractmethod
    def save(self, file: UploadFile, *, prefix: str = "reviews") -> str:
        """Valida el archivo, lo persiste y devuelve su URL pública."""


class LocalStorageStrategy(StorageStrategy):
    """Guarda los archivos en `config.UPLOADS_DIR` y sirve vía `/static/...`."""

    def __init__(self, base_dir: str | Path | None = None) -> None:
        self.base_dir = Path(base_dir or configuracion.UPLOADS_DIR)

    def save(self, file: UploadFile, *, prefix: str = "reviews") -> str:
        content = file.file.read()
        _validate_image(file, content)

        # Nombre aleatorio: el filename del cliente no se usa jamás.
        name = f"{uuid4().hex}{_EXTENSIONES[file.content_type]}"
        destination = self.base_dir / prefix / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(content)

        return f"/static/uploads/{prefix}/{name}"


def _validate_image(file: UploadFile, content: bytes) -> None:
    """Rechaza archivos que no sean imagen/jpeg o imagen/png de < 5 MB."""
    if file.content_type not in TIPOS_IMAGEN_PERMITIDOS:
        raise InvalidUploadError(
            f"Tipo de archivo no permitido: {file.content_type}. "
            "Solo se aceptan imágenes JPEG o PNG."
        )

    max_bytes = configuracion.MAX_UPLOAD_MB * 1024 * 1024
    if len(content) > max_bytes:
        raise InvalidUploadError(
            f"La imagen supera el máximo de {configuracion.MAX_UPLOAD_MB} MB."
        )


def get_storage() -> StorageStrategy:
    """Fabrica la estrategia activa según `STORAGE_BACKEND` (una línea en .env)."""
    backend = configuracion.STORAGE_BACKEND.strip().lower()
    if backend == "local":
        return LocalStorageStrategy()
    raise StorageError(
        f"STORAGE_BACKEND desconocido: '{configuracion.STORAGE_BACKEND}'. "
        "Valores soportados: 'local'."
    )
