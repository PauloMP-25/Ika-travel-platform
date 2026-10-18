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
    assert response.status_code == 201, f"register falló: {response.text}"
    return response.json()


def _headers(client: TestClient, email: str) -> dict[str, str]:
    response = client.post(
        f"{API}/auth/login",
        json={"email": email, "password": "secreto123"},
    )
    assert response.status_code == 200, f"login falló: {response.text}"
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


# ============================================================================
# Sprint 4, F4: Idempotency-Key en POST /emergency/sos y /emergency/reports
# ============================================================================

CLAVE = "ikatravel-0000-0000-0000-000000000001"


def test_misma_clave_mismo_payload_crea_una_sola_fila(
    client: TestClient, db_session: AsyncSession
) -> None:
    """Reenviar la misma clave devuelve el recurso original (200 + replay)."""
    _sign_up(client, "idem@ika.pe")
    headers = _headers(client, "idem@ika.pe")
    headers_con_clave = {**headers, "Idempotency-Key": CLAVE}

    primera = _create_sos(client, headers_con_clave)
    segunda = _create_sos(client, headers_con_clave)

    assert primera.status_code == 201
    assert segunda.status_code == 200
    assert segunda.headers.get("idempotent-replayed") == "true"
    assert segunda.json()["id"] == primera.json()["id"]

    filas = run(
        db_session.execute(select(SOSReport).where(SOSReport.user_id.is_not(None)))
    )
    assert len(filas.scalars().all()) == 1


def test_el_replay_no_vuelve_a_despachar_notificaciones(
    client: TestClient, monkeypatch
) -> None:
    """El despacho Celery solo se encola en la creación real."""
    from src.modules.emergency import service as service_emergency

    _sign_up(client, "spy@ika.pe")
    headers = _headers(client, "spy@ika.pe")
    headers_con_clave = {**headers, "Idempotency-Key": CLAVE}

    llamadas: list[str] = []
    monkeypatch.setattr(
        service_emergency.tasks.dispatch_sos_notifications,
        "delay",
        lambda report_id: llamadas.append(report_id),
    )

    _create_sos(client, headers_con_clave)
    _create_sos(client, headers_con_clave)

    assert len(llamadas) == 1


def test_misma_clave_payload_distinto_da_422(client: TestClient) -> None:
    _sign_up(client, "reusa@ika.pe")
    headers = {**_headers(client, "reusa@ika.pe"), "Idempotency-Key": CLAVE}

    _create_sos(client, headers)
    conflicto = _create_sos(client, headers, description="Otra emergencia distinta")

    assert conflicto.status_code == 422
    assert conflicto.json()["codigo"] == "IDEMPOTENCY_KEY_REUTILIZADA"


def test_sin_header_el_comportamiento_anterior_se_mantiene(
    client: TestClient, db_session: AsyncSession
) -> None:
    """Sin cabecera no hay idempotencia: dos peticiones crean dos filas."""
    _sign_up(client, "sin-header@ika.pe")
    headers = _headers(client, "sin-header@ika.pe")

    primera = _create_sos(client, headers)
    segunda = _create_sos(client, headers)

    assert primera.status_code == segunda.status_code == 201
    assert primera.json()["id"] != segunda.json()["id"]

    filas = run(
        db_session.execute(select(SOSReport).where(SOSReport.user_id.is_not(None)))
    )
    assert len(filas.scalars().all()) == 2


def test_clave_con_formato_invalido_da_400(client: TestClient) -> None:
    _sign_up(client, "formato@ika.pe")
    headers = {**_headers(client, "formato@ika.pe"), "Idempotency-Key": "abc"}

    respuesta = _create_sos(client, headers)

    assert respuesta.status_code == 400
    assert respuesta.json()["codigo"] == "IDEMPOTENCY_KEY_INVALIDA"


def test_la_clave_tiene_ambito_por_usuario(client: TestClient) -> None:
    """La misma clave de dos usuarios distintos crea dos filas (ámbito usuario)."""
    _sign_up(client, "usuario-a@ika.pe")
    _sign_up(client, "usuario-b@ika.pe")
    headers_a = {**_headers(client, "usuario-a@ika.pe"), "Idempotency-Key": CLAVE}
    headers_b = {**_headers(client, "usuario-b@ika.pe"), "Idempotency-Key": CLAVE}

    respuesta_a = _create_sos(client, headers_a)
    respuesta_b = _create_sos(client, headers_b)

    assert respuesta_a.status_code == respuesta_b.status_code == 201
    assert respuesta_a.json()["id"] != respuesta_b.json()["id"]


def test_idempotencia_tambien_en_emergency_reports(client: TestClient) -> None:
    """El mismo contrato aplica a POST /emergency/reports."""
    _sign_up(client, "reportes-idem@ika.pe")
    headers = {**_headers(client, "reportes-idem@ika.pe"), "Idempotency-Key": CLAVE}
    payload = {
        "incident_type": "information_error",
        "title": "Señalización incorrecta en el centro",
        "description": "El letrero indica mal la ruta hacia el museo regional de Ica.",
    }

    primera = client.post(f"{API}/emergency/reports", json=payload, headers=headers)
    segunda = client.post(f"{API}/emergency/reports", json=payload, headers=headers)

    assert primera.status_code == 201
    assert segunda.status_code == 200
    assert segunda.headers.get("idempotent-replayed") == "true"
    assert segunda.json()["id"] == primera.json()["id"]


def test_clave_es_por_ambito_de_usuario_en_reports(
    client: TestClient,
) -> None:
    """La misma clave de dos usuarios distintos crea dos filas en /reports."""
    _sign_up(client, "ambito-a@ika.pe")
    _sign_up(client, "ambito-b@ika.pe")
    payload = {
        "incident_type": "information_error",
        "title": "Horario incorrecto",
        "description": "El horario publicado no coincide con el real.",
    }

    primera = client.post(
        f"{API}/emergency/reports",
        json=payload,
        headers={**_headers(client, "ambito-a@ika.pe"), "Idempotency-Key": CLAVE},
    )
    segunda = client.post(
        f"{API}/emergency/reports",
        json=payload,
        headers={**_headers(client, "ambito-b@ika.pe"), "Idempotency-Key": CLAVE},
    )

    assert primera.status_code == 201
    assert segunda.status_code == 201
    assert primera.json()["id"] != segunda.json()["id"]


def test_rn04_se_valida_antes_de_consumir_la_clave(client: TestClient) -> None:
    """Una petición sin GPS válidos no consume la Idempotency-Key (RN-04)."""
    _sign_up(client, "gps-invalido@ika.pe")
    headers = _headers(client, "gps-invalido@ika.pe")

    rechazado = _create_sos(
        client,
        {**headers, "Idempotency-Key": CLAVE},
        latitude=None,
        longitude=None,
    )

    assert rechazado.status_code == 400

    # La clave sigue disponible: no se registró nada con ella.
    valido = _create_sos(client, {**headers, "Idempotency-Key": CLAVE})
    assert valido.status_code == 201


def test_carrera_por_clave_termina_en_una_sola_fila(
    client: TestClient, db_session: AsyncSession, monkeypatch
) -> None:
    """Simula la carrera: la lectura inicial no ve la fila y pega la restricción única."""
    from src.modules.emergency import service as emergency_service
    from src.modules.emergency.schemas import SOSCreate

    _sign_up(client, "carrera-servicio@ika.pe")
    headers = _headers(client, "carrera-servicio@ika.pe")
    creada = _create_sos(client, {**headers, "Idempotency-Key": CLAVE})
    assert creada.status_code == 201

    usuario_id = run(_id_de_usuario(db_session, "carrera-servicio@ika.pe"))
    datos = SOSCreate(
        latitude=-14.089, longitude=-75.697, description="Caída en dunas"
    )

    original = emergency_service._buscar_sos_por_clave
    estado = {"primera_lectura": True}

    async def _buscar_invisible(db, user_id, clave):
        if estado["primera_lectura"]:
            estado["primera_lectura"] = False  # como si aún no existiera
            return None
        return await original(db, user_id, clave)

    monkeypatch.setattr(
        emergency_service, "_buscar_sos_por_clave", _buscar_invisible
    )

    reporte, repetido = run(
        emergency_service.crear_reporte_sos(db_session, usuario_id, datos, CLAVE)
    )

    assert repetido is True
    assert reporte.idempotency_key == CLAVE


async def _id_de_usuario(db: AsyncSession, email: str) -> UUID:
    from src.modules.users.models import User

    resultado = await db.execute(select(User.id).where(User.email == email))
    return resultado.scalar_one()
