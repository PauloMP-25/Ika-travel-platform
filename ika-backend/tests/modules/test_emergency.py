"""Tests del módulo `emergency` (SOS, historial y notificaciones)."""

from uuid import UUID, uuid4

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from src.modules.emergency import tasks
from src.modules.emergency.models import (
    NotificationStatus,
    SOSReport,
    SOSStatus,
)

API = "/api/v1"


def _sign_up(client: TestClient, email: str) -> dict:
    response = client.post(
        f"{API}/auth/register",
        json={
            "email": email,
            "password": "secreto123",
            "full_name": "Viajero Ica",
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


def _create_sos(client: TestClient, headers: dict, **overrides) -> dict:
    payload = {
        "latitude": -14.089,
        "longitude": -75.697,
        "description": "Caída en dunas",
        **overrides,
    }
    return client.post(f"{API}/emergency/sos", json=payload, headers=headers)


def test_create_sos_without_token_returns_401(client: TestClient) -> None:
    response = client.post(
        f"{API}/emergency/sos", json={"latitude": -14.0, "longitude": -75.0}
    )

    assert response.status_code == 401


def test_create_sos_without_gps_returns_400(
    client: TestClient,
) -> None:
    """RN-04: sin coordenadas no se abre el incidente."""
    _sign_up(client, "sin-gps@ika.pe")
    headers = _headers(client, "sin-gps@ika.pe")

    response = _create_sos(
        client, headers, latitude=None, longitude=None
    )

    assert response.status_code == 400
    assert "coordenadas" in response.json()["detail"].lower()


def test_create_sos_with_invalid_latitude_returns_400(
    client: TestClient,
) -> None:
    _sign_up(client, "lat-mala@ika.pe")
    headers = _headers(client, "lat-mala@ika.pe")

    response = _create_sos(client, headers, latitude=999.0)

    assert response.status_code == 400


def test_create_sos_returns_201_with_pending_status(
    client: TestClient,
) -> None:
    _sign_up(client, "sos@ika.pe")
    headers = _headers(client, "sos@ika.pe")

    response = _create_sos(client, headers)

    assert response.status_code == 201
    body = response.json()
    assert body["status"] == SOSStatus.PENDING.value


def test_create_sos_queues_notifications(
    client: TestClient, db_session: Session
) -> None:
    _sign_up(client, "cola@ika.pe")
    headers = _headers(client, "cola@ika.pe")

    report_id = _create_sos(client, headers).json()["id"]

    report = db_session.get(SOSReport, UUID(report_id))
    assert report is not None
    # push + email siempre; sms solo si el usuario tiene teléfono
    assert len(report.notifications) == 2
    assert all(
        notification.status == NotificationStatus.QUEUED
        for notification in report.notifications
    )


def test_incidents_history_only_shows_own_reports(
    client: TestClient,
) -> None:
    _sign_up(client, "uno@ika.pe")
    _sign_up(client, "dos@ika.pe")
    headers_a = _headers(client, "uno@ika.pe")
    headers_b = _headers(client, "dos@ika.pe")

    _create_sos(client, headers_a)
    _create_sos(client, headers_b)

    response_a = client.get(f"{API}/emergency/incidents", headers=headers_a)
    response_b = client.get(f"{API}/emergency/incidents", headers=headers_b)

    assert response_a.status_code == 200
    assert len(response_a.json()) == 1
    assert len(response_b.json()) == 1
    assert response_a.json()[0]["id"] != response_b.json()[0]["id"]


def test_status_of_someone_elses_report_returns_403(
    client: TestClient,
) -> None:
    _sign_up(client, "propietario@ika.pe")
    _sign_up(client, "curioso@ika.pe")
    headers_owner = _headers(client, "propietario@ika.pe")
    headers_other = _headers(client, "curioso@ika.pe")

    report_id = _create_sos(client, headers_owner).json()["id"]

    response = client.get(
        f"{API}/emergency/sos/{report_id}/status", headers=headers_other
    )

    assert response.status_code == 403


def test_status_of_missing_report_returns_404(client: TestClient) -> None:
    _sign_up(client, "nadie@ika.pe")
    headers = _headers(client, "nadie@ika.pe")

    response = client.get(
        f"{API}/emergency/sos/{uuid4()}/status", headers=headers
    )

    assert response.status_code == 404


def test_task_marks_notifications_failed_without_provider(
    client: TestClient, db_session: Session
) -> None:
    """Sin proveedor configurado el fallo queda registrado, no silencioso."""
    _sign_up(client, "falla@ika.pe")
    headers = _headers(client, "falla@ika.pe")
    report_id = UUID(_create_sos(client, headers).json()["id"])

    sent = tasks.process_sos_notifications(report_id, db_session)

    assert sent == 0
    report = db_session.get(SOSReport, report_id)
    assert all(
        notification.status == NotificationStatus.FAILED
        for notification in report.notifications
    )


def test_task_marks_notifications_sent_when_provider_succeeds(
    client: TestClient,
    db_session: Session,
    monkeypatch,
) -> None:
    _sign_up(client, "exito@ika.pe")
    headers = _headers(client, "exito@ika.pe")
    report_id = UUID(_create_sos(client, headers).json()["id"])
    monkeypatch.setattr(tasks, "send_notification", lambda *args, **kwargs: True)

    sent = tasks.process_sos_notifications(report_id, db_session)

    assert sent == 2
    report = db_session.get(SOSReport, report_id)
    assert all(
        notification.status == NotificationStatus.SENT
        and notification.sent_at is not None
        for notification in report.notifications
    )
