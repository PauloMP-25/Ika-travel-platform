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


def test_la_ultima_revision_es_la_del_sprint_4() -> None:
    """La migración de idempotencia/oauth cierra la cadena del sprint."""
    config = Config(str(RAIZ_BACKEND / "alembic.ini"))
    scripts = ScriptDirectory.from_config(config)

    head = scripts.get_current_head()

    assert head == "8db9ab3bcce4", (
        f"El head cambió ({head}); actualiza este test y documenta la nueva "
        "revisión en docs/sprint_4.md."
    )
