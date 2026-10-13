"""Excepciones personalizadas del módulo `emergency`.

Se apoyan en `ErrorDeNegocio` (de `src/core/exceptions.py`), que ya tiene
registrado un manejador global en `main.py`: no hace falta repetir
`HTTPException` en el router.
"""

from src.core.exceptions import ErrorDeNegocio


class MissingLocationPermissionException(ErrorDeNegocio):
    """Sin coordenadas GPS no se puede derivar el incidente (RN-04, HTTP 400)."""

    codigo_http = 400
    codigo = "ubicacion_requerida"
    mensaje_por_defecto = (
        "Se requieren las coordenadas GPS para reportar una emergencia"
    )


class SOSReportNotFoundException(ErrorDeNegocio):
    """El reporte SOS pedido no existe (HTTP 404)."""

    codigo_http = 404
    codigo = "reporte_sos_no_encontrado"
    mensaje_por_defecto = "Reporte de emergencia no encontrado"


class UnauthorizedIncidentAccessException(ErrorDeNegocio):
    """Un usuario intenta ver un incidente que no es suyo (HTTP 403)."""

    codigo_http = 403
    codigo = "incidente_no_autorizado"
    mensaje_por_defecto = "No tienes permiso para ver este incidente"
