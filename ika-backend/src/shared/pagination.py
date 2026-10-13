from dataclasses import dataclass

from fastapi import Query


@dataclass
class ParametrosPaginacion:
    """Dependencia reutilizable: ``params: ParametrosPaginacion = Depends()``."""

    page: int = Query(1, ge=1, description="Número de página (desde 1)")
    page_size: int = Query(10, ge=1, le=50, description="Elementos por página (máx. 50)")

    @property
    def offset(self) -> int:
        return (self.page - 1) * self.page_size


def hay_siguiente_pagina(total: int, page: int, page_size: int) -> bool:
    return page * page_size < total
