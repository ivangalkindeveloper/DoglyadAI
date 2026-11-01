from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from app.error import InferenceBusyError
from app.model.generation_config import GenerationConfig


class GenerationCapacity:
    """Bound both running requests and queue length in this inference worker."""

    def __init__(
        self,
        config: GenerationConfig,
    ) -> None:
        self._config = config
        self._semaphore = asyncio.BoundedSemaphore(
            config.max_concurrent_requests,
        )
        self._requests = 0

    @asynccontextmanager
    async def slot(
        self,
    ) -> AsyncIterator[None]:
        if self._requests >= self._config.max_concurrent_requests + self._config.max_waiting_requests:
            raise InferenceBusyError(
                self._config.retry_after_seconds,
            )
        self._requests += 1
        try:
            try:
                await asyncio.wait_for(
                    self._semaphore.acquire(),
                    timeout=self._config.queue_timeout_seconds,
                )
            except TimeoutError as error:
                raise InferenceBusyError(
                    self._config.retry_after_seconds,
                ) from error
            try:
                yield
            finally:
                self._semaphore.release()
        finally:
            self._requests -= 1
