"""Tests para el módulo geo: /nearby y cobertura de la región de Ica."""
import datetime as _dt
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession
from src.modules.catalog.models import Attraction
from tests.conftest import run

API = "/api/v1"


def test_nearby_admite_radio_300km_y_limite_100(
    client: TestClient, db_session: AsyncSession
) -> None:
    """Verifica que /geo/nearby acepte radius_m hasta 300,000 m y limit hasta 100 sin error 422,
    cubriendo destinos lejanos como Playa Hermosa de Marcona."""
    marcona = Attraction(
        name="Playa Hermosa de Marcona",
        description="Playa y formaciones rocosas en Marcona.",
        latitude=-15.3583,
        longitude=-75.1750,
        district="Marcona",
        is_active=True,
        created_at=_dt.datetime.now(_dt.timezone.utc),
        updated_at=_dt.datetime.now(_dt.timezone.utc),
    )
    db_session.add(marcona)
    run(db_session.commit())

    # Centro de Ica: -14.0685, -75.7288
    # Con radius_m=300000 y limit=100 debe responder 200 y encontrar a Marcona (>140km)
    resp = client.get(
        f"{API}/geo/nearby",
        params={
            "lat": -14.0685,
            "lon": -75.7288,
            "radius_m": 300000,
            "limit": 100,
        },
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["radius_m"] == 300000
    items = data["items"]
    nombres = [item["name"] for item in items]
    assert "Playa Hermosa de Marcona" in nombres
