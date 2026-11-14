"""F5 — Un solo head de Alembic (Sprint 4).

La guía del equipo pide que "el CI falle si `alembic heads` devuelve más de
una línea": un merge mal resuelto entre ramas dejan revisiones hermanas y la
siguiente migración fallaría en producción. Este test resuelve el grafo de
revisiones sin tocar la base de datos.
"""

from pathlib import Path

from alembic.config import Config
from alembic.script import ScriptDirectory

RAIZ_BACKEND = Path(__file__).resolve().parents[2]


def test_hay_un_solo_head_de_alembic() -> None:
    config = Config(str(RAIZ_BACKEND / "alembic.ini"))
    scripts = ScriptDirectory.from_config(config)

    heads = scripts.get_heads()

    assert len(heads) == 1, (
        f"Se esperaba un único head de Alembic y hay {len(heads)}: {heads}. "
        "Encadena las revisiones (down_revision) antes de mergear."
    )


def test_la_ultima_revision_es_la_de_la_correccion_14() -> None:
    """La migración Corrección N.º 14 (tabla `roles`) cierra la cadena actual.

    Antes esta prueba fijaba el head de RF-03 (`e5c1a7b93f28`); la cadena
    avanzó con `b7c9e1f4a2d6` (tabla `roles` + FK `users.role_id`).
    """
    config = Config(str(RAIZ_BACKEND / "alembic.ini"))
    scripts = ScriptDirectory.from_config(config)

    head = scripts.get_current_head()

    assert head == "b7c9e1f4a2d6", (
        f"El head cambió ({head}); actualiza este test y documenta la nueva "
        "revisión en docs/modelo_datos.md."
    )
