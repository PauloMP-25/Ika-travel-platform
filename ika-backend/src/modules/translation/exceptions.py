"""Excepciones de dominio del módulo translation (Sprint 3, RNF-04).

Todas heredan de `ErrorDeNegocio`; el manejador global registrado en
`core/exceptions.py` las convierte en {"detail", "codigo"} con el
`codigo_http` de cada subclase.
"""

from src.core.exceptions import ErrorDeNegocio


class TranslationProviderUnavailableException(ErrorDeNegocio):
    """El proveedor de traducción no respondió, falló o no está configurado."""

    codigo_http = 503
    codigo = "TRADUCCION_PROVEEDOR_NO_DISPONIBLE"
    mensaje_por_defecto = (
        "El servicio de traducción no está disponible. Use las frases oficiales descargadas."
    )


class InvalidTranslationResponseException(ErrorDeNegocio):
    """El proveedor devolvió una salida vacía o desproporcionada."""

    codigo_http = 502
    codigo = "TRADUCCION_RESPUESTA_INVALIDA"
    mensaje_por_defecto = "El proveedor devolvió una traducción inválida. Intente nuevamente."
