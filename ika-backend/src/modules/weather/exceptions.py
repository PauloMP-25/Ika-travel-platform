"""Excepciones personalizadas del módulo de clima.

Ningún adaptador debe dejar escapar excepciones crudas de `httpx` hacia
capas superiores: todo fallo se traduce a una de estas clases para que
`core/exceptions.py` pueda mapearlas a códigos HTTP en un solo lugar.
"""


class ErrorProveedorClimaBase(Exception):
    """Excepción base para cualquier fallo relacionado a un proveedor de clima."""

    def __init__(self, proveedor: str, mensaje: str):
        self.proveedor = proveedor
        self.mensaje = mensaje
        super().__init__(f"[{proveedor}] {mensaje}")


class ProveedorClimaTimeoutException(ErrorProveedorClimaBase):
    """El proveedor externo no respondió dentro del tiempo límite configurado."""


class ProveedorClimaNoDisponibleException(ErrorProveedorClimaBase):
    """El proveedor externo respondió con error HTTP o falló la conexión."""


class ErrorMapeoClimaException(ErrorProveedorClimaBase):
    """La respuesta del proveedor no pudo mapearse al esquema estándar `ClimaActual`."""


class DestinoNoEncontradoException(Exception):
    """El destino solicitado no existe en el catálogo de coordenadas conocidas."""

    def __init__(self, destino: str):
        self.destino = destino
        super().__init__(f"Destino '{destino}' no reconocido")


class TodosLosProveedoresFallaronException(Exception):
    """Ningún proveedor climático pudo responder (viola RN-03 de frescura de datos)."""

    def __init__(self, errores: list[ErrorProveedorClimaBase]):
        self.errores = errores
        detalle = "; ".join(str(error) for error in errores)
        super().__init__(f"Todos los proveedores de clima fallaron: {detalle}")
