"""Excepciones personalizadas del módulo `emergency`."""

from src.core.exceptions import AppException


class MissingLocationPermissionException(AppException):
    """Sin coordenadas GPS no se puede derivar el incidente (RN-04, HTTP 400)."""

    status_code = 400
    default_detail = (
        "Se requieren las coordenadas GPS para reportar una emergencia"
    )


class SOSReportNotFoundException(AppException):
    """El reporte SOS pedido no existe (HTTP 404)."""

    status_code = 404
    default_detail = "Reporte de emergencia no encontrado"


class UnauthorizedIncidentAccessException(AppException):
    """Un usuario intenta ver un incidente que no es suyo (HTTP 403)."""

    status_code = 403
    default_detail = "No tienes permiso para ver este incidente"
