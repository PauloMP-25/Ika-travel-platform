"""Excepciones personalizadas del módulo `reviews` y su manejador HTTP.

Mismo patrón que `users/exceptions.py`: el módulo es autocontenido y basta
con llamar a `register_reviews_exception_handlers(app)` desde `main.py`.
"""

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse


class ReviewsException(Exception):
    """Base de las excepciones de negocio del módulo `reviews`."""

    status_code: int = 500
    default_detail: str = "Error en el módulo de reseñas"

    def __init__(self, detail: str | None = None) -> None:
        self.detail = detail if detail is not None else self.default_detail
        super().__init__(self.detail)


class AttractionNotFoundException(ReviewsException):
    """El atractivo a reseñar o guardar como favorito no existe (HTTP 404)."""

    status_code = 404
    default_detail = "El atractivo indicado no existe"


class DuplicateReviewException(ReviewsException):
    """El usuario ya dejó una reseña para ese atractivo (HTTP 409)."""

    status_code = 409
    default_detail = "Ya has publicado una reseña para este atractivo"


class ReviewNotFoundException(ReviewsException):
    """La reseña indicada no existe (HTTP 404)."""

    status_code = 404
    default_detail = "La reseña indicada no existe"


class ReviewForbiddenException(ReviewsException):
    """Intento de borrar una reseña que no es del usuario (HTTP 403)."""

    status_code = 403
    default_detail = "No tienes permiso para modificar esta reseña"


class InvalidRatingException(ReviewsException):
    """Calificación fuera del rango 1–5 (HTTP 422).

    Pydantic ya la valida en la entrada; esta excepción es la defensa en
    profundidad si el servicio se invoca desde otro código.
    """

    status_code = 422
    default_detail = "La calificación debe estar entre 1 y 5"


def register_reviews_exception_handlers(app: FastAPI) -> None:
    """Adjunta el manejador de las excepciones de `reviews` a la app."""

    @app.exception_handler(ReviewsException)
    async def handle_reviews_exception(
        request: Request, exc: ReviewsException
    ) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content={"detail": exc.detail},
        )
