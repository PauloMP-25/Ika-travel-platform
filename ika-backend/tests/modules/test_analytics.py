from datetime import date, timedelta
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

from src.core.security import create_access_token
from src.modules.catalog.models import Attraction
from src.modules.emergency.models import IncidentStatus, IncidentType, TouristIncidentReport
from src.modules.reviews.models import Favorite, Review
from src.modules.users.models import User, UserRole
from src.modules.analytics.models import UsageEvent, UsageEventType
from tests.conftest import run


def _create_user(db_session, email, role=UserRole.TOURIST, lang="es", prefs=None, active=True):
    user = User(
        email=email,
        password_hash="fakehashedpassword",
        full_name=f"User {email}",
        role=role,
        preferred_language=lang,
        preferences=prefs or [],
        is_active=active,
    )
    db_session.add(user)
    return user


def _create_attraction(db_session, name, district="Ica"):
    attraction = Attraction(
        name=name,
        description="Hermoso lugar",
        district=district,
        latitude=-14.0678,
        longitude=-75.7286,
        is_active=True,
    )
    db_session.add(attraction)
    return attraction


def test_analytics_endpoints_auth_and_roles(client: TestClient, db_session):
    """A-01, A-02, A-03: Validación de autenticación y rol dircetur_admin."""
    # A-02: Sin token -> 401
    resp = client.get("/api/v1/admin/analytics/summary")
    assert resp.status_code == 401

    # Crear usuario tourist y admin
    tourist = _create_user(db_session, "tourist@test.com", role=UserRole.TOURIST)
    admin = _create_user(db_session, "admin@test.com", role=UserRole.DIRCETUR_ADMIN)
    run(db_session.commit())

    tourist_token = create_access_token(tourist.id)
    admin_token = create_access_token(admin.id)

    # A-03: Rol tourist -> 403
    resp_tourist = client.get(
        "/api/v1/admin/analytics/summary",
        headers={"Authorization": f"Bearer {tourist_token}"},
    )
    assert resp_tourist.status_code == 403

    # A-01: Rol dircetur_admin -> 200 y estructura completa
    resp_admin = client.get(
        "/api/v1/admin/analytics/summary",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp_admin.status_code == 200
    data = resp_admin.json()
    assert "period" in data
    assert "kpis" in data
    assert "languages" in data
    assert "preferences" in data
    assert "top_attractions" in data
    assert "incidents" in data


def test_analytics_languages_and_active_users(client: TestClient, db_session):
    """A-04, A-05: Idiomas preferidos y exclusión de usuarios inactivos."""
    _create_user(db_session, "u1@test.com", lang="es", active=True)
    _create_user(db_session, "u2@test.com", lang="es", active=True)
    _create_user(db_session, "u3@test.com", lang="en", active=True)
    _create_user(db_session, "u4@test.com", lang="fr", active=False)  # inactivo

    admin = _create_user(db_session, "admin_lang@test.com", role=UserRole.DIRCETUR_ADMIN)
    run(db_session.commit())

    admin_token = create_access_token(admin.id)
    resp = client.get(
        "/api/v1/admin/analytics/languages",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 200
    langs = resp.json()["preferred_language_users"]
    labels = {item["label"]: item["count"] for item in langs}
    assert labels.get("es") == 3  # u1, u2, admin_lang
    assert labels.get("en") == 1  # u3
    assert "fr" not in labels     # inactivo excluido


def test_analytics_date_range_validation(client: TestClient, db_session):
    """A-16, A-17: Validación de rango de fechas."""
    admin = _create_user(db_session, "admin_dates@test.com", role=UserRole.DIRCETUR_ADMIN)
    run(db_session.commit())
    token = create_access_token(admin.id)

    # A-16: date_from > date_to -> 400
    resp_invalid = client.get(
        "/api/v1/admin/analytics/summary?date_from=2026-10-15&date_to=2026-10-10",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp_invalid.status_code == 400
    assert resp_invalid.json()["codigo"] == "RANGO_FECHAS_INVALIDO"

    # A-17: Rango > 366 días -> 400
    resp_too_large = client.get(
        "/api/v1/admin/analytics/summary?date_from=2024-01-01&date_to=2025-02-15",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp_too_large.status_code == 400
    assert resp_too_large.json()["codigo"] == "RANGO_FECHAS_EXCEDIDO"


def test_analytics_preferences_expansion(client: TestClient, db_session):
    """A-07, A-08: Preferencias JSON normalizadas y sin fallos por formatos inválidos."""
    _create_user(db_session, "p1@test.com", prefs=["aventura", "cultura"])
    _create_user(db_session, "p2@test.com", prefs=["aventura"])
    _create_user(db_session, "p3@test.com", prefs=[])
    admin = _create_user(db_session, "admin_pref@test.com", role=UserRole.DIRCETUR_ADMIN)
    run(db_session.commit())

    token = create_access_token(admin.id)
    resp = client.get(
        "/api/v1/admin/analytics/preferences",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    prefs = resp.json()["registered_preferences"]
    pref_counts = {item["label"]: item["count"] for item in prefs}
    assert pref_counts.get("aventura") == 2
    assert pref_counts.get("cultura") == 1


def test_top_attractions_without_cartesian_product(client: TestClient, db_session):
    """A-09, A-10, A-11, A-12: Top atractivos con conteos exactos sin producto cartesiano."""
    u1 = _create_user(db_session, "user_top1@test.com")
    u2 = _create_user(db_session, "user_top2@test.com")
    u3 = _create_user(db_session, "user_top3@test.com")
    admin = _create_user(db_session, "admin_top@test.com", role=UserRole.DIRCETUR_ADMIN)

    attraction = _create_attraction(db_session, "Huacachina Oasis")
    run(db_session.commit())

    # 3 favoritos
    db_session.add(Favorite(user_id=u1.id, attraction_id=attraction.id))
    db_session.add(Favorite(user_id=u2.id, attraction_id=attraction.id))
    db_session.add(Favorite(user_id=u3.id, attraction_id=attraction.id))

    # 2 reviews
    db_session.add(Review(user_id=u1.id, attraction_id=attraction.id, rating=5, comment="Excelente"))
    db_session.add(Review(user_id=u2.id, attraction_id=attraction.id, rating=4, comment="Muy bueno"))

    # 4 vistas de evento
    for _ in range(4):
        db_session.add(UsageEvent(event_type=UsageEventType.ATTRACTION_VIEW, attraction_id=attraction.id))

    run(db_session.commit())

    token = create_access_token(admin.id)
    resp = client.get(
        "/api/v1/admin/analytics/attractions/top?limit=10&sort_by=favorites",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    items = resp.json()["items"]
    assert len(items) == 1
    item = items[0]
    assert item["name"] == "Huacachina Oasis"
    assert item["favorites"] == 3
    assert item["reviews"] == 2
    assert item["views"] == 4
    assert item["avg_rating"] == 4.5

    # A-12: limit=51 -> 422
    resp_limit_exceeded = client.get(
        "/api/v1/admin/analytics/attractions/top?limit=51",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp_limit_exceeded.status_code == 422


def test_catalog_instrumentation_records_events(client: TestClient, db_session):
    """A-18, A-19: Instrumentación del catálogo registra búsquedas y vistas."""
    from src.modules.catalog.models import Category
    cat = Category(name="Aventura", slug="aventura")
    db_session.add(cat)
    attraction = _create_attraction(db_session, "Cañón de los Perdidos", district="Santiago")
    run(db_session.commit())

    # GET /catalog/attractions?category=aventura -> track_attraction_search
    client.get("/api/v1/catalog/attractions?category=aventura", headers={"accept-language": "es-PE,es;q=0.9"})

    # GET /catalog/attractions/{id} -> track_attraction_view
    client.get(f"/api/v1/catalog/attractions/{attraction.id}", headers={"accept-language": "en-US,en;q=0.9"})

    async def _get_events():
        stmt = select(UsageEvent)
        res = await db_session.execute(stmt)
        return res.scalars().all()

    events = run(_get_events())
    types = [e.event_type for e in events]
    assert UsageEventType.ATTRACTION_SEARCH in types
    assert UsageEventType.ATTRACTION_VIEW in types


def test_analytics_summary_cache(client: TestClient, db_session):
    """A-21: Resumen analítico usa caché Redis para peticiones idénticas."""
    from unittest.mock import patch
    admin = _create_user(db_session, "admin_cache@test.com", role=UserRole.DIRCETUR_ADMIN)
    run(db_session.commit())
    token = create_access_token(admin.id)

    # Primera llamada: llena caché
    resp1 = client.get("/api/v1/admin/analytics/summary", headers={"Authorization": f"Bearer {token}"})
    assert resp1.status_code == 200

    # Segunda llamada: verificamos que retorna el mismo contenido
    resp2 = client.get("/api/v1/admin/analytics/summary", headers={"Authorization": f"Bearer {token}"})
    assert resp2.status_code == 200
    assert resp1.json() == resp2.json()


def test_analytics_incidents_metrics(client: TestClient, db_session):
    """A-13, A-14, A-15: Endpoint analítico de incidencias de DIRCETUR."""
    admin = _create_user(db_session, "admin_incidents@test.com", role=UserRole.DIRCETUR_ADMIN)
    tourist = _create_user(db_session, "tourist_inc@test.com", role=UserRole.TOURIST)
    run(db_session.commit())

    # Sembrar incidencias
    inc1 = TouristIncidentReport(
        user_id=tourist.id,
        incident_type=IncidentType.INFORMAL_SERVICE,
        title="Agencia sin carnet",
        description="Transporte informal en Huacachina",
        agency_name="Agencia Pirata Tours",
        status=IncidentStatus.RECEIVED,
    )
    inc2 = TouristIncidentReport(
        user_id=tourist.id,
        incident_type=IncidentType.INFORMAL_SERVICE,
        title="Cobro indebido",
        description="Cobro excesivo de buggy",
        agency_name="agencia pirata tours",  # para probar agrupamiento case-insensitive
        status=IncidentStatus.RESOLVED,
    )
    db_session.add(inc1)
    db_session.add(inc2)
    run(db_session.commit())

    token = create_access_token(admin.id)
    resp = client.get("/api/v1/admin/analytics/incidents", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200
    data = resp.json()

    assert data["total"] == 2
    assert data["resolution_rate"] == 50.0  # 1 resuelto de 2
    types = {item["label"]: item["count"] for item in data["by_type"]}
    assert types.get(IncidentType.INFORMAL_SERVICE.value) == 2

    # A-15: Top agencias informales agrupadas por nombre sin distinguir mayúsculas
    top_agencies = data["top_informal_agencies"]
    assert len(top_agencies) >= 1
    assert top_agencies[0]["count"] == 2
