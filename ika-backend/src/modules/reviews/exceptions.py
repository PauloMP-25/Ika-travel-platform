"""Excepciones de dominio del módulo `reviews`."""

from src.core.exceptions import ErrorDeNegocio


class ReviewAlreadyExistsException(ErrorDeNegocio):
    """El usuario ya emitió una reseña para este atractivo (1 por usuario por atractivo)."""

    codigo_http = 409
    codigo = "review_duplicada"
    mensaje_por_defecto = "Ya has publicado una reseña para este atractivo."

    def __init__(self, mensaje: str | None = None) -> None:
        super().__init__(mensaje or self.mensaje_por_defecto)


class ReviewNotFoundException(ErrorDeNegocio):
    """La reseña solicitada no existe."""

    codigo_http = 404
    codigo = "review_no_encontrada"
    mensaje_por_defecto = "Reseña no encontrada."

    def __init__(self, mensaje: str | None = None) -> None:
        super().__init__(mensaje or self.mensaje_por_defecto)


class UnauthorizedReviewActionException(ErrorDeNegocio):
    """El usuario intenta modificar o borrar una reseña que no le pertenece."""

    codigo_http = 403
    codigo = "accion_no_autorizada"
    mensaje_por_defecto = "No tienes permiso para modificar esta reseña."

    def __init__(self, mensaje: str | None = None) -> None:
        super().__init__(mensaje or self.mensaje_por_defecto)


class InvalidImageUploadException(ErrorDeNegocio):
    """El archivo subido no cumple con el formato o tamaño permitido."""

    codigo_http = 400
    codigo = "imagen_invalida"
    mensaje_por_defecto = "Archivo inválido. Solo se admiten imágenes JPG, PNG o WEBP menores a 5MB."

    def __init__(self, mensaje: str | None = None) -> None:
        super().__init__(mensaje or self.mensaje_por_defecto)
