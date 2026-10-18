"""Estrategias de almacenamiento de imágenes (Patrón Strategy).

Define una interfaz común `StorageStrategy` y sus implementaciones concretas:
- `LocalStorageStrategy`: Guarda archivos en el sistema local o volumen Docker.
- `MockStorageStrategy`: Para entornos de testing o ejecución sin filesystem real.
"""

from abc import ABC, abstractmethod
import os
import uuid
from pathlib import Path


class StorageStrategy(ABC):
    """Interfaz abstracta del Patrón Strategy para almacenamiento de archivos."""

    @abstractmethod
    async def upload(self, file_content: bytes, filename: str, content_type: str) -> str:
        """Sube un archivo y retorna la URL pública o relativa generada."""
        pass

    @abstractmethod
    async def delete(self, file_url: str) -> bool:
        """Elimina un archivo dado su URL o ruta."""
        pass


class LocalStorageStrategy(StorageStrategy):
    """Estrategia de guardado en disco local / volumen montado."""

    def __init__(self, base_dir: str = "media/reviews", url_prefix: str = "/media/reviews"):
        self.base_dir = Path(base_dir)
        self.url_prefix = url_prefix.rstrip("/")
        self.base_dir.mkdir(parents=True, exist_ok=True)

    async def upload(self, file_content: bytes, filename: str, content_type: str) -> str:
        ext = Path(filename).suffix.lower() or ".jpg"
        unique_name = f"{uuid.uuid4().hex}{ext}"
        destination = self.base_dir / unique_name
        
        with open(destination, "wb") as f:
            f.write(file_content)
            
        return f"{self.url_prefix}/{unique_name}"

    async def delete(self, file_url: str) -> bool:
        filename = Path(file_url).name
        target = self.base_dir / filename
        if target.exists():
            try:
                target.unlink()
                return True
            except OSError:
                return False
        return False


class MockStorageStrategy(StorageStrategy):
    """Estrategia simulada para pruebas unitarias de alta velocidad."""

    def __init__(self):
        self.saved_files: dict[str, bytes] = {}

    async def upload(self, file_content: bytes, filename: str, content_type: str) -> str:
        unique_name = f"mock_{uuid.uuid4().hex[:8]}_{filename}"
        url = f"/mock/media/{unique_name}"
        self.saved_files[url] = file_content
        return url

    async def delete(self, file_url: str) -> bool:
        if file_url in self.saved_files:
            del self.saved_files[file_url]
            return True
        return False


_current_strategy: StorageStrategy = LocalStorageStrategy()


def get_storage_strategy() -> StorageStrategy:
    """Retorna la estrategia de almacenamiento configurada."""
    return _current_strategy


def set_storage_strategy(strategy: StorageStrategy) -> None:
    """Permite intercambiar la estrategia dinámicamente (e.g. en tests o Cloud)."""
    global _current_strategy
    _current_strategy = strategy
