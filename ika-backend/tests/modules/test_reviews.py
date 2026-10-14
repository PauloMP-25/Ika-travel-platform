"""Tests exhaustivos del módulo `reviews` (Reseñas, Fotos con Strategy y Favoritos)."""

import io
from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.modules.catalog.models import Attraction
from src.modules.reviews.models import Favorite, Review
from src.modules.reviews.storage import MockStorageStrategy, set_storage_strategy
from tests.conftest import run

API = "/api/v1"


@pytest.fixture(autouse=True)
def setup_mock_storage():
    """Usa MockStorageStrategy en los tests para evitar escrituras en disco."""
    mock = MockStorageStrategy()
    set_storage_strategy(mock)
    yield mock


def _sign_up(client: TestClient, email: str) -> dict:
    res = client.post(
        f"{API}/auth/register",
        json={"email": email, "password": "password123", "full_name": "Turista Test"},
    )
    assert res.status_code == 201
    return res.json()


def _headers(client: TestClient, email: str) -> dict[str, str]:
    res = client.post(
        f"{API}/auth/login",
        json={"email": email, "password": "password123"},
    )
    assert res.status_code == 200
    return {"Authorization": f"Bearer {res.json()['access_token']}"}


def _create_attraction(db_session: AsyncSession) -> UUID:
    async def _insert():
        attraction = Attraction(
            name=f"Laguna de Huacachina {uuid4().hex[:6]}",
            description="Oasis natural rodeado de dunas en Ica.",
            latitude=-14.087,
            longitude=-75.763,
            district="Ica",
            official_recommendation="Llevar bloqueador y agua.",
        )
        db_session.add(attraction)
        await db_session.commit()
        await db_session.refresh(attraction)
        return attraction.id

    return run(_insert())


# ============================================================================
# Criterio 1: Validación estricta de Calificación (1 a 5 estrellas)
# ============================================================================

def test_create_review_with_invalid_ratings_returns_422(
    client: TestClient, db_session: AsyncSession
) -> None:
    attraction_id = _create_attraction(db_session)
    email = f"rating_invalido_{uuid4().hex[:6]}@ika.pe"
    _sign_up(client, email)
    headers = _headers(client, email)

    # Menor que 1
    res_zero = client.post(
        f"{API}/catalog/attractions/{attraction_id}/reviews",
        json={"rating": 0, "comment": "Horrible"},
        headers=headers,
    )
    assert res_zero.status_code == 422

    # Mayor que 5
    res_six = client.post(
        f"{API}/catalog/attractions/{attraction_id}/reviews",
        json={"rating": 6, "comment": "Increíble"},
        headers=headers,
    )
    assert res_six.status_code == 422


# ============================================================================
# Criterio 2: Unicidad (1 reseña por usuario por atractivo -> 409 Conflict)
# ============================================================================

def test_duplicate_review_by_same_user_returns_409(
    client: TestClient, db_session: AsyncSession
) -> None:
    attraction_id = _create_attraction(db_session)
    email = f"unico_{uuid4().hex[:6]}@ika.pe"
    _sign_up(client, email)
    headers = _headers(client, email)

    # Primera reseña: 201
    res1 = client.post(
        f"{API}/catalog/attractions/{attraction_id}/reviews",
        json={"rating": 5, "comment": "Hermoso atardecer en el oasis"},
        headers=headers,
    )
    assert res1.status_code == 201
    assert res1.json()["rating"] == 5

    # Segunda reseña para el mismo atractivo: 409 Conflict
    res2 = client.post(
        f"{API}/catalog/attractions/{attraction_id}/reviews",
        json={"rating": 4, "comment": "Intento duplicado"},
        headers=headers,
    )
    assert res2.status_code == 409


# ============================================================================
# Criterio 3: Listado público, Resumen Estadístico y Edición
# ============================================================================

def test_list_reviews_and_summary_calculation(
    client: TestClient, db_session: AsyncSession
) -> None:
    attraction_id = _create_attraction(db_session)

    # Crear 3 usuarios y 3 reseñas (5, 4, 3 estrellas)
    for rating in [5, 4, 3]:
        em = f"user_{rating}_{uuid4().hex[:6]}@ika.pe"
        _sign_up(client, em)
        h = _headers(client, em)
        client.post(
            f"{API}/catalog/attractions/{attraction_id}/reviews",
            json={"rating": rating, "comment": f"Califico con {rating}"},
            headers=h,
        )

    # 1. Consulta pública de lista
    res_list = client.get(f"{API}/catalog/attractions/{attraction_id}/reviews")
    assert res_list.status_code == 200
    reviews = res_list.json()
    assert len(reviews) == 3

    # 2. Resumen estadístico
    res_sum = client.get(f"{API}/catalog/attractions/{attraction_id}/reviews/summary")
    assert res_sum.status_code == 200
    summary = res_sum.json()
    assert summary["total_reviews"] == 3
    assert summary["average_rating"] == 4.0
    assert summary["rating_distribution"]["5"] == 1
    assert summary["rating_distribution"]["4"] == 1
    assert summary["rating_distribution"]["3"] == 1


def test_update_and_delete_permissions(
    client: TestClient, db_session: AsyncSession
) -> None:
    attraction_id = _create_attraction(db_session)
    email_owner = f"dueno_{uuid4().hex[:6]}@ika.pe"
    email_other = f"ajeno_{uuid4().hex[:6]}@ika.pe"

    _sign_up(client, email_owner)
    _sign_up(client, email_other)
    h_owner = _headers(client, email_owner)
    h_other = _headers(client, email_other)

    # Crear review
    res = client.post(
        f"{API}/catalog/attractions/{attraction_id}/reviews",
        json={"rating": 3, "comment": "Regular"},
        headers=h_owner,
    )
    review_id = res.json()["id"]

    # Usuario ajeno intenta editar -> 403
    res_edit_bad = client.put(
        f"{API}/reviews/{review_id}",
        json={"rating": 5},
        headers=h_other,
    )
    assert res_edit_bad.status_code == 403

    # Usuario ajeno intenta borrar -> 403
    res_del_bad = client.delete(f"{API}/reviews/{review_id}", headers=h_other)
    assert res_del_bad.status_code == 403

    # Dueño actualiza con éxito -> 200
    res_edit_ok = client.put(
        f"{API}/reviews/{review_id}",
        json={"rating": 4, "comment": "Mejoró bastante"},
        headers=h_owner,
    )
    assert res_edit_ok.status_code == 200
    assert res_edit_ok.json()["rating"] == 4

    # Dueño borra con éxito -> 204
    res_del_ok = client.delete(f"{API}/reviews/{review_id}", headers=h_owner)
    assert res_del_ok.status_code == 204


# ============================================================================
# Criterio 4: Subida de fotos con Patrón Strategy y validación de tipos
# ============================================================================

def test_upload_review_image_strategy(
    client: TestClient, db_session: AsyncSession
) -> None:
    attraction_id = _create_attraction(db_session)
    email = f"fotografo_{uuid4().hex[:6]}@ika.pe"
    _sign_up(client, email)
    headers = _headers(client, email)

    review_res = client.post(
        f"{API}/catalog/attractions/{attraction_id}/reviews",
        json={"rating": 5, "comment": "Con fotos espectaculares"},
        headers=headers,
    )
    review_id = review_res.json()["id"]

    # Subir imagen válida (JPEG)
    fake_img = io.BytesIO(b"\xff\xd8\xff\xe0" + b"0" * 1024)
    upload_res = client.post(
        f"{API}/reviews/{review_id}/images",
        files={"file": ("atardecer.jpg", fake_img, "image/jpeg")},
        headers=headers,
    )
    assert upload_res.status_code == 201
    img_data = upload_res.json()
    assert "/mock/media/" in img_data["image_url"]

    # Subir archivo no permitido (ej. PDF) -> 400
    bad_file = io.BytesIO(b"%PDF-1.4")
    upload_bad = client.post(
        f"{API}/reviews/{review_id}/images",
        files={"file": ("documento.pdf", bad_file, "application/pdf")},
        headers=headers,
    )
    assert upload_bad.status_code == 400


# ============================================================================
# Criterio 5: Toggle y listado de Favoritos (RN-02)
# ============================================================================

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

    # 4. Listar favoritos del usuario
    list_fav = client.get(f"{API}/users/me/favorites", headers=headers)
    assert list_fav.status_code == 200
    favs = list_fav.json()
    assert len(favs) == 1
    assert favs[0]["attraction_id"] == str(attraction_id)

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
