import asyncio
from uuid import uuid4
from sqlalchemy import select, insert
from src.core.database import SesionAsincronaLocal, motor
from src.modules.catalog.models import Attraction, Category, AttractionImage, attraction_category

PLAYAS_Y_DESTINOS = [
    (
        "Playa La Mina",
        "Hermosa playa de aguas calmas y color turquesa ubicada dentro de la Reserva Nacional de Paracas.",
        -13.9167, -76.3167, "Paracas",
        "Llevar sombrilla, bloqueador solar y agua. Respetar las zonas designadas de baño.",
        ["naturaleza", "aventura", "sol_playa"],
        "assets/images/act_reserva1.jpg"
    ),
    (
        "Playa Roja",
        "Emblemática playa de arena rojiza originada por la erosión de rocas volcánicas en Paracas.",
        -13.8867, -76.2872, "Paracas",
        "Zona protegida: no descender al acantilado ni retirar arena del lugar.",
        ["naturaleza", "cultural", "sol_playa"],
        "assets/images/act_reserva1.jpg"
    ),
    (
        "Playa El Chaco",
        "Principal balneario y muelle turístico de Paracas, punto de embarque a las Islas Ballestas.",
        -13.8322, -76.2483, "Paracas",
        "Revisar alertas de oleaje y viento antes de abordar embarcaciones turísticas.",
        ["aventura", "gastronomia", "naturaleza", "sol_playa"],
        "assets/images/act_ballestas1.jpg"
    ),
    (
        "Playa Hermosa de Marcona",
        "Extensa playa de arenas doradas y brisa marina en la costa sur de Ica.",
        -15.3583, -75.1750, "Marcona",
        "Ideal para caminatas y contemplación de formaciones rocosas al atardecer.",
        ["naturaleza", "sol_playa"],
        "assets/images/act_reserva1.jpg"
    ),
    (
        "Islas Ballestas",
        "Santuario marino que alberga lobos marinos, pingüinos de Humboldt y aves guaneras.",
        -13.8167, -76.2833, "Paracas",
        "Uso obligatorio de chaleco salvavidas en el deslizador turístico.",
        ["naturaleza", "aventura"],
        "assets/images/act_ballestas1.jpg"
    ),
    (
        "Reserva Nacional de Paracas",
        "Área natural protegida que combina desierto costero y rica biodiversidad marina.",
        -13.8333, -76.2500, "Paracas",
        "Ingreso con ticket SERNANP. No arrojar residuos en el desierto.",
        ["naturaleza", "aventura"],
        "assets/images/act_reserva1.jpg"
    ),
    (
        "Bodega Tacama",
        "El viñedo más antiguo de Sudamérica con paseos guiados, catas y shows de caballos de paso.",
        -14.0206, -75.7089, "Ica",
        "Visitas recomendadas de 10:00 AM a 04:00 PM bajo sombra arbolada.",
        ["gastronomia", "cultural"],
        "assets/images/act_vinos.jpg"
    ),
]

async def seed_playas():
    async with SesionAsincronaLocal() as db:
        # Asegurar categoría Sol y Playa
        res_cat = await db.execute(select(Category).where(Category.slug == "sol_playa"))
        cat_playa = res_cat.scalar_one_or_none()
        if not cat_playa:
            cat_playa = Category(id=uuid4(), name="Sol y Playa", slug="sol_playa")
            db.add(cat_playa)
            await db.commit()

        # Obtener todas las categorías
        todas_cats = (await db.execute(select(Category))).scalars().all()
        cat_map = {c.slug: c.id for c in todas_cats}

        for nombre, desc, lat, lon, dist, rec, slugs, img in PLAYAS_Y_DESTINOS:
            q = await db.execute(select(Attraction).where(Attraction.name == nombre))
            existente = q.scalar_one_or_none()
            if not existente:
                new_id = uuid4()
                attr = Attraction(
                    id=new_id,
                    name=nombre,
                    description=desc,
                    latitude=lat,
                    longitude=lon,
                    district=dist,
                    official_recommendation=rec,
                    is_active=True,
                )
                db.add(attr)
                await db.flush()

                # Insertar en tabla asociativa attraction_category directamente
                for s in slugs:
                    if s in cat_map:
                        await db.execute(
                            insert(attraction_category).values(
                                attraction_id=new_id,
                                category_id=cat_map[s]
                            )
                        )

                # Asociar imagen
                img_obj = AttractionImage(
                    id=uuid4(),
                    attraction_id=new_id,
                    url=img,
                    display_order=0
                )
                db.add(img_obj)
                print(f"+ Agregado: {nombre}")

        await db.commit()
        print("Playas y destinos costeros de Ica cargados exitosamente.")

if __name__ == "__main__":
    asyncio.run(seed_playas())
