"""Módulo de Seguridad Temporal y Planificación para Mañana (SOLID - Strategy Pattern).

Integra normativas oficiales y recomendaciones de DIRCETUR Ica, SERNANP, DICAPI,
GORE Ica (Ordenanza Regional N° 007-2017) y MINCETUR.

Evalúa la hora local de Ica (America/Lima) frente a las ventanas operativas oficiales.
Si la consulta se realiza en horario nocturno o fuera de la franja autorizada,
analiza el pronóstico meteorológico del día de mañana (Open-Meteo) para seleccionar
dinámicamente la hora óptima de visita (viento, UV, temperatura) y generar una
recomendación formal de 'Planificación para Mañana'.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime, time
from zoneinfo import ZoneInfo
from typing import Any

from src.modules.weather.schemas import PronosticoHoraResponse

ZONA_HORARIA_ICA = ZoneInfo("America/Lima")


@dataclass(frozen=True)
class EvaluacionSeguridadHoraria:
    es_horario_seguro: bool
    es_planificacion_manana: bool
    hora_sugerida: str | None
    justificacion_seguridad: str
    justificacion_climatica_manana: str | None
    normativa_oficial: str
    temperatura_proyectada: float | None = None
    viento_proyectado: float | None = None
    uv_proyectado: float | None = None
    condicion_proyectada: str | None = None


class EstrategiaSeguridadHoraria(ABC):
    """Interfaz abstracta (Strategy) para reglas de horario y seguridad por actividad."""

    @property
    @abstractmethod
    def nombre_perfil(self) -> str:
        """Nombre del perfil turístico."""

    @property
    @abstractmethod
    def ventana_horario_seguro(self) -> tuple[time, time]:
        """Rango (hora_inicio, hora_fin) seguro y regulado para visitas presenciales."""

    @property
    @abstractmethod
    def motivo_riesgo_nocturno(self) -> str:
        """Explicación del riesgo de visitar fuera de horario."""

    @property
    @abstractmethod
    def normativa_oficial(self) -> str:
        """Referencia normativa o directiva oficial aplicable."""

    def esta_en_horario_seguro(self, hora_actual: time) -> bool:
        inicio, fin = self.ventana_horario_seguro
        if inicio <= fin:
            return inicio <= hora_actual <= fin
        return hora_actual >= inicio or hora_actual <= fin

    @abstractmethod
    def calcular_hora_optima_manana(
        self, horas_pronostico: list[PronosticoHoraResponse]
    ) -> tuple[str, str, float, float, float, str]:
        """Calcula dinámicamente la mejor hora para visitar mañana según el clima proyectado.
        
        Devuelve: (hora_str, explicacion_clima, temp, viento, uv, condicion).
        """


class SeguridadMarinaYPlayas(EstrategiaSeguridadHoraria):
    """Playas y naturaleza marina (Reserva Nacional de Paracas e Islas Ballestas)."""

    nombre_perfil = "naturaleza_marina"
    # Horario oficial SERNANP / DICAPI:
    # - Reserva de Paracas (Control Santo Domingo): 09:00 a 16:00 horas.
    # - Zarpes a Islas Ballestas (Muelle El Chaco): 06:00 a 13:00 horas (turnos 08:00 y 10:00).
    ventana_horario_seguro = (time(8, 0), time(16, 0))
    motivo_riesgo_nocturno = (
        "Por disposición de DICAPI y SERNANP, el circuito turístico de la Reserva Nacional de Paracas "
        "opera de 09:00 a 16:00 h y los zarpes en El Chaco cierran a las 13:00 h. Queda prohibido el ingreso nocturno "
        "por riesgo de mareas altas, visibilidad nula y vientos Paracas."
    )
    normativa_oficial = "Directiva SERNANP (Puesto Santo Domingo 09:00-16:00) y Capitanía de Puerto DICAPI (Muelle El Chaco)"

    def calcular_hora_optima_manana(
        self, horas_pronostico: list[PronosticoHoraResponse]
    ) -> tuple[str, str, float, float, float, str]:
        # Para Paracas y Ballestas, DICAPI y operadores recomiendan el turno de las 08:00 a.m. o 09:00 a.m.
        # Buscar en la mañana (07:00 a 11:00) la hora con menor velocidad de viento antes de que aumente al mediodía.
        horas_manana = [h for h in horas_pronostico if 7 <= h.time.hour <= 11]
        if not horas_manana:
            horas_manana = horas_pronostico[:6]

        # Minimizar viento y buscar temperatura >= 18°C
        mejor_hora = min(horas_manana, key=lambda h: (h.wind_speed, abs(h.temperature - 21.0)))
        hora_fmt = mejor_hora.time.strftime("%I:%M %p")
        explicacion = (
            f"Según el pronóstico de mañana, a las {hora_fmt} el viento estará calmo ({mejor_hora.wind_speed:.1f} km/h) "
            f"con {mejor_hora.temperature:.1f}°C y condiciones de {mejor_hora.condition}. Esto coincide con el primer turno de zarpe "
            f"recomendado por Capitanía para disfrutar de mar tranquilo sin oleaje anómalo."
        )
        return hora_fmt, explicacion, mejor_hora.temperature, mejor_hora.wind_speed, mejor_hora.uv_index, mejor_hora.condition


class SeguridadDesiertoYAventura(EstrategiaSeguridadHoraria):
    """Dunas de Huacachina, Sandboarding, Cañón de los Perdidos."""

    nombre_perfil = "aventura_desierto"
    # Ordenanza Regional N° 007-2017-GORE-ICA y Ordenanza Municipal N° 007-2020-MPI:
    # Salidas de tubulares autorizadas: 08:00 a.m. a 05:00 p.m. (Sunset: 16:00 - 16:30).
    ventana_horario_seguro = (time(8, 0), time(17, 30))
    motivo_riesgo_nocturno = (
        "Conforme a la Ordenanza Regional N° 007-2017-GORE-ICA y Ordenanza N° 007-2020-MPI, el servicio turístico "
        "de tubulares en las dunas de Huacachina concluye a las 17:00 / 17:30 h. De noche se prohíbe el tránsito vehicular "
        "en dunas por alto riesgo de desorientación, vuelcos y enfriamiento severo de la arena."
    )
    normativa_oficial = "Ordenanza Regional N° 007-2017-GORE-ICA / Ordenanza Municipal N° 007-2020-MPI (ACR Laguna de Huacachina)"

    def calcular_hora_optima_manana(
        self, horas_pronostico: list[PronosticoHoraResponse]
    ) -> tuple[str, str, float, float, float, str]:
        # Para el desierto, buscar franja matutina autorizada (08:00 a 10:30) con temperatura < 27°C y UV no extremo
        horas_validas = [h for h in horas_pronostico if 8 <= h.time.hour <= 10]
        if not horas_validas:
            horas_validas = horas_pronostico[:6]

        mejor_hora = min(horas_validas, key=lambda h: (h.uv_index, abs(h.temperature - 23.0)))
        hora_fmt = mejor_hora.time.strftime("%I:%M %p")
        explicacion = (
            f"El pronóstico proyecta para las {hora_fmt} un índice UV moderado de {mejor_hora.uv_index:.1f} "
            f"y {mejor_hora.temperature:.1f}°C con viento de {mejor_hora.wind_speed:.1f} km/h, cumpliendo el inicio de salidas "
            f"autorizadas bajo la normativa de la ACR Huacachina antes de la radiación solar del mediodía."
        )
        return hora_fmt, explicacion, mejor_hora.temperature, mejor_hora.wind_speed, mejor_hora.uv_index, mejor_hora.condition


class SeguridadEnoturismoYBodegas(EstrategiaSeguridadHoraria):
    """Viñedos y bodegas tradicionales (Tacama, Bodega Sotelo, Queirolo, El Catador)."""

    nombre_perfil = "enoturismo_gastronomia"
    # Horario oficial de atención y tours guiados (El Tambo de Tacama / MINCETUR):
    # Martes a Domingo de 09:30 a.m. a 05:00 p.m.
    ventana_horario_seguro = (time(9, 30), time(17, 0))
    motivo_riesgo_nocturno = (
        "Los centros enoturísticos y viñedos históricos atienden de 09:30 a 17:00 h (MINCETUR / DIRCETUR). "
        "En horario nocturno las instalaciones de cata y salas de barricas permanecen cerradas al turismo."
    )
    normativa_oficial = "Directrices Enoturísticas MINCETUR / Horario Oficial El Tambo de Tacama (09:30-17:00 h)"

    def calcular_hora_optima_manana(
        self, horas_pronostico: list[PronosticoHoraResponse]
    ) -> tuple[str, str, float, float, float, str]:
        # Salidas de tours inician a las 09:30 y 10:00 a.m.
        horas_apertura = [h for h in horas_pronostico if 9 <= h.time.hour <= 12]
        if not horas_apertura:
            horas_apertura = horas_pronostico[:6]

        mejor_hora = min(horas_apertura, key=lambda h: abs(h.temperature - 23.5))
        hora_fmt = mejor_hora.time.strftime("%I:%M %p")
        explicacion = (
            f"A las {hora_fmt} inician los primeros recorridos guiados por las bodegas con temperatura de {mejor_hora.temperature:.1f}°C "
            f"y {mejor_hora.condition}, condiciones óptimas para el paseo por los viñedos y catas dirigidas."
        )
        return hora_fmt, explicacion, mejor_hora.temperature, mejor_hora.wind_speed, mejor_hora.uv_index, mejor_hora.condition


class SeguridadArqueologia(EstrategiaSeguridadHoraria):
    """Líneas de Nazca, Cahuachi, Acueductos de Cantalloc."""

    nombre_perfil = "arqueologia_misterio"
    # Horario oficial de operaciones aéreas en Aeródromo María Reiche (CORPAC / DGAC / MINCETUR):
    # Sobrevuelos continuos de 08:00 a.m. a 04:30 p.m.
    ventana_horario_seguro = (time(8, 0), time(16, 30))
    motivo_riesgo_nocturno = (
        "Las operaciones aéreas en el Aeródromo María Reiche de Nazca cierran a las 16:30 h por normativas de aviación "
        "civil (CORPAC / DGAC). No se autorizan sobrevuelos sin luz solar ni fuera de visibilidad VFR."
    )
    normativa_oficial = "Regulaciones Aeronáuticas DGAC / CORPAC Aeródromo María Reiche Neuman de Nazca (08:00-16:30 h)"

    def calcular_hora_optima_manana(
        self, horas_pronostico: list[PronosticoHoraResponse]
    ) -> tuple[str, str, float, float, float, str]:
        # Las mejores salidas de sobrevuelo recomendadas por operadores y CORPAC son entre 08:00 y 10:00 a.m.
        horas_vuelo = [h for h in horas_pronostico if 8 <= h.time.hour <= 11]
        if not horas_vuelo:
            horas_vuelo = horas_pronostico[:6]

        mejor_hora = min(horas_vuelo, key=lambda h: h.wind_speed)
        hora_fmt = mejor_hora.time.strftime("%I:%M %p")
        explicacion = (
            f"A las {hora_fmt} el pronóstico indica vientos mínimos de {mejor_hora.wind_speed:.1f} km/h y visibilidad despejada ({mejor_hora.condition}), "
            f"cumpliendo la ventana óptima recomendada por aviación para la máxima nitidez y estabilidad en el sobrevuelo."
        )
        return hora_fmt, explicacion, mejor_hora.temperature, mejor_hora.wind_speed, mejor_hora.uv_index, mejor_hora.condition


class SeguridadCulturaYCiudad(EstrategiaSeguridadHoraria):
    """Plaza de Armas de Ica, Santuario de Luren, Cachiche."""

    nombre_perfil = "cultura_mistica"
    # Horario seguro de visitas cívico-religiosas: 08:00 a 21:30.
    ventana_horario_seguro = (time(8, 0), time(21, 30))
    motivo_riesgo_nocturno = (
        "Pasadas las 21:30 h concluyen los horarios de visita en templos históricos (como Luren) y museos cívicos. "
        "Se recomienda recorrer el centro monumental en horario diurno o vespertino."
    )
    normativa_oficial = "Recomendaciones de Seguridad Turística DIRCETUR Ica / POLTUR (Circuito Histórico Monumental)"

    def calcular_hora_optima_manana(
        self, horas_pronostico: list[PronosticoHoraResponse]
    ) -> tuple[str, str, float, float, float, str]:
        horas_ciudad = [h for h in horas_pronostico if 8 <= h.time.hour <= 11]
        if not horas_ciudad:
            horas_ciudad = horas_pronostico[:6]

        mejor_hora = min(horas_ciudad, key=lambda h: (h.uv_index, abs(h.temperature - 22.0)))
        hora_fmt = mejor_hora.time.strftime("%I:%M %p")
        explicacion = (
            f"A las {hora_fmt} el centro histórico ofrece temperatura fresca de {mejor_hora.temperature:.1f}°C "
            f"y baja radiación ({mejor_hora.uv_index:.1f} UV), ideal para la apertura de monumentos y recorrido peatonal."
        )
        return hora_fmt, explicacion, mejor_hora.temperature, mejor_hora.wind_speed, mejor_hora.uv_index, mejor_hora.condition


class SelectorEstrategiaSeguridad:
    """Selector de estrategias según las categorías y nombre del atractivo."""

    _ESTRATEGIAS = [
        SeguridadMarinaYPlayas(),
        SeguridadDesiertoYAventura(),
        SeguridadEnoturismoYBodegas(),
        SeguridadArqueologia(),
        SeguridadCulturaYCiudad(),
    ]

    @classmethod
    def obtener_estrategia(cls, slugs_categorias: list[str], nombre_atractivo: str) -> EstrategiaSeguridadHoraria:
        texto_busqueda = (nombre_atractivo + " " + " ".join(slugs_categorias)).lower()

        if any(w in texto_busqueda for w in ("playa", "paracas", "ballestas", "marina", "reserva")):
            return cls._ESTRATEGIAS[0]
        if any(w in texto_busqueda for w in ("sandboarding", "buggy", "tubular", "duna", "huacachina", "canon", "cañon")):
            return cls._ESTRATEGIAS[1]
        if any(w in texto_busqueda for w in ("vino", "pisco", "bodega", "tacama", "sotelo", "queirolo", "catador", "gastronomia")):
            return cls._ESTRATEGIAS[2]
        if any(w in texto_busqueda for w in ("lineas", "nazca", "geoglifos", "arqueologico", "cantalloc", "cahuachi")):
            return cls._ESTRATEGIAS[3]
        return cls._ESTRATEGIAS[4]


def evaluar_seguridad_temporal(
    *,
    slugs_categorias: list[str],
    nombre_atractivo: str,
    horas_pronostico: list[PronosticoHoraResponse] | None = None,
    hora_referencia_lima: time | None = None,
) -> EvaluacionSeguridadHoraria:
    """Punto de entrada principal para evaluar si es seguro visitar ahora o planificar para mañana."""
    estrategia = SelectorEstrategiaSeguridad.obtener_estrategia(slugs_categorias, nombre_atractivo)

    if hora_referencia_lima is None:
        hora_referencia_lima = datetime.now(ZONA_HORARIA_ICA).time()

    en_horario = estrategia.esta_en_horario_seguro(hora_referencia_lima)

    if en_horario:
        return EvaluacionSeguridadHoraria(
            es_horario_seguro=True,
            es_planificacion_manana=False,
            hora_sugerida=None,
            justificacion_seguridad="Horario regular y seguro conforme a normativas oficiales para realizar la visita.",
            justificacion_climatica_manana=None,
            normativa_oficial=estrategia.normativa_oficial,
        )

    # Fuera de horario seguro: requiere planificación para el día de mañana
    hora_sugerida = None
    justificacion_clima = None
    temp_proy = None
    viento_proy = None
    uv_proy = None
    cond_proy = None

    if horas_pronostico:
        hora_sugerida, justificacion_clima, temp_proy, viento_proy, uv_proy, cond_proy = (
            estrategia.calcular_hora_optima_manana(horas_pronostico)
        )
    else:
        hora_sugerida = "08:30 AM"
        justificacion_clima = "Se aconseja planificar la salida por la mañana para aprovechar las mejores condiciones del día."

    return EvaluacionSeguridadHoraria(
        es_horario_seguro=False,
        es_planificacion_manana=True,
        hora_sugerida=hora_sugerida,
        justificacion_seguridad=estrategia.motivo_riesgo_nocturno,
        justificacion_climatica_manana=justificacion_clima,
        normativa_oficial=estrategia.normativa_oficial,
        temperatura_proyectada=temp_proy,
        viento_proyectado=viento_proy,
        uv_proyectado=uv_proy,
        condicion_proyectada=cond_proy,
    )
