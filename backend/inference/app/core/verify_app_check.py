from __future__ import annotations

import asyncio
import logging

from fastapi import Header, HTTPException, status
from firebase_admin import app_check

from app.core.http_header import HttpHeader

logger = logging.getLogger(__name__)

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
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing App Check token",
        )
    try:
        await asyncio.to_thread(app_check.verify_token, x_firebase_app_check)
    except ValueError as error:
        logger.warning("Invalid App Check token: %s", error)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid App Check token",
        ) from error
