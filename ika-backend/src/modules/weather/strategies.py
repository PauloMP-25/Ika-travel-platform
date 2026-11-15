"""Patrón Estrategia (Strategy Pattern) para el Recomendador Turístico Personalizado de Ika Travel.

Permite desacoplar y personalizar dinámicamente los algoritmos de afinidad,
pesos climáticos y directivas de redacción según el perfil del turista
(ej. aventura, gastronomía/pisco, naturaleza/marina, cultural o balanceado).
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any


class BaseRecommendationStrategy(ABC):
    """Interfaz abstracta del Patrón Estrategia para scoring y personalización."""

    @property
    @abstractmethod
    def slug(self) -> str:
        """Identificador único de la estrategia."""
        ...

    @property
    @abstractmethod
    def nombre(self) -> str:
        """Nombre legible de la estrategia."""
        ...

    @abstractmethod
    def calcular_afinidad(self, preferencias_turista: list[str] | None, categorias_atractivo: list[str]) -> float:
        """Calcula el bono de afinidad (0.0 a 0.25) entre los gustos del usuario y el atractivo."""
        ...

    @abstractmethod
    def calcular_ajuste_climatico(self, temperatura: float, viento: float, uv: float) -> float:
        """Calcula el factor de idoneidad climática según el tipo de actividad."""
        ...

    @abstractmethod
    def directiva_personalizada_ia(self, estilo: str | None, presupuesto: str | None, compania: str | None) -> str:
        """Genera directivas específicas para que Gemini adapte las sugerencias al perfil."""
        ...


class AventuraStrategy(BaseRecommendationStrategy):
    """Estrategia para turistas que buscan adrenalina, dunas, sandboarding y deportes extremos."""

    @property
    def slug(self) -> str:
        return "aventura"

    @property
    def nombre(self) -> str:
        return "Turismo de Aventura & Adrenalina en el Desierto"

    def calcular_afinidad(self, preferencias_turista: list[str] | None, categorias_atractivo: list[str]) -> float:
        tags = [c.lower() for c in categorias_atractivo]
        if any(t in tags for t in ["aventura", "sandboarding", "desierto", "deportes"]):
            return 0.25
        return 0.05

    def calcular_ajuste_climatico(self, temperatura: float, viento: float, uv: float) -> float:
        # Aventura en dunas: ideal viento 10-25 km/h, sol radiante, penaliza viento > 35 km/h
        if viento > 35:
            return 0.35  # Viento fuerte levanta arena, visibilidad nula
        if 20 <= temperatura <= 33:
            return 1.0
        return 0.80

    def directiva_personalizada_ia(self, estilo: str | None, presupuesto: str | None, compania: str | None) -> str:
        presupuesto_str = f"con enfoque {presupuesto}" if presupuesto else "accesible y de alto valor"
        compania_str = f"ideal para disfrutar {compania}" if compania else "para grupos o viajeros activos"
        return (
            f"El turista busca adrenalina y deportes de acción ({presupuesto_str}, {compania_str}). "
            "Destaca recorridos en tubulares (buggies), sandboarding en dunas o trekking por cañones. "
            "Recomienda franjas horarias con atardecer fotográfico en el desierto."
        )


class EnoturismoStrategy(BaseRecommendationStrategy):
    """Estrategia para turistas interesados en gastronomía, viñedos, cata de pisco y maridaje."""

    @property
    def slug(self) -> str:
        return "vino_pisco"

    @property
    def nombre(self) -> str:
        return "Enoturismo & Ruta del Pisco y Vino"

    def calcular_afinidad(self, preferencias_turista: list[str] | None, categorias_atractivo: list[str]) -> float:
        tags = [c.lower() for c in categorias_atractivo]
        if any(t in tags for t in ["gastronomia", "vino_pisco", "enoturismo", "bodegas"]):
            return 0.25
        return 0.05

    def calcular_ajuste_climatico(self, temperatura: float, viento: float, uv: float) -> float:
        # Bodegas y viñedos cuentan con áreas techadas y bodegas frescas
        return 1.0 if uv < 12 else 0.85

    def directiva_personalizada_ia(self, estilo: str | None, presupuesto: str | None, compania: str | None) -> str:
        return (
            "El turista prioriza la experiencia enológica y gastronómica regional. "
            "Recomienda visitas guiadas a bodegas patrimoniales (Tacama, Sotelo), proceso de destilación del pisco "
            "quebranta y maridaje con gastronomía iqueña. Sugiere refugiarse en bodegas durante el pico de radiación solar."
        )


class NaturalezaMarinaStrategy(BaseRecommendationStrategy):
    """Estrategia para amantes de la fauna marina, playas, reservas y áreas naturales protegidas."""

    @property
    def slug(self) -> str:
        return "naturaleza"

    @property
    def nombre(self) -> str:
        return "Naturaleza Marina & Áreas Protegidas (Paracas)"

    def calcular_afinidad(self, preferencias_turista: list[str] | None, categorias_atractivo: list[str]) -> float:
        tags = [c.lower() for c in categorias_atractivo]
        if any(t in tags for t in ["naturaleza", "marina", "playa", "sol_playa", "ecoturismo"]):
            return 0.25
        return 0.05

    def calcular_ajuste_climatico(self, temperatura: float, viento: float, uv: float) -> float:
        # Actividades marítimas requieren viento suave a moderado (< 30 km/h)
        if viento >= 35:
            return 0.30
        return 0.95

    def directiva_personalizada_ia(self, estilo: str | None, presupuesto: str | None, compania: str | None) -> str:
        return (
            "El turista ama el ecoturismo, la observación de aves, pingüinos de Humboldt y lobos marinos. "
            "Recomienda zarpes matutinos en deslizadores (08:00 - 10:00 AM) antes del incremento vespertino del viento, "
            "y miradores escénicos como la Catedral o Playa Roja con respeto irrestricto a la directiva SERNANP."
        )


class CulturalPatrimonialStrategy(BaseRecommendationStrategy):
    """Estrategia para turistas interesados en historia, misticismo, arquitectura y museos."""

    @property
    def slug(self) -> str:
        return "cultura"

    @property
    def nombre(self) -> str:
        return "Turismo Cultural, Histórico y Místico"

    def calcular_afinidad(self, preferencias_turista: list[str] | None, categorias_atractivo: list[str]) -> float:
        tags = [c.lower() for c in categorias_atractivo]
        if any(t in tags for t in ["cultura", "arqueologia", "religioso", "mistico", "historia"]):
            return 0.25
        return 0.05

    def calcular_ajuste_climatico(self, temperatura: float, viento: float, uv: float) -> float:
        if uv >= 11:
            return 0.75  # Recorrido peatonal requiere sombra
        return 0.95

    def directiva_personalizada_ia(self, estilo: str | None, presupuesto: str | None, compania: str | None) -> str:
        return (
            "El turista busca conocer la identidad, historia y misticismo de Ica. "
            "Recomienda la Palmera de las 7 Cabezas, leyendas de Cachiche, el Santuario del Señor de Luren "
            "y el museo regional. Enfatiza paseos peatonales durante las primeras horas de la mañana o al atardecer."
        )


class BalancedGeneralStrategy(BaseRecommendationStrategy):
    """Estrategia general equilibrada para turistas sin preferencias específicas o público diverso."""

    @property
    def slug(self) -> str:
        return "general"

    @property
    def nombre(self) -> str:
        return "Recomendación Turística Equilibrada Integral"

    def calcular_afinidad(self, preferencias_turista: list[str] | None, categorias_atractivo: list[str]) -> float:
        return 0.10

    def calcular_ajuste_climatico(self, temperatura: float, viento: float, uv: float) -> float:
        return 0.90

    def directiva_personalizada_ia(self, estilo: str | None, presupuesto: str | None, compania: str | None) -> str:
        return (
            "Ofrece una recomendación balanceada y atractiva de los mejores atractivos de Ica, "
            "combinando naturaleza, cultura y gastronomía adaptada a las condiciones climáticas del día."
        )


class RecommendationStrategyFactory:
    """Fábrica (Factory Pattern) para seleccionar la estrategia de recomendación óptima."""

    _ESTRATEGIAS: dict[str, BaseRecommendationStrategy] = {
        "aventura": AventuraStrategy(),
        "sandboarding": AventuraStrategy(),
        "vino_pisco": EnoturismoStrategy(),
        "gastronomia": EnoturismoStrategy(),
        "naturaleza": NaturalezaMarinaStrategy(),
        "marina": NaturalezaMarinaStrategy(),
        "sol_playa": NaturalezaMarinaStrategy(),
        "cultura": CulturalPatrimonialStrategy(),
        "historia": CulturalPatrimonialStrategy(),
        "general": BalancedGeneralStrategy(),
    }

    @classmethod
    def obtener_estrategia(
        cls,
        preferencias_turista: list[str] | None = None,
        categoria_principal: str | None = None,
    ) -> BaseRecommendationStrategy:
        """Determina la mejor estrategia según las preferencias del turista o la categoría."""
        if preferencias_turista:
            for pref in preferencias_turista:
                clave = pref.lower().strip()
                if clave in cls._ESTRATEGIAS:
                    return cls._ESTRATEGIAS[clave]
                # Coincidencias parciales
                for k, estrat in cls._ESTRATEGIAS.items():
                    if k in clave or clave in k:
                        return estrat

        if categoria_principal:
            cat_lower = categoria_principal.lower().strip()
            if cat_lower in cls._ESTRATEGIAS:
                return cls._ESTRATEGIAS[cat_lower]

        return cls._ESTRATEGIAS["general"]
