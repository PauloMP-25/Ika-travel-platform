"""Tests del módulo `users` (registro, login y perfil protegido)."""

from fastapi.testclient import TestClient

API = "/api/v1"


def _register(client: TestClient, email: str = "viajero@ika.pe", **overrides) -> dict:
    payload = {
        "email": email,
        "password": "secreto123",
        "full_name": "Francisco Ica",
        **overrides,
    }
    return client.post(f"{API}/auth/register", json=payload)


def _login(client: TestClient, email: str, password: str) -> dict:
    response = client.post(
        f"{API}/auth/login", json={"email": email, "password": password}
    )
    return response.json()


def test_register_returns_201_without_password_hash(client: TestClient) -> None:
    response = _register(client)

    assert response.status_code == 201
    body = response.json()
    assert body["email"] == "viajero@ika.pe"
    assert "password_hash" not in body
    assert "password" not in body


def test_register_duplicate_email_returns_409(client: TestClient) -> None:
    assert _register(client).status_code == 201

    response = _register(client)

    assert response.status_code == 409
    assert "email" in response.json()["detail"]


def test_register_short_password_returns_422(client: TestClient) -> None:
    response = _register(client, password="corto")

    assert response.status_code == 422


def test_login_with_wrong_password_returns_401(client: TestClient) -> None:
    _register(client)

    response = client.post(
        f"{API}/auth/login",
        json={"email": "viajero@ika.pe", "password": "contraseñamala"},
    )

    assert response.status_code == 401


def test_login_with_unknown_email_returns_401(client: TestClient) -> None:
    """No se revela si el email existe: mismo 401 genérico."""
    response = client.post(
        f"{API}/auth/login",
        json={"email": "nadie@ika.pe", "password": "secreto123"},
    )

    assert response.status_code == 401


def test_login_success_returns_jwt(client: TestClient) -> None:
    _register(client)

    body = _login(client, "viajero@ika.pe", "secreto123")

    assert body["token_type"] == "bearer"
    assert len(body["access_token"]) > 0
    assert body["expires_in"] > 0


def test_get_me_without_token_returns_401(client: TestClient) -> None:
    response = client.get(f"{API}/users/me")

    assert response.status_code == 401


def test_get_me_with_token_returns_profile(client: TestClient) -> None:
    _register(client)
    token = _login(client, "viajero@ika.pe", "secreto123")["access_token"]

    response = client.get(
        f"{API}/users/me", headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 200
    body = response.json()
    assert body["email"] == "viajero@ika.pe"
    assert body["full_name"] == "Francisco Ica"
    assert "password_hash" not in body


def test_get_me_with_tampered_token_returns_401(client: TestClient) -> None:
    response = client.get(
        f"{API}/users/me", headers={"Authorization": "Bearer token-falso"}
    )

    assert response.status_code == 401


def test_update_profile_returns_updated_user(client: TestClient) -> None:
    _register(client)
    token = _login(client, "viajero@ika.pe", "secreto123")["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    response = client.put(
        f"{API}/users/me", json={"phone": "+51999888777"}, headers=headers
    )

    assert response.status_code == 200
    body = response.json()
    assert body["phone"] == "+51999888777"
    assert body["full_name"] == "Francisco Ica"  # no se tocó
