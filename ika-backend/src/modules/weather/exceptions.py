from src.core.exceptions import ErrorDeNegocio


class StaleWeatherDataException(ErrorDeNegocio):
    """RN-03: no hay datos de menos de 6 h y el refresco también falló."""

    codigo_http = 503
    codigo = "clima_desactualizado"
    mensaje_por_defecto = (
        "No hay datos climáticos recientes y no fue posible actualizarlos en este momento."
    )


class WeatherProviderUnavailableException(ErrorDeNegocio):
    codigo_http = 503
    codigo = "proveedor_clima_no_disponible"
    mensaje_por_defecto = "El servicio meteorológico externo no está disponible."
