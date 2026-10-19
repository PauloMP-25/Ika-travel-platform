"""Constantes, coordenadas de destinos y umbrales meteorológicos oficiales para Ica."""

from __future__ import annotations

from dataclasses import dataclass

# Coordenadas oficiales de destinos turísticos piloto
DESTINOS_ICA: dict[str, tuple[float, float]] = {
    "plaza de armas de pisco": (-13.7103, -76.2053),
    "plaza de armas de chincha": (-13.4172, -76.1325),
    "playa la mina": (-13.9167, -76.3167),
    "playa roja": (-13.8867, -76.2872),
    "playa el chaco": (-13.8322, -76.2483),
    "playa hermosa de marcona": (-15.3583, -75.1750),

    "huacachina": (-14.0873, -75.7637),
    "islas ballestas": (-13.8167, -76.2833),
    "reserva nacional de paracas": (-13.8333, -76.2500),
    "plaza de armas de ica": (-14.0678, -75.7286),
    "bodega tacama": (-14.0206, -75.7089),
    "cerro blanco": (-14.1333, -75.7333),
    "pueblo de cachiche": (-14.0583, -75.7486),
    "cañon de los perdidos": (-14.6833, -75.7167),
}


def normalizar_nombre_destino(destino: str) -> str:
    return destino.strip().lower()


# ======================================================================
# Umbrales Oficiales de Alertas Meteorológicas de Ica (P2)
# ======================================================================
@dataclass(frozen=True)
class UmbralAlerta:
    tipo: str
    advisory: float  # Nivel bajo / preventivo
    warning: float   # Nivel medio / precaución
    danger: float    # Nivel alto / peligro inminente


UMBRALES_ICA = {
    # Vientos Paracas (solo aplican a la zona costera de Paracas/Pisco)
    "paracas_wind": UmbralAlerta("paracas_wind", advisory=25.0, warning=35.0, danger=50.0),
    # Radiación UV (según escala oficial de la OMS: 11+ = Extremo)
    "extreme_uv": UmbralAlerta("extreme_uv", advisory=8.0, warning=11.0, danger=12.0),
    # Calor desértico / golpe de calor
    "high_temperature": UmbralAlerta("high_temperature", advisory=33.0, warning=37.0, danger=40.0),
    # Lluvia / Huayco en quebradas (precipitación en mm/h)
    "rain_hazard": UmbralAlerta("rain_hazard", advisory=1.0, warning=4.0, danger=8.0),
    # Temperatura de la arena superficial en dunas (°C)
    "hot_sand": UmbralAlerta("hot_sand", advisory=36.0, warning=42.0, danger=48.0),
}
