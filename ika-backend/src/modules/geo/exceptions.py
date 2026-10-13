from src.core.exceptions import ErrorDeNegocio


class UserTooFarFromAttractionException(ErrorDeNegocio):
    """Reutilizable por otros módulos (p. ej. reseñas verificadas por ubicación)."""

    codigo_http = 403
    codigo = "usuario_lejos_del_atractivo"
    mensaje_por_defecto = "Estás demasiado lejos del atractivo para realizar esta acción."


class InvalidRouteRequestException(ErrorDeNegocio):
    codigo_http = 400
    codigo = "ruta_invalida"
    mensaje_por_defecto = "La solicitud de ruta no es válida."
