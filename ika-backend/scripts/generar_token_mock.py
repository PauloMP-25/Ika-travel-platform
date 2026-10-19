"""Script para generar tokens JWT de prueba (Mock Tokens) para desarrollo y testing de Flutter."""
import asyncio
import sys
from uuid import uuid4

from sqlalchemy import select

from src.core.database import SessionLocal
from src.core.security import create_access_token, hash_password
from src.modules.users.models import CategoriaTuristicaIca, User, UserRole


async def generar_o_obtener_usuario_demo(
    email: str = "turista.demo@ikatravel.pe",
    role: UserRole = UserRole.TOURIST,
    full_name: str = "Turista Demo",
    lang: str = "es",
    prefs: list[str] | None = None,
) -> tuple[User, str]:
    if prefs is None:
        prefs = [CategoriaTuristicaIca.AVENTURA_DESIERTO.value, CategoriaTuristicaIca.ENOTURISMO.value]

    async with SessionLocal() as session:
        query = select(User).where(User.email == email)
        result = await session.execute(query)
        user = result.scalar_one_or_none()

        if user is None:
            user = User(
                id=uuid4(),
                email=email,
                password_hash=hash_password("Demo1234!"),
                full_name=full_name,
                role=role,
                preferred_language=lang,
                preferences=prefs,
                is_active=True,
            )
            session.add(user)
            await session.commit()
            await session.refresh(user)
            print(f"[*] Usuario creado exitosamente: {email} (ID: {user.id})")
        else:
            print(f"[*] Usuario existente encontrado: {email} (ID: {user.id})")

        # Token con expiración extendida (ej. 30 días = 43200 minutos)
        token = create_access_token(user_id=user.id, expires_minutes=43200)
        return user, token


async def main():
    print("=" * 70)
    print("  IKA TRAVEL & EXPERIENCE - GENERADOR DE TOKENS DE PRUEBA (MOCK)")
    print("=" * 70)

    # 1. Turista estándar
    user_turista, token_turista = await generar_o_obtener_usuario_demo(
        email="turista.demo@ikatravel.pe",
        role=UserRole.TOURIST,
        full_name="Turista Demo (Ica Aventura)",
        lang="es",
    )

    # 2. Administrador DIRCETUR
    user_admin, token_admin = await generar_o_obtener_usuario_demo(
        email="admin.dircetur@ikatravel.pe",
        role=UserRole.DIRCETUR_ADMIN,
        full_name="Fiscalizador DIRCETUR Demo",
        lang="es",
    )

    print("\n" + "-" * 70)
    print(">>> TOKEN TURISTA (Para Flutter Mobile / Web):")
    print(f"Authorization: Bearer {token_turista}")
    print("-" * 70)
    print(">>> TOKEN ADMIN DIRCETUR (Para pruebas de analítica y fiscalización):")
    print(f"Authorization: Bearer {token_admin}")
    print("=" * 70)


if __name__ == "__main__":
    asyncio.run(main())
