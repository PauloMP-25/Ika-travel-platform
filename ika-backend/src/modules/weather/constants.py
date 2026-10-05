"""Catálogo mínimo de coordenadas de destinos turísticos de Ica.

Es un stand-in temporal para el PoC. En la siguiente iteración esto debe
reemplazarse por una consulta real a `catalog.Attraction` (que ya tiene
`latitude`/`longitude`), resolviendo el destino por nombre o por
`attraction_id` en vez de este diccionario hardcodeado.
"""

DESTINOS_ICA: dict[str, tuple[float, float]] = {
    "huacachina": (-14.0873, -75.7637),
    "islas ballestas": (-13.8167, -76.2833),
    "reserva nacional de paracas": (-13.8333, -76.2500),
    "plaza de armas de ica": (-14.0678, -75.7286),
    "bodega tacama": (-14.0206, -75.7089),
    "cerro blanco": (-14.1333, -75.7333),
}


def normalizar_nombre_destino(destino: str) -> str:
    return destino.strip().lower()
