"""Protección provisional de endpoints administrativos mediante X-Admin-Key.

Se usa mientras el módulo ``users`` no tenga roles. Cuando existan, basta con
reemplazar esta dependencia por una que exija un usuario con rol admin.
"""
import secrets

from fastapi import Header

from src.core.config import configuracion
from src.core.exceptions import AccesoAdminDenegadoException, AdminNoConfiguradoException


async def requerir_admin(x_admin_key: str | None = Header(default=None)) -> None:
    if not configuracion.CLAVE_ADMIN:
        raise AdminNoConfiguradoException()
    if x_admin_key is None or not secrets.compare_digest(
        x_admin_key.encode(), configuracion.CLAVE_ADMIN.encode()
    ):
        raise AccesoAdminDenegadoException()
