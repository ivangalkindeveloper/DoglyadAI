from __future__ import annotations

from contextlib import AbstractAsyncContextManager
from types import TracebackType


class UnmeteredRequest(AbstractAsyncContextManager[None]):
    """Only for existing report tests. Billing tests use the real guard and database."""

    async def __aenter__(
        self,
    ) -> None:
        return None

    async def __aexit__(
        self,
        exc_type: type[BaseException] | None,
        exc_value: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        return None
