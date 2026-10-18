"""Tests del módulo `emergency` (SOS, historial y notificaciones)."""

from uuid import UUID, uuid4

from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from src.modules.emergency import tasks
from src.modules.emergency.models import (
    NotificationStatus,
    SOSReport,
    SOSStatus,
)
from tests.conftest import run

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


async def _get_report(
    db: AsyncSession, report_id: UUID
) -> SOSReport | None:
    """Carga un reporte con sus notificaciones ya resueltas (sin lazy-load)."""
    result = await db.execute(
        select(SOSReport)
        .where(SOSReport.id == report_id)
        .options(selectinload(SOSReport.notifications))
    )
    return result.scalar_one_or_none()


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
    client: TestClient, db_session: AsyncSession
) -> None:
    _sign_up(client, "cola@ika.pe")
    headers = _headers(client, "cola@ika.pe")

    report_id = _create_sos(client, headers).json()["id"]

    report = run(_get_report(db_session, UUID(report_id)))
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
    client: TestClient, db_session: AsyncSession
) -> None:
    """Sin proveedor configurado el fallo queda registrado, no silencioso."""
    _sign_up(client, "falla@ika.pe")
    headers = _headers(client, "falla@ika.pe")
    report_id = UUID(_create_sos(client, headers).json()["id"])

    sent = run(tasks.process_sos_notifications(report_id, db_session))

    assert sent == 0
    report = run(_get_report(db_session, report_id))
    assert all(
        notification.status == NotificationStatus.FAILED
        for notification in report.notifications
    )


def test_task_marks_notifications_sent_when_provider_succeeds(
    client: TestClient,
    db_session: AsyncSession,
    monkeypatch,
) -> None:
    _sign_up(client, "exito@ika.pe")
    headers = _headers(client, "exito@ika.pe")
    report_id = UUID(_create_sos(client, headers).json()["id"])
    monkeypatch.setattr(tasks, "send_notification", lambda *args, **kwargs: True)

    sent = run(tasks.process_sos_notifications(report_id, db_session))

    assert sent == 2
    report = run(_get_report(db_session, report_id))
    assert all(
        notification.status == NotificationStatus.SENT
        and notification.sent_at is not None
        for notification in report.notifications
    )


# ============================================================================
# Tests para Contactos de Emergencia y Reportes DIRCETUR (RF-05 / CUN06)
# ============================================================================

def test_get_emergency_contacts_returns_200(client: TestClient) -> None:
    response = client.get(f"{API}/emergency/contacts")
    assert response.status_code == 200
    contacts = response.json()
    assert isinstance(contacts, list)
    assert len(contacts) >= 4
    # Verificar que contiene POLTUR Ica y DIRCETUR Ica
    names = [c["name"] for c in contacts]
    assert any("POLTUR" in name for name in names)
    assert any("DIRCETUR" in name for name in names)


def test_tourist_create_incident_report(client: TestClient) -> None:
    _sign_up(client, "denuncia@ika.pe")
    headers = _headers(client, "denuncia@ika.pe")

    payload = {
        "incident_type": "informal_service",
        "title": "Cobro excesivo y falta de chalecos en tubulares",
        "description": "Un jalador informal en Huacachina ofreció tour sin credencial oficial ni SOAT vigente.",
        "latitude": -14.087,
        "longitude": -75.763,
        "agency_name": "Tours Fantasma Huacachina",
    }
    response = client.post(
        f"{API}/emergency/reports",
        json=payload,
        headers=headers,
    )
    assert response.status_code == 201
    data = response.json()
    assert data["incident_type"] == "informal_service"
    assert data["status"] == "received"
    assert data["agency_name"] == "Tours Fantasma Huacachina"


def test_list_my_tourist_reports(client: TestClient) -> None:
    _sign_up(client, "mis_reportes@ika.pe")
    headers = _headers(client, "mis_reportes@ika.pe")

    client.post(
        f"{API}/emergency/reports",
        json={
            "incident_type": "information_error",
            "title": "Horario falso de museo regional",
            "description": "El panel indicaba abierto pero estaba cerrado por inventario.",
        },
        headers=headers,
    )

    response = client.get(f"{API}/emergency/my-reports", headers=headers)
    assert response.status_code == 200
    reports = response.json()
    assert len(reports) == 1
    assert reports[0]["title"] == "Horario falso de museo regional"


def test_admin_reports_forbidden_for_regular_tourist(client: TestClient) -> None:
    _sign_up(client, "turista_comun@ika.pe")
    headers = _headers(client, "turista_comun@ika.pe")

    response = client.get(f"{API}/emergency/admin/reports", headers=headers)
    assert response.status_code == 403


def test_admin_reports_allowed_and_can_update_status(
    client: TestClient, db_session: AsyncSession
) -> None:
    from src.modules.users.models import User, UserRole

    # 1. Crear usuario turista y reporte
    _sign_up(client, "reporta_esto@ika.pe")
    headers_tourist = _headers(client, "reporta_esto@ika.pe")
    rep_res = client.post(
        f"{API}/emergency/reports",
        json={
            "incident_type": "safety_hazard",
            "title": "Sendero mal señalizado hacia mirador",
            "description": "Falta baranda y señalización adecuada cerca de la duna mayor.",
        },
        headers=headers_tourist,
    )
    report_id = rep_res.json()["id"]

    # 2. Crear admin DIRCETUR
    _sign_up(client, "admin_fiscalizador@ika.pe")
    headers_admin = _headers(client, "admin_fiscalizador@ika.pe")

    # Modificar rol a dircetur_admin directamente en BD para el test
    async def _make_admin():
        user = (
            await db_session.execute(
                select(User).where(User.email == "admin_fiscalizador@ika.pe")
            )
        ).scalar_one()
        user.role = UserRole.DIRCETUR_ADMIN
        db_session.add(user)
        await db_session.commit()

    run(_make_admin())

    # 3. Consultar lista como admin
    get_res = client.get(f"{API}/emergency/admin/reports", headers=headers_admin)
    assert get_res.status_code == 200
    all_reports = get_res.json()
    assert any(r["id"] == report_id for r in all_reports)

    # 4. Actualizar estado y notas
    patch_res = client.patch(
        f"{API}/emergency/admin/reports/{report_id}",
        json={
            "status": "in_review",
            "admin_notes": "Notificado a fiscalización de DIRCETUR y Policía de Turismo.",
        },
        headers=headers_admin,
    )
    assert patch_res.status_code == 200
    assert patch_res.json()["status"] == "in_review"
    assert "fiscalización" in patch_res.json()["admin_notes"]
