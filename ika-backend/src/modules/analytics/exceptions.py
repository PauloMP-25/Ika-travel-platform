from src.core.exceptions import ErrorDeNegocio


class InvalidDateRangeException(ErrorDeNegocio):
    codigo_http = 400
    codigo = "RANGO_FECHAS_INVALIDO"
    mensaje_por_defecto = "La fecha inicial no puede ser posterior a la fecha final."

    def __init__(self, mensaje: str | None = None) -> None:
        super().__init__(mensaje or self.mensaje_por_defecto)


class DateRangeTooLargeException(ErrorDeNegocio):
    codigo_http = 400
    codigo = "RANGO_FECHAS_EXCEDIDO"
    mensaje_por_defecto = "El rango máximo permitido es de 366 días."

    def __init__(self, mensaje: str | None = None) -> None:
        super().__init__(mensaje or self.mensaje_por_defecto)
