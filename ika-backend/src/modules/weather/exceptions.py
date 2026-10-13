"""Excepciones personalizadas del módulo de clima.

Todas heredan de `ErrorDeNegocio` (`src/core/exceptions.py`), por lo que el
manejador global las convierte en JSON con su `codigo_http` sin que el router
tenga que capturar nada. Ningún adaptador debe dejar escapar excepciones
crudas de `httpx`: todo fallo se traduce a una de estas clases.

Mapeo HTTP:
    - DestinoNoEncontradoException ........ 404
    - AtractivoSinClimaException .......... 404
    - ProveedorClima* / TodosLosProveedores 502 (fallo de un servicio externo)
    - DatosClimaDesactualizadosException .. 503 (RN-03: dato > 6 h y sin refresco)
"""

from src.core.exceptions import ErrorDeNegocio


class ErrorProveedorClimaBase(ErrorDeNegocio):
    """Excepción base para cualquier fallo relacionado a un proveedor de clima."""

    codigo_http = 502
    codigo = "proveedor_clima_error"
    mensaje_por_defecto = "El proveedor meteorológico no está disponible."

    def __init__(self, proveedor: str = "desconocido", mensaje: str | None = None):
        self.proveedor = proveedor
        super().__init__(f"[{proveedor}] {mensaje or self.mensaje_por_defecto}")


class ProveedorClimaTimeoutException(ErrorProveedorClimaBase):
    """El proveedor externo no respondió dentro del tiempo límite configurado."""

    codigo = "proveedor_clima_timeout"
    mensaje_por_defecto = "El proveedor no respondió a tiempo."


class ProveedorClimaNoDisponibleException(ErrorProveedorClimaBase):
    """El proveedor externo respondió con error HTTP o falló la conexión."""

    codigo = "proveedor_clima_no_disponible"


class ErrorMapeoClimaException(ErrorProveedorClimaBase):
    """La respuesta del proveedor no pudo mapearse al esquema estándar `ClimaActual`."""

    codigo = "proveedor_clima_formato_invalido"
    mensaje_por_defecto = "La respuesta del proveedor tiene un formato inesperado."


class WeatherProviderUnavailableException(ErrorProveedorClimaBase):
    """Fallo del proveedor del pronóstico (Open-Meteo) tras agotar reintentos."""

    codigo = "proveedor_pronostico_no_disponible"

    def __init__(self, mensaje: str | None = None):
        super().__init__("open-meteo", mensaje)


class DestinoNoEncontradoException(ErrorDeNegocio):
    """El destino solicitado no existe en el catálogo de coordenadas conocidas."""

    codigo_http = 404
    codigo = "destino_no_encontrado"

    def __init__(self, destino: str):
        self.destino = destino
        super().__init__(f"Destino '{destino}' no reconocido")


class AtractivoSinClimaException(ErrorDeNegocio):
    """El `attraction_id` pedido no existe o está inactivo en el catálogo."""

    codigo_http = 404
    codigo = "atractivo_no_encontrado"
    mensaje_por_defecto = "El atractivo solicitado no existe."


class TodosLosProveedoresFallaronException(ErrorDeNegocio):
    """Ningún proveedor climático pudo responder."""

    codigo_http = 502
    codigo = "todos_los_proveedores_fallaron"

    def __init__(self, errores: list[ErrorProveedorClimaBase] | None = None):
        self.errores = errores or []
        detalle = "; ".join(str(error) for error in self.errores)
        mensaje = "Ningún proveedor de clima respondió."
        if detalle:
            mensaje += f" {detalle}"
        super().__init__(
            mensaje, extra={"proveedores_intentados": [e.proveedor for e in self.errores]}
        )


class DatosClimaDesactualizadosException(ErrorDeNegocio):
    """RN-03: no hay datos de ≤ 6 h y no fue posible refrescarlos (HTTP 503)."""

    codigo_http = 503
    codigo = "datos_clima_desactualizados"
    mensaje_por_defecto = (
        "No hay datos meteorológicos recientes disponibles. Intenta nuevamente en unos minutos."
    )


# Alias con el nombre usado en `docs/sprint_2.md`.
StaleWeatherDataException = DatosClimaDesactualizadosException
