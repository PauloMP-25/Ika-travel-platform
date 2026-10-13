"""Capa de orquestación del módulo clima.

Implementa el Patrón Aggregator: dispara consultas concurrentes a 3 proveedores
diferentes, colecta las respuestas válidas (tolerando fallos parciales), y
calcula un consenso/promedio para entregar un dato altamente preciso y resiliente.
"""

import logging
import asyncio
from datetime import datetime

from src.modules.clima.adaptadores import (
    AdaptadorClimaBase,
    AdaptadorOpenWeatherMap,
    AdaptadorOpenMeteo,
    AdaptadorWeatherAPI,
)
from src.modules.clima.constants import DESTINOS_ICA, normalizar_nombre_destino
from src.modules.clima.exceptions import (
    DestinoNoEncontradoException,
    TodosLosProveedoresFallaronException,
)
from src.modules.clima.schemas import ClimaActual, ClimaActualResponse

logger = logging.getLogger(__name__)


class AgregadorClima:
    """Orquestador que implementa el Patrón Aggregator."""

    def __init__(self, adaptadores: list[AdaptadorClimaBase]):
        self.adaptadores = adaptadores

    async def obtener_consenso(self, latitud: float, longitud: float) -> ClimaActual:
        # Disparamos todas las peticiones concurrentemente
        tareas = [
            adaptador.obtener_clima_actual(latitud, longitud)
            for adaptador in self.adaptadores
        ]
        
        # return_exceptions=True permite que si una API falla, las otras sigan
        resultados = await asyncio.gather(*tareas, return_exceptions=True)

        exitosos = []
        nombres_fallidos = []
        nombres_exitosos = []

        for i, resultado in enumerate(resultados):
            nombre_api = self.adaptadores[i].nombre_proveedor
            if isinstance(resultado, Exception):
                logger.warning(f"Fallo en proveedor {nombre_api}: {resultado}")
                nombres_fallidos.append(nombre_api)
            else:
                exitosos.append(resultado)
                nombres_exitosos.append(nombre_api)

        # Si absolutamente todas fallaron, lanzamos la excepción de dominio
        if not exitosos:
            raise TodosLosProveedoresFallaronException([])

        # Retornamos el promedio calculado de los que sí respondieron
        return self._promediar_resultados(exitosos, nombres_exitosos)

    def _promediar_resultados(self, resultados: list[ClimaActualResponse], nombres: list[str]) -> ClimaActual:
        n = len(resultados)

        def prom(lista):
            return sum(lista) / n

        # Para las ráfagas que pueden ser None en algunas APIs, filtramos los Nones
        rafagas_validas = [r.rafagas_viento for r in resultados if r.rafagas_viento is not None]
        promedio_rafagas = sum(rafagas_validas) / len(rafagas_validas) if rafagas_validas else None

        # Para el UV, filtramos los 0 que vienen de OpenWeatherMap (porque no tiene el dato, no porque sea 0 real)
        uvs_validos = [r.indice_uv for r in resultados if r.indice_uv > 0]
        promedio_uv = sum(uvs_validos) / len(uvs_validos) if uvs_validos else 0.0

        clima_promedio = ClimaActual(
            temperatura_actual=round(prom([r.temperatura_actual for r in resultados]), 1),
            sensacion_termica=round(prom([r.sensacion_termica for r in resultados]), 1),
            probabilidad_precipitacion=round(prom([r.probabilidad_precipitacion for r in resultados]), 1),
            humedad=round(prom([r.humedad for r in resultados]), 1),
            velocidad_viento=round(prom([r.velocidad_viento for r in resultados]), 1),
            rafagas_viento=round(promedio_rafagas, 1) if promedio_rafagas else None,
            indice_uv=round(promedio_uv, 1),
            descripcion_clima=resultados[0].descripcion_clima,  # Usamos la primera descripcion
            visibilidad=round(prom([r.visibilidad for r in resultados]), 1),
            hora_amanecer=resultados[0].hora_amanecer,
            hora_atardecer=resultados[0].hora_atardecer,
            fecha_hora_pronostico=datetime.utcnow(),
            origen_api=f"Consenso ({n} APIs): {', '.join(nombres)}"
        )
        return clima_promedio


# Instancia Global inyectando los adaptadores (Inversión de Dependencias)
agregador_clima = AgregadorClima(
    adaptadores=[
        AdaptadorOpenWeatherMap(),
        AdaptadorWeatherAPI(),
        AdaptadorOpenMeteo(),
    ]
)


def resolver_coordenadas_destino(destino: str) -> tuple[float, float]:
    clave = normalizar_nombre_destino(destino)
    if clave not in DESTINOS_ICA:
        raise DestinoNoEncontradoException(destino)
    return DESTINOS_ICA[clave]


async def obtener_clima_destino(destino: str) -> ClimaActualResponse:
    """Punto de entrada usado por el router.
    """
    latitud, longitud = resolver_coordenadas_destino(destino)
    
    # Delegamos al agregador la tarea de consensuar la información
    clima_consenso = await agregador_clima.obtener_consenso(latitud, longitud)
    
    return ClimaActualResponse(
        destino=destino,
        **clima_consenso.model_dump()
    )
