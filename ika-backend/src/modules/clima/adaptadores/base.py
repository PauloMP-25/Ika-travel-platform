"""Interfaz común (patrón Strategy + Adapter) que deben implementar todos
los adaptadores de proveedores de clima externos."""

from abc import ABC, abstractmethod

from src.modules.clima.schemas import ClimaActual


class AdaptadorClimaBase(ABC):
    """Contrato que todo adaptador de un proveedor climático debe cumplir.

    Cada implementación concreta (OpenWeatherMap, WeatherAPI, Tomorrow.io)
    se encarga de: (1) llamar a la API externa, (2) traducir su respuesta
    "sucia" al esquema estándar `ClimaActual` (requerimiento de limpieza de
    datos). El resto del sistema (`service.py`) nunca conoce los detalles
    de cada API — solo habla con esta interfaz (principio Strategy).
    """

    nombre_proveedor: str

    @abstractmethod
    async def obtener_clima_actual(self, latitud: float, longitud: float) -> ClimaActual:
        """Consulta el proveedor externo y retorna el clima ya normalizado.

        Debe lanzar excepciones de `src.modules.clima.exceptions` ante
        cualquier fallo (timeout, error HTTP, error de mapeo) — nunca debe
        propagar excepciones crudas de `httpx` hacia capas superiores.
        """
        raise NotImplementedError
