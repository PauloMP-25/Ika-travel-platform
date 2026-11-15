"""Datos semilla oficiales para el catalogo de agencias, atractivos y tours de Ica.
Es idempotente (se puede ejecutar varias veces sin duplicar registros).
"""
import asyncio
from decimal import Decimal
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.orm import selectinload

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
        -14.087265, -75.763105, "Ica",
        "Lleva protector solar, lentes y evita el mediodía en temporada de verano.",
        ["sandboarding", "aventura", "naturaleza"],
    ),
    (
        "Palmera de las 7 Cabezas (Cachiche)",
        "Lugar tradicional conocido por la enigmática Palmera de las 7 Cabezas, sus leyendas místicas y la brujería de Cachiche.",
        -14.094789, -75.735570, "Ica",
        "Visita en horas de la mañana para recorrer con menos calor.",
        ["cultural"],
    ),
    (
        "Plaza de Armas de Ica",
        "Centro histórico de la ciudad, rodeado de la catedral y edificios coloniales.",
        -14.063804, -75.728825, "Ica",
        None,
        ["cultural"],
    ),
    (
        "Viña Tacama",
        "La viña y bodega más antigua de Sudamérica, cuna de vinos y piscos de prestigio internacional.",
        -14.000958, -75.716955, "Ica",
        "Reserva tu recorrido con anticipación y disfruta de la cata dirigida.",
        ["gastronomia", "cultural"],
    ),
    (
        "Bodega y Viñedos Sotelo (Subtanjalla)",
        "Tradicional viñedo y bodega pisquera artesanal de Subtanjalla, cuna de vinos y piscos de alta calidad.",
        -14.002123, -75.739003, "Subtanjalla",
        "Consume alcohol con responsabilidad y reserva el transporte de regreso.",
        ["gastronomia", "cultural"],
    ),
    (
        "Bodega Tres Generaciones (Subtanjalla)",
        "Bodega tradicional pisquera artesanal con más de un siglo de tradición en la elaboración de pisco puro y acholado.",
        -14.009363, -75.754251, "Subtanjalla",
        "Ideal para recorridos enoturísticos y maridajes con postres típicos.",
        ["gastronomia", "cultural"],
    ),
    (
        "Cañón de los Perdidos",
        "Formaciones desérticas y paisajes de gran valor geológico, de acceso en 4x4.",
        -14.737226, -75.509457, "Ocucaje",
        "Ir con agencia formal: la cobertura de red es limitada. Lleva agua suficiente.",
        ["aventura", "naturaleza"],
    ),
    (
        "Islas Ballestas",
        "Conjunto de islas rocosas habitadas por lobos marinos, pingüinos de Humboldt y millones de aves guaneras.",
        -13.735943, -76.394191, "Paracas",
        "Embarque en deslizadores autorizados con chaleco salvavidas obligatorio.",
        ["naturaleza", "aventura"],
    ),
    (
        "Reserva Nacional de Paracas",
        "Área protegida costera con impresionantes paisajes desérticos y playas vírgenes.",
        -13.911640, -76.318399, "Paracas",
        "Respeta los senderos señalizados y no dejes residuos en la reserva.",
        ["naturaleza"],
    ),
    (
        "Playa Roja",
        "Singular playa de arena roja volcánica rodeada de acantilados desérticos en Paracas.",
        -13.886700, -76.287200, "Paracas",
        "Acceso exclusivamente peatonal en miradores para preservar el ecosistema.",
        ["naturaleza"],
    ),
    (
        "Playa La Mina",
        "Bahía de aguas calmas y cristalinas protegida por cerros desérticos, ideal para el baño.",
        -13.911591, -76.318357, "Paracas",
        "Lleva protector solar y sombrilla; el sol es intenso todo el año.",
        ["naturaleza"],
    ),
    (
        "Playa Hermosa de Marcona",
        "Hermosa playa y costa virgen de la ensenada de Marcona, rica en biodiversidad marina.",
        -15.358300, -75.175000, "Marcona",
        "Excelente punto para observación de fauna marina y fotografía.",
        ["naturaleza"],
    ),
]

# nombre, ruc, validada, registro, teléfono, email
DURACIONES_ATRACTIVOS: dict[str, int] = {
    "Oasis de Huacachina": 180,
    "Palmera de las 7 Cabezas (Cachiche)": 60,
    "Plaza de Armas de Ica": 45,
    "Viña Tacama": 150,
    "Bodega y Viñedos Sotelo (Subtanjalla)": 90,
    "Bodega Tres Generaciones (Subtanjalla)": 90,
    "Cañón de los Perdidos": 300,
    "Islas Ballestas": 120,
    "Reserva Nacional de Paracas": 240,
    "Playa Roja": 60,
    "Playa La Mina": 180,
    "Playa Hermosa de Marcona": 150,
}

CDN_BASE = "https://raw.githubusercontent.com/PauloMP-25/Ika-travel-platform/main/imagenes_lugares_turisticos"

FOTOS_ATRACTIVOS: dict[str, list[str]] = {
    "Oasis de Huacachina": [
        f"{CDN_BASE}/carrusel_1_huacachina.jpg",
        f"{CDN_BASE}/detalle_sandboarding_1.jpg",
        f"{CDN_BASE}/detalle_sandboarding_2.jpg",
    ],
    "Palmera de las 7 Cabezas (Cachiche)": [
        f"{CDN_BASE}/Cachiche_1.jpg",
        f"{CDN_BASE}/detalle_buggy_2.jpg",
        f"{CDN_BASE}/Cachiche_2.jpg",
    ],
    "Plaza de Armas de Ica": [
        f"{CDN_BASE}/carrusel_3_sandboarding.jpg",
        f"{CDN_BASE}/carrusel_2_vinos.jpg",
        f"{CDN_BASE}/Señor_L_1.jpg",
    ],
    "Viña Tacama": [
        f"{CDN_BASE}/act_vinos.jpg",
        f"{CDN_BASE}/detalle_vinos_2.jpg",
        f"{CDN_BASE}/detalle_vinos_3.jpg",
    ],
    "Bodega y Viñedos Sotelo (Subtanjalla)": [
        f"{CDN_BASE}/detalle_vinos_2.jpg",
        f"{CDN_BASE}/Viñedo_piscos_artesanales_1.jpg",
        f"{CDN_BASE}/act_vinos.jpg",
    ],
    "Bodega Tres Generaciones (Subtanjalla)": [
        f"{CDN_BASE}/detalle_vinos_3.jpg",
        f"{CDN_BASE}/Viñedo_piscos_artesanales_2.jpg",
        f"{CDN_BASE}/act_vinos.jpg",
    ],
    "Cañón de los Perdidos": [
        f"{CDN_BASE}/act_buggy1.jpg",
        f"{CDN_BASE}/Ca%C3%B1on_1.jpg",
        f"{CDN_BASE}/detalle_buggy_3.jpg",
    ],
    "Islas Ballestas": [
        f"{CDN_BASE}/act_ballestas1.jpg",
        f"{CDN_BASE}/detalle_ballestas_2.jpg",
        f"{CDN_BASE}/detalle_ballestas_3.jpg",
    ],
    "Reserva Nacional de Paracas": [
        f"{CDN_BASE}/act_reserva1.jpg",
        f"{CDN_BASE}/detalle_reserva_2.jpg",
        f"{CDN_BASE}/detalle_reserva_3.jpg",
    ],
    "Playa Roja": [
        f"{CDN_BASE}/detalle_reserva_2.jpg",
        f"{CDN_BASE}/act_reserva1.jpg",
        f"{CDN_BASE}/detalle_reserva_3.jpg",
    ],
    "Playa La Mina": [
        f"{CDN_BASE}/detalle_reserva_3.jpg",
        f"{CDN_BASE}/act_reserva1.jpg",
        f"{CDN_BASE}/detalle_reserva_2.jpg",
    ],
    "Playa Hermosa de Marcona": [
        f"{CDN_BASE}/act_reserva1.jpg",
        f"{CDN_BASE}/detalle_reserva_2.jpg",
        f"{CDN_BASE}/detalle_reserva_3.jpg",
    ],
}

AGENCIAS = [
    ("Ika Travel and Experience", "20608912345", True, "DIR-ICA-0010", "+51 956 789 000", "contacto@ikatravel.pe"),
    ("Oro Travel Peru S.A.C.", "20600883446", True, "DIR-ICA-0104", "+51 956 789 123", "contacto@orotravelperu.com"),
    ("Paracas Sight & Tours S.A.C.", "20494562716", True, "DIR-ICA-0188", "+51 956 112 233", "reservas@paracassighttours.com"),
    ("Ica Trip Agency S.A.C.", "20600495519", True, "DIR-ICA-0215", "+51 956 445 566", "informes@icatrip.pe"),
    ("Inversiones Turísticas Ica S.A.C.", "20601775540", True, "DIR-ICA-0290", "+51 956 778 899", "tours@invturisticaica.pe"),
    ("Turismo Ica Peru E.I.R.L.", "20604989958", True, "DIR-ICA-0312", "+51 956 990 011", "operaciones@turismoicaperu.com"),
    ("Ica Aventura Tours Express E.I.R.L.", "20609998811", False, None, "+51 956 001 122", "informes@icaaventuraexpress.pe"),
]

# agencia_ruc, atractivo_nombre, nombre_tour, descripción, precio, horas
TOURS = [
    # Ika Travel and Experience
    ("20608912345", "Oasis de Huacachina", "Tubulares y Sandboarding en Huacachina",
     "Paseo de adrenalina en buggy por las dunas del oasis con práctica guiada de sandboarding y atardecer fotográfico.", "60.00", 3),
    ("20608912345", "Cañón de los Perdidos", "Expedición Cañón de los Perdidos 4x4",
     "Excursión 4x4 por el desierto de Ocucaje con guía turístico certificado, hidratación y equipo de primeros auxilios.", "180.00", 8),
    ("20608912345", "Palmera de las 7 Cabezas (Cachiche)", "Tour Místico Palmera de 7 Cabezas y Cachiche",
     "Recorrido cultural y místico por la Palmera de las 7 Cabezas, brujas de Cachiche y el centro tradicional.", "45.00", 4),

    # Paracas Sight & Tours S.A.C.
    ("20494562716", "Islas Ballestas", "Navegación en Deslizador a Islas Ballestas",
     "Tour marítimo oficial en deslizador con chaleco salvavidas. Avistamiento del Candelabro, lobos marinos y pingüinos.", "50.00", 2),
    ("20494562716", "Reserva Nacional de Paracas", "Circuito Terrestre Reserva Nacional de Paracas",
     "Visita panorámica a los miradores de la Catedral, Playa Roja, istmo y tiempo de relajo en Playa La Mina.", "45.00", 4),

    # Oro Travel Peru S.A.C.
    ("20600883446", "Oasis de Huacachina", "Safari en Dunas & Sandboarding Profesional",
     "Circuito de alta velocidad en areneros homologados por DIRCETUR y tablas profesionales enceradas para dunas.", "55.00", 2),
    ("20600883446", "Cañón de los Perdidos", "Trekking Geológico Cañón de los Perdidos",
     "Caminata por la garganta del cañón, avistamiento de fauna desértica y fósiles de ballenas prehistóricas.", "170.00", 8),

    # Ica Trip Agency S.A.C.
    ("20600495519", "Viña Tacama", "Ruta del Pisco y Vinos: Tacama Tradicional",
     "Visita a los viñedos y bodegas de Tacama, explicación del proceso de destilación y cata de piscos y vinos.", "75.00", 4),
    ("20600495519", "Plaza de Armas de Ica", "City Tour Histórico y Religioso de Ica",
     "Paseo peatonal por el casco histórico de Ica, Santuario del Señor de Luren y museo regional Adolfo Bermúdez.", "35.00", 3),

    # Inversiones Turísticas Ica S.A.C.
    ("20601775540", "Playa La Mina", "Excursión Playera Paracas: El Chaco y La Mina",
     "Transporte privado con aire acondicionado, paseo por el balneario de El Chaco y tarde de sol en Playa La Mina.", "65.00", 5),
    ("20601775540", "Playa Roja", "Ruta Fotográfica Paisajística Playa Roja",
     "Excursión especializada para fotografía en el mirador de arena volcánica roja y acantilados de Paracas.", "55.00", 3),

    # Turismo Ica Peru E.I.R.L.
    ("20604989958", "Bodega Tres Generaciones (Subtanjalla)", "Cata Pisquera Tradicional en Subtanjalla",
     "Visita a las bodegas Tres Generaciones y Sotelo en Subtanjalla, cata de pisco acholado con tejas artesanales.", "60.00", 3),
    ("20604989958", "Playa Hermosa de Marcona", "Expedición Marcona: Playa Hermosa y San Fernando",
     "Aventura en camioneta hacia las bahías vírgenes de Marcona y avistamiento de fauna marina y cóndores.", "135.00", 7),

    # Operador no validado (para demostrar filtro RN-01 en pruebas de fiscalización)
    ("20609998811", "Oasis de Huacachina", "Paseo Informal en Dunas (Sin Seguro ni Registro)",
     "Servicio ofrecido por operador sin autorización formal de DIRCETUR (demostración de filtro RN-01).", "25.00", 1),
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
            atr = (
                await db.execute(
                    select(Attraction)
                    .options(selectinload(Attraction.images))
                    .where(Attraction.name == nombre)
                )
            ).scalar_one_or_none()
            urls_reales = FOTOS_ATRACTIVOS.get(
                nombre,
                [f"{CDN_BASE}/carrusel_1_huacachina.jpg", f"{CDN_BASE}/act_reserva1.jpg"]
            )
            duracion = DURACIONES_ATRACTIVOS.get(nombre, 90)
            if atr is None:
                atr = Attraction(
                    name=nombre, description=desc, latitude=lat, longitude=lon,
                    district=distrito, official_recommendation=reco,
                    visit_duration_minutes=duracion,
                    categories=[categorias[s] for s in slugs],
                    images=[
                        AttractionImage(url=url_foto, display_order=n)
                        for n, url_foto in enumerate(urls_reales)
                    ],
                )
                db.add(atr)
            else:
                atr.visit_duration_minutes = duracion
                # Actualizar imágenes si tenían placehold.co o estaban vacías
                if any("placehold.co" in img.url for img in atr.images) or not atr.images:
                    atr.images.clear()
                    for n, url_foto in enumerate(urls_reales):
                        atr.images.append(AttractionImage(url=url_foto, display_order=n))
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
            if existe is None and atr_nombre in atractivos and ruc in agencias:
                db.add(Tour(
                    agency_id=agencias[ruc].id, attraction_id=atractivos[atr_nombre].id,
                    name=nombre, description=desc, price=Decimal(precio), duration_hours=horas,
                ))
        await db.commit()
    await motor.dispose()
    print("Catalogo oficial y tours de Ica sincronizados exitosamente.")


if __name__ == "__main__":
    asyncio.run(ejecutar())
