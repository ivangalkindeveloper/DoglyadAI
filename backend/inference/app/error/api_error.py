from __future__ import annotations

from typing import ClassVar


class ApiError(Exception):
    """An expected API failure. Public descriptions contain no request or provider data."""

    code: ClassVar[str] = "internalServerError"
    description: ClassVar[str] = "Internal server error"
    status_code: int = 500

    def __init__(
        self,
    ) -> None:
        super().__init__(
            self.description,
        )

    @property
    def headers(
        self,
    ) -> dict[str, str] | None:
        return None
