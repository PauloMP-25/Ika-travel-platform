"""Tests del módulo `reviews` (reseñas, fotos, favoritos y rating del catálogo).

Cubre los criterios de aceptación del Sprint 2:
- rating 0 o 6 → HTTP 422.
- segunda reseña en el mismo lugar → HTTP 409.
- borrar reseña de otro usuario → HTTP 403.
- `toggle_favorite` dos veces → crea y luego borra.
- subir un PDF o una imagen > 5 MB → HTTP 422.
"""

from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.config import configuracion
from src.modules.catalog.models import Attraction
from src.modules.reviews.models import Favorite, Review
from tests.conftest import run

API = "/api/v1"


@pytest.fixture(autouse=True)
def _uploads_en_tmp(tmp_path, monkeypatch) -> None:
    """Las fotos del test van a un tmp dir, no a `./uploads` del repo."""
    monkeypatch.setattr(configuracion, "UPLOADS_DIR", str(tmp_path / "uploads"))


def _sign_up(client: TestClient, email: str) -> dict:
    response = client.post(
        f"{API}/auth/register",
        json={
            "email": email,
            "password": "secreto123",
            "full_name": "Turista Ica",
        },
    )
    assert response.status_code == 201
    return response.json()


def _headers(client: TestClient, email: str) -> dict[str, str]:
    response = client.post(
        f"{API}/auth/login",
        json={"email": email, "password": "secreto123"},
    )
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


async def _create_attraction(db: AsyncSession) -> UUID:
    """Inserta un atractivo directamente (sin depender del endpoint admin)."""
    attraction = Attraction(
        name="Huacachina",
        description="Oasis en el desierto",
        latitude=-14.089,
        longitude=-75.697,
        district="Ica",
    )
    db.add(attraction)
    await db.commit()
    await db.refresh(attraction)
    return attraction.id


def _create_review(
    client: TestClient,
    headers: dict,
    attraction_id: UUID,
    rating: int = 5,
    comment: str = "Excelente",
    images: list | None = None,
):
    data = {
        "attraction_id": str(attraction_id),
        "rating": str(rating),
        "comment": comment,
    }
    files = None
    if images is not None:
        files = [("images", (name, payload, content_type)) for name, payload, content_type in images]
    return client.post(
        f"{API}/reviews", data=data, files=files or [], headers=headers
    )


def _png_bytes(size: int = 100) -> bytes:
    """Payload arbitrario con content-type image/png (la validación es por MIME)."""
    return b"\x89PNG" + b"\x00" * size


# ======================================================================
# Autenticación y validación de entrada
# ======================================================================
def test_create_review_without_token_returns_401(client: TestClient) -> None:
    response = client.post(
        f"{API}/reviews",
        data={"attraction_id": str(uuid4()), "rating": "5"},
    )

    assert response.status_code == 401


def test_create_review_with_invalid_rating_returns_422(
    client: TestClient, db_session: AsyncSession
) -> None:
    """Rating 0 o 6 es rechazado por Pydantic (422)."""
    _sign_up(client, "rating-malo@ika.pe")
    headers = _headers(client, "rating-malo@ika.pe")
    attraction_id = run(_create_attraction(db_session))

    for rating in ("0", "6"):
        response = _create_review(client, headers, attraction_id, rating=int(rating))
        assert response.status_code == 422


def test_create_review_for_missing_attraction_returns_404(
    client: TestClient,
) -> None:
    _sign_up(client, "sin-lugar@ika.pe")
    headers = _headers(client, "sin-lugar@ika.pe")

    response = _create_review(client, headers, uuid4())

    assert response.status_code == 404


# ======================================================================
# Creación y unicidad
# ======================================================================
def test_create_review_returns_201_without_sensitive_data(
    client: TestClient, db_session: AsyncSession
) -> None:
    """El DTO jamás expone email ni hash de la contraseña del autor."""
    _sign_up(client, "autora@ika.pe")
    headers = _headers(client, "autora@ika.pe")
    attraction_id = run(_create_attraction(db_session))

    response = _create_review(
        client,
        headers,
        attraction_id,
        images=[("dunas.png", _png_bytes(), "image/png")],
    )

    assert response.status_code == 201
    body = response.json()
    assert body["rating"] == 5
    assert body["user_name"] == "Turista Ica"
    assert len(body["images"]) == 1
    assert body["images"][0].startswith("/static/uploads/reviews/")
    assert "email" not in body
    assert "password_hash" not in body


def test_second_review_for_same_attraction_returns_409(
    client: TestClient, db_session: AsyncSession
) -> None:
    _sign_up(client, "duplicada@ika.pe")
    headers = _headers(client, "duplicada@ika.pe")
    attraction_id = run(_create_attraction(db_session))

    first = _create_review(client, headers, attraction_id)
    second = _create_review(client, headers, attraction_id)

    assert first.status_code == 201
    assert second.status_code == 409


# ======================================================================
# Eliminación
# ======================================================================
def test_delete_review_by_non_owner_returns_403(
    client: TestClient, db_session: AsyncSession
) -> None:
    _sign_up(client, "dueña@ika.pe")
    _sign_up(client, "intrusa@ika.pe")
    headers_owner = _headers(client, "dueña@ika.pe")
    headers_other = _headers(client, "intrusa@ika.pe")
    attraction_id = run(_create_attraction(db_session))

    review_id = _create_review(client, headers_owner, attraction_id).json()["id"]

    response = client.delete(f"{API}/reviews/{review_id}", headers=headers_other)

    assert response.status_code == 403


def test_delete_own_review_returns_204(
    client: TestClient, db_session: AsyncSession
) -> None:
    _sign_up(client, "borradora@ika.pe")
    headers = _headers(client, "borradora@ika.pe")
    attraction_id = run(_create_attraction(db_session))

    review_id = _create_review(client, headers, attraction_id).json()["id"]
    response = client.delete(f"{API}/reviews/{review_id}", headers=headers)

    assert response.status_code == 204
    assert run(_count_reviews(db_session)) == 0


def test_delete_missing_review_returns_404(
    client: TestClient,
) -> None:
    _sign_up(client, "fantasma@ika.pe")
    headers = _headers(client, "fantasma@ika.pe")

    response = client.delete(f"{API}/reviews/{uuid4()}", headers=headers)

    assert response.status_code == 404


async def _count_reviews(db: AsyncSession) -> int:
    from sqlalchemy import func

    return int(await db.scalar(select(func.count()).select_from(Review)) or 0)


# ======================================================================
# Subida de archivos (Strategy + validación)
# ======================================================================
def test_upload_pdf_returns_422(
    client: TestClient, db_session: AsyncSession
) -> None:
    """Solo se aceptan imágenes JPEG/PNG (MIME type)."""
    _sign_up(client, "pdf@ika.pe")
    headers = _headers(client, "pdf@ika.pe")
    attraction_id = run(_create_attraction(db_session))

    response = _create_review(
        client,
        headers,
        attraction_id,
        images=[("informe.pdf", b"%PDF-1.4", "application/pdf")],
    )

    assert response.status_code == 422


def test_upload_image_bigger_than_5mb_returns_422(
    client: TestClient, db_session: AsyncSession, monkeypatch
) -> None:
    """Respeta `MAX_UPLOAD_MB` (5 MB por defecto)."""
    _sign_up(client, "gigante@ika.pe")
    headers = _headers(client, "gigante@ika.pe")
    attraction_id = run(_create_attraction(db_session))
    # El límite se fija en 1 MB para probar la regla sin transferir 5 MB
    # por la red en cada ejecución.
    monkeypatch.setattr(configuracion, "MAX_UPLOAD_MB", 1)

    huge = _png_bytes(size=2 * 1024 * 1024)  # 2 MB
    response = _create_review(
        client,
        headers,
        attraction_id,
        images=[("enorme.png", huge, "image/png")],
    )

    assert response.status_code == 422


# ======================================================================
# Favoritos
# ======================================================================
def test_toggle_favorite_creates_then_removes(
    client: TestClient, db_session: AsyncSession
) -> None:
    """Dos toggles seguidos: el primero crea, el segundo borra."""
    _sign_up(client, "favorita@ika.pe")
    headers = _headers(client, "favorita@ika.pe")
    attraction_id = run(_create_attraction(db_session))
    url = f"{API}/reviews/favorites/{attraction_id}"

    first = client.post(url, headers=headers)
    second = client.post(url, headers=headers)

    assert first.status_code == 200
    assert first.json()["is_favorite"] is True
    assert second.status_code == 200
    assert second.json()["is_favorite"] is False
    assert run(_count_favorites(db_session)) == 0


def test_list_favorites_returns_saved_attraction(
    client: TestClient, db_session: AsyncSession
) -> None:
    _sign_up(client, "lista@ika.pe")
    headers = _headers(client, "lista@ika.pe")
    attraction_id = run(_create_attraction(db_session))

    client.post(f"{API}/reviews/favorites/{attraction_id}", headers=headers)
    response = client.get(f"{API}/reviews/favorites", headers=headers)

    assert response.status_code == 200
    items = response.json()
    assert len(items) == 1
    assert items[0]["attraction_name"] == "Huacachina"
    assert items[0]["cover_image_url"] is None


async def _count_favorites(db: AsyncSession) -> int:
    from sqlalchemy import func

    return int(await db.scalar(select(func.count()).select_from(Favorite)) or 0)


# ======================================================================
# Integración con el catálogo (tarea 5 del sprint)
# ======================================================================
def test_catalog_detail_uses_real_average_rating(
    client: TestClient, db_session: AsyncSession
) -> None:
    """`get_attraction_detail` muestra el rating calculado, no None."""
    _sign_up(client, "catalogo@ika.pe")
    headers = _headers(client, "catalogo@ika.pe")
    attraction_id = run(_create_attraction(db_session))

    _create_review(client, headers, attraction_id, rating=4)
    response = client.get(f"{API}/catalog/attractions/{attraction_id}")

    assert response.status_code == 200
    assert response.json()["avg_rating"] == 4.0


def test_list_attraction_reviews_returns_newest_first(
    client: TestClient, db_session: AsyncSession
) -> None:
    _sign_up(client, "una@ika.pe")
    _sign_up(client, "dos@ika.pe")
    attraction_id = run(_create_attraction(db_session))

    _create_review(client, _headers(client, "una@ika.pe"), attraction_id, rating=3)
    _create_review(client, _headers(client, "dos@ika.pe"), attraction_id, rating=5)

    response = client.get(
        f"{API}/reviews/attractions/{attraction_id}",
        headers=_headers(client, "una@ika.pe"),
    )

    assert response.status_code == 200
    assert [r["rating"] for r in response.json()] == [5, 3]
