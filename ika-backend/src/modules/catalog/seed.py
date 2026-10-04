"""Datos semilla para desarrollo local. Es idempotente (se puede ejecutar varias veces).

Uso (desde la carpeta ika-backend):
    python -m src.modules.catalog.seed

IMPORTANTE: datos de ejemplo. Coordenadas referenciales (verificar antes de producción),
imágenes de relleno, RUC ficticios y agencia "Demo" para probar la regla RN-01.
"""
import asyncio
from decimal import Decimal

from sqlalchemy import select

from src.core.database import SesionAsincronaLocal, motor
from src.modules.catalog.models import Agency, Attraction, AttractionImage, Category, Tour
from src.shared.utils import utc_ahora

CATEGORIAS = [
    ("Sandboarding", "sandboarding"),
    ("Aventura", "aventura"),
    ("Cultural", "cultural"),
    ("Gastronomía y vino", "gastronomia"),
    ("Naturaleza", "naturaleza"),
]

# nombre, descripción, lat, lon, distrito, recomendación oficial, categorías
ATRACTIVOS = [
    (
        "Oasis de Huacachina",
        "Laguna natural rodeada de dunas, punto de partida de paseos en buggy y sandboarding.",
        -14.0875, -75.7631, "Ica",
        "Lleva protector solar, lentes y evita el mediodía en temporada de verano.",
        ["sandboarding", "aventura", "naturaleza"],
    ),
    (
        "Pueblo de Cachiche",
        "Pueblo tradicional conocido por sus leyendas, artesanía y el árbol de la Huaringa.",
        -14.0290, -75.7440, "Ica",
        "Visita en horas de la mañana para recorrer con menos calor.",
        ["cultural"],
    ),
    (
        "Plaza de Armas de Ica",
        "Centro histórico de la ciudad, rodeado de la catedral y edificios coloniales.",
        -14.0678, -75.7286, "Ica",
        None,
        ["cultural"],
    ),
    (
        "Bodegas de Subtanjalla",
        "Zona vitivinícola con bodegas tradicionales, degustación de pisco y vino.",
        -14.0210, -75.7570, "Subtanjalla",
        "Consume alcohol con responsabilidad y reserva el transporte de regreso.",
        ["gastronomia", "cultural"],
    ),
    (
        "Cañón de los Perdidos",
        "Formaciones desérticas y paisajes de gran valor geológico, de acceso en 4x4.",
        -14.3300, -75.5800, "Ocucaje",
        "Ir con agencia formal: la cobertura de red es limitada. Lleva agua suficiente.",
        ["aventura", "naturaleza"],
    ),
]

# nombre, ruc, validada, registro, teléfono, email
AGENCIAS = [
    ("Ika Travel and Experience (DEMO)", "20000000001", True, "DEMO-0001", "+51 900 000 001", "demo@ika.example"),
    ("Agencia Informal (DEMO - no validada)", "20000000002", False, None, "+51 900 000 002", None),
]

# agencia_ruc, atractivo, nombre, descripción, precio, horas
TOURS = [
    ("20000000001", "Oasis de Huacachina", "Tubulares y Sandboarding en Huacachina",
     "Paseo en buggy por las dunas con práctica de sandboarding.", "60.00", 3),
    ("20000000001", "Pueblo de Cachiche", "City Tour Ica + Cachiche",
     "Recorrido cultural por el centro de Ica y el pueblo de Cachiche.", "45.00", 4),
    ("20000000001", "Cañón de los Perdidos", "Expedición Cañón de los Perdidos",
     "Excursión 4x4 con guía certificado.", "180.00", 8),
    ("20000000002", "Oasis de Huacachina", "Tour no validado (no debe mostrarse)",
     "Sirve para comprobar la regla RN-01.", "10.00", 1),
]


async def ejecutar() -> None:
    async with SesionAsincronaLocal() as db:
        categorias: dict[str, Category] = {}
        for nombre, slug in CATEGORIAS:
            cat = (await db.execute(select(Category).where(Category.slug == slug))).scalar_one_or_none()
            if cat is None:
                cat = Category(name=nombre, slug=slug)
                db.add(cat)
            categorias[slug] = cat
        await db.flush()

        atractivos: dict[str, Attraction] = {}
        for nombre, desc, lat, lon, distrito, reco, slugs in ATRACTIVOS:
            atr = (await db.execute(select(Attraction).where(Attraction.name == nombre))).scalar_one_or_none()
            if atr is None:
                texto_img = nombre.replace(" ", "+")
                atr = Attraction(
                    name=nombre, description=desc, latitude=lat, longitude=lon,
                    district=distrito, official_recommendation=reco,
                    categories=[categorias[s] for s in slugs],
                    images=[
                        AttractionImage(url=f"https://placehold.co/800x600?text={texto_img}+{n}", display_order=n)
                        for n in range(3)
                    ],
                )
                db.add(atr)
            atractivos[nombre] = atr
        await db.flush()

        agencias: dict[str, Agency] = {}
        for nombre, ruc, validada, registro, tel, email in AGENCIAS:
            ag = (await db.execute(select(Agency).where(Agency.ruc == ruc))).scalar_one_or_none()
            if ag is None:
                ag = Agency(
                    name=nombre, ruc=ruc, is_validated=validada,
                    dircetur_registry_number=registro,
                    validated_at=utc_ahora() if validada else None,
                    contact_phone=tel, contact_email=email,
                )
                db.add(ag)
            agencias[ruc] = ag
        await db.flush()

        for ruc, atr_nombre, nombre, desc, precio, horas in TOURS:
            existe = (await db.execute(select(Tour).where(Tour.name == nombre))).scalar_one_or_none()
            if existe is None:
                db.add(Tour(
                    agency_id=agencias[ruc].id, attraction_id=atractivos[atr_nombre].id,
                    name=nombre, description=desc, price=Decimal(precio), duration_hours=horas,
                ))
        await db.commit()
    await motor.dispose()
    print("Datos semilla de catálogo cargados correctamente.")


if __name__ == "__main__":
    asyncio.run(ejecutar())
