"""Dobles de prueba compartidos (RF-03).

- `MockEmailSender`: captura los correos en memoria; ningún test del paquete
  por defecto abre una conexión con Gmail ni con otro servidor SMTP.
- `FakeRedis`: contador de ventana fija para ejercer el rate limit sin un
  Redis real (en local el servidor no está disponible).
"""

from __future__ import annotations

from src.modules.users.email import Correo, EmailSender


class MockEmailSender(EmailSender):
    """`EmailSender` de prueba: acumula los correos en vez de enviarlos."""

    def __init__(self) -> None:
        self.enviados: list[Correo] = []

    async def enviar(self, correo: Correo) -> None:
        self.enviados.append(correo)

    # --- Azúcar para las aserciones ---
    @property
    def cantidad(self) -> int:
        return len(self.enviados)

    def ultimo(self) -> Correo:
        assert self.enviados, "No se envió ningún correo."
        return self.enviados[-1]


class _PipelineFalso:
    """Pipeline de un solo comando: `SET ... NX` + `INCR` (ventana fija)."""

    def __init__(self, redis: "FakeRedis") -> None:
        self._redis = redis
        self._clave: str | None = None

    async def __aenter__(self) -> "_PipelineFalso":
        return self

    async def __aexit__(self, exc_type, exc, tb) -> bool:
        return False

    def set(self, key, value, ex=None, nx=None) -> None:
        self._clave = key

    def incr(self, key) -> None:
        self._clave = key

    async def execute(self) -> list:
        assert self._clave is not None
        self._redis.conteos[self._clave] = self._redis.conteos.get(self._clave, 0) + 1
        return [True, self._redis.conteos[self._clave]]


class FakeRedis:
    """Redis falso que solo mantiene contadores por clave (con TTL simulado)."""

    def __init__(self) -> None:
        self.conteos: dict[str, int] = {}

    def pipeline(self, transaction: bool = True) -> _PipelineFalso:
        return _PipelineFalso(self)

    def contar(self, clave: str) -> int:
        return self.conteos.get(clave, 0)
