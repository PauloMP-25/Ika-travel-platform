import pytest
from unittest.mock import MagicMock
from fastapi import Request
from redis.exceptions import RedisError

from src.core.rate_limit import limit_requests
from src.core.exceptions import RateLimitExceededException
from tests.conftest import run


class FakeRedisPipeline:
    def __init__(self, counts):
        self._counts = counts
        self._calls = 0

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        pass

    def set(self, key, val, ex=None, nx=None):
        pass

    def incr(self, key):
        pass

    async def execute(self):
        self._calls += 1
        return [True, self._counts[self._calls - 1]]


class FakeRedis:
    def __init__(self, sequence):
        self._sequence = sequence

    def pipeline(self, transaction=True):
        return FakeRedisPipeline(self._sequence)


def test_rate_limit_allows_under_maximum():
    """A-23: Solicitudes dentro del límite se permiten."""
    limiter = limit_requests("test", maximum=2, window_seconds=60)
    fake_redis = FakeRedis([1, 2])

    request = MagicMock(spec=Request)
    request.client.host = "192.168.1.1"

    # Primera llamada: count 1 <= 2 -> OK
    run(limiter(request, redis_client=fake_redis))
    # Segunda llamada: count 2 <= 2 -> OK
    run(limiter(request, redis_client=fake_redis))


def test_rate_limit_raises_when_exceeded():
    """A-23: Solicitud por encima del límite lanza RateLimitExceededException."""
    limiter = limit_requests("test", maximum=2, window_seconds=60)
    fake_redis = FakeRedis([3])

    request = MagicMock(spec=Request)
    request.client.host = "192.168.1.1"

    with pytest.raises(RateLimitExceededException) as exc_info:
        run(limiter(request, redis_client=fake_redis))
    assert exc_info.value.codigo == "LIMITE_SOLICITUDES_EXCEDIDO"
    assert exc_info.value.codigo_http == 429


def test_rate_limit_fails_open_on_redis_error():
    """A-23: Si Redis falla, el rate limiter falla abierto (no interrumpe al usuario)."""
    limiter = limit_requests("test", maximum=2, window_seconds=60)

    class FailingRedis:
        def pipeline(self, transaction=True):
            raise RedisError("Connection refused")

    request = MagicMock(spec=Request)
    request.client.host = "192.168.1.1"

    # No debe levantar excepción
    run(limiter(request, redis_client=FailingRedis()))
