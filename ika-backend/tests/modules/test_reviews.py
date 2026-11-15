"""Tests para el módulo de Favoritos (RN-02)."""

from uuid import UUID, uuid4

from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession

from src.modules.catalog.models import Attraction
from src.modules.reviews.models import Favorite
from tests.conftest import run

API = "/api/v1"


def _create_attraction(db: AsyncSession) -> UUID:
    """Crea un atractivo de prueba directamente en la base de datos."""
    import datetime as _dt

    attraction = Attraction(
        name=f"Laguna de Huacachina {uuid4().hex[:6]}",
        description="Dunas y oasis en el desierto de Ica.",
        latitude=-14.0873,
        longitude=-75.7637,
        district="Ica",
        visit_duration_minutes=120,
        is_active=True,
        created_at=_dt.datetime.now(_dt.timezone.utc),
        updated_at=_dt.datetime.now(_dt.timezone.utc),
    )
    db.add(attraction)
    run(db.commit())
    return attraction.id


def _sign_up(client: TestClient, email: str, password: str = "Password123!") -> None:
    res = client.post(
        f"{API}/auth/register",
        json={
            "email": email,
            "password": password,
            "full_name": "Turista Test",
        },
    )
    assert res.status_code == 201, res.text


def _headers(client: TestClient, email: str, password: str = "Password123!") -> dict[str, str]:
    res = client.post(
        f"{API}/auth/login",
        json={"email": email, "password": password},
    )
    token = res.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_favorite_toggle_and_list_lifecycle(
    client: TestClient, db_session: AsyncSession
) -> None:
    attraction_id = _create_attraction(db_session)
    email = f"turista_fav_{uuid4().hex[:6]}@ika.pe"
    _sign_up(client, email)
    headers = _headers(client, email)

    # 1. Verificar inicialmente no es favorito
    chk1 = client.get(
        f"{API}/catalog/attractions/{attraction_id}/is-favorite",
        headers=headers,
    )
    assert chk1.status_code == 200
    assert chk1.json() is False

    # 2. Toggle -> Guardar en favoritos
    tgl1 = client.post(
        f"{API}/catalog/attractions/{attraction_id}/favorite",
        headers=headers,
    )
    assert tgl1.status_code == 200
    assert tgl1.json()["is_favorite"] is True

    # 3. Verificar que ahora es favorito
    chk2 = client.get(
        f"{API}/catalog/attractions/{attraction_id}/is-favorite",
        headers=headers,
    )
    assert chk2.status_code == 200
    assert chk2.json() is True

    # 4. Listar favoritos del usuario enriquecidos con datos del atractivo
    list_fav = client.get(f"{API}/users/me/favorites", headers=headers)
    assert list_fav.status_code == 200
    favs = list_fav.json()
    assert len(favs) == 1
    assert favs[0]["attraction_id"] == str(attraction_id)
    assert "name" in favs[0]
    assert "district" in favs[0]
    assert "cover_image_url" in favs[0]
    assert favs[0]["name"].startswith("Laguna de Huacachina")
    assert favs[0]["district"] == "Ica"

    # 5. Toggle de nuevo -> Retirar de favoritos
    tgl2 = client.post(
        f"{API}/catalog/attractions/{attraction_id}/favorite",
        headers=headers,
    )
    assert tgl2.status_code == 200
    assert tgl2.json()["is_favorite"] is False

    # 6. Comprobar que la lista ahora está vacía
    list_fav_empty = client.get(f"{API}/users/me/favorites", headers=headers)
    assert list_fav_empty.status_code == 200
    assert len(list_fav_empty.json()) == 0
