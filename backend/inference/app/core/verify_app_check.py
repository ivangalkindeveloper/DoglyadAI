from __future__ import annotations

import asyncio

from fastapi import Header
from firebase_admin import app_check

from app.core.http_header import HttpHeader
from app.error import InvalidAppCheckTokenError, MissingAppCheckTokenError

APP_CHECK_HEADER = HttpHeader.FIREBASE_APP_CHECK.value


async def verify_app_check(
    x_firebase_app_check: str | None = Header(default=None, alias=APP_CHECK_HEADER),
) -> None:
    """Verifies the App Check token from the `X-Firebase-AppCheck` header.

    The token is minted by the app instance and relayed unchanged by the backend,
    so verifying it here confirms the whole chain originates from a genuine app
    instance rather than from anyone who happens to know this VM's address.
    Raises 401 when the token is missing or fails verification.
    """
    if not x_firebase_app_check:
        raise MissingAppCheckTokenError()
    try:
        await asyncio.to_thread(app_check.verify_token, x_firebase_app_check)
    except ValueError as error:
        raise InvalidAppCheckTokenError() from error
