"""Tests del catálogo público: ETag/304 (Sprint 4, F3) y RN-01.

Los ETag se calculan sobre el cuerpo **ya filtrado y paginado**, así que:
- cada combinación de query params tiene su propio ETag;
- cualquier cambio de contenido (crear, editar, dejar de validar una agencia)
  cambia el ETag automáticamente.
"""

from uuid import UUID, uuid4

from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession

from src.modules.catalog.models import Agency, Attraction, Category
from tests.conftest import run

API = "/api/v1"


def _crear_atractivo(
    db: AsyncSession,
    *,
    nombre: str = "Oasis de Huacachina",
    distrito: str = "Ica",
) -> UUID:
    """Inserta un atractivo directamente en BD (sin depender del admin API)."""
    import datetime as _dt

    atractivo = Attraction(
        name=nombre,
        description="Dunas y oasis en el desierto de Ica.",
        latitude=-14.0873,
        longitude=-75.7637,
        district=distrito,
        is_active=True,
        created_at=_dt.datetime.now(_dt.timezone.utc),
        updated_at=_dt.datetime.now(_dt.timezone.utc),
    )
    db.add(atractivo)
    run(db.commit())
    return atractivo.id


def _crear_agencia(db: AsyncSession, *, validada: bool, nombre: str) -> UUID:
    import datetime as _dt

    agencia = Agency(
        name=nombre,
        ruc=str(uuid4().int % 10**11).zfill(11),  # 11 dígitos únicos por test
        is_validated=validada,
        validated_at=_dt.datetime.now(_dt.timezone.utc) if validada else None,
        created_at=_dt.datetime.now(_dt.timezone.utc),
    )
    db.add(agencia)
    run(db.commit())
    return agencia.id


# ----------------------------------------------------------------------
# ETag en /catalog/attractions
# ----------------------------------------------------------------------
def test_primera_peticion_devuelve_etag_y_segunda_304(
    client: TestClient, db_session: AsyncSession
) -> None:
    _crear_atractivo(db_session)

    primera = client.get(f"{API}/catalog/attractions")

    assert primera.status_code == 200
    etag = primera.headers.get("etag")
    assert etag and etag.startswith('W/"')
    assert primera.headers.get("cache-control") == "no-cache"

    segunda = client.get(
        f"{API}/catalog/attractions", headers={"If-None-Match": etag}
    )

    assert segunda.status_code == 304
    assert segunda.content == b""  # 304 sin cuerpo
    assert segunda.headers.get("etag") == etag


def test_editar_un_atractivo_cambia_el_etag(client: TestClient, db_session: AsyncSession) -> None:
    atractivo_id = _crear_atractivo(db_session)
    etag_original = client.get(f"{API}/catalog/attractions").headers.get("etag")

    async def _renombrar() -> None:
        atractivo = await db_session.get(Attraction, atractivo_id)
        atractivo.name = "Oasis de Huacachina (renombrado)"
        db_session.add(atractivo)
        await db_session.commit()

    run(_renombrar())

    despues = client.get(f"{API}/catalog/attractions")

    assert despues.status_code == 200
    assert despues.headers.get("etag") != etag_original

    # El ETag viejo ya no está vigente: revalidar devuelve el cuerpo nuevo.
    revalidada = client.get(
        f"{API}/catalog/attractions", headers={"If-None-Match": etag_original}
    )
    assert revalidada.status_code == 200


def test_distintos_query_params_tienen_distinto_etag(
    client: TestClient, db_session: AsyncSession
) -> None:
    _crear_atractivo(db_session)
    _crear_atractivo(db_session, nombre="Líneas de Nasca", distrito="Nasca")

    una_pagina = client.get(f"{API}/catalog/attractions?page=1&page_size=1")
    otra_pagina = client.get(f"{API}/catalog/attractions?page=2&page_size=1")
    sin_filtro = client.get(f"{API}/catalog/attractions")

    assert una_pagina.headers.get("etag") != otra_pagina.headers.get("etag")
    assert una_pagina.headers.get("etag") != sin_filtro.headers.get("etag")

    # Cada uno revalida con su propio ETag.
    revalidada = client.get(
        f"{API}/catalog/attractions?page=1&page_size=1",
        headers={"If-None-Match": una_pagina.headers.get("etag", "")},
    )
    assert revalidada.status_code == 304


def test_if_none_match_con_comodin_o_lista(client: TestClient, db_session: AsyncSession) -> None:
    _crear_atractivo(db_session)
    etag = client.get(f"{API}/catalog/attractions").headers.get("etag")

    con_comodin = client.get(f"{API}/catalog/attractions", headers={"If-None-Match": "*"})
    con_lista = client.get(
        f"{API}/catalog/attractions",
        headers={"If-None-Match": f'W/"otro-etag", {etag}'},
    )
    distinto = client.get(
        f"{API}/catalog/attractions", headers={"If-None-Match": 'W/"nunca-visto"'}
    )

    assert con_comodin.status_code == 304
    assert con_lista.status_code == 304
    assert distinto.status_code == 200


# ----------------------------------------------------------------------
# RN-01 + ETag en /catalog/agencies
# ----------------------------------------------------------------------
def test_invalidar_agencia_cambia_el_etag_y_desaparece(
    client: TestClient, db_session: AsyncSession
) -> None:
    """RN-01: el catálogo público solo lista agencias validadas."""
    agencia_id = _crear_agencia(db_session, validada=True, nombre="Tours Paracas Oficial")

    antes = client.get(f"{API}/catalog/agencies")
    assert antes.status_code == 200
    assert [a["id"] for a in antes.json()] == [str(agencia_id)]

    async def _revocar() -> None:
        agencia = await db_session.get(Agency, agencia_id)
        agencia.is_validated = False
        db_session.add(agencia)
        await db_session.commit()

    run(_revocar())

    despues = client.get(f"{API}/catalog/agencies")

    assert despues.status_code == 200
    assert despues.json() == []
    assert despues.headers.get("etag") != antes.headers.get("etag")


def test_etag_de_agencias_no_filtrado_por_otras_rutas(
    client: TestClient, db_session: AsyncSession
) -> None:
    """El ETag de agencies y el de attractions son independientes."""
    _crear_agencia(db_session, validada=True, nombre="Agencia ETag")
    etag_agencias = client.get(f"{API}/catalog/agencies").headers.get("etag")
    etag_atractivos = client.get(f"{API}/catalog/attractions").headers.get("etag")

    assert etag_agencias != etag_atractivos
