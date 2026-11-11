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


def test_la_ultima_revision_es_la_del_rf_03() -> None:
    """La migración RF-03 (tokens de recuperación) cierra la cadena actual."""
    config = Config(str(RAIZ_BACKEND / "alembic.ini"))
    scripts = ScriptDirectory.from_config(config)

    head = scripts.get_current_head()

    assert head == "e5c1a7b93f28", (
        f"El head cambió ({head}); actualiza este test y documenta la nueva "
        "revisión en docs/rf-03_recuperacion_cuenta.md."
    )
