from __future__ import annotations

import asyncio
import logging

import firebase_admin
from fastapi import Header, HTTPException, status
from firebase_admin import app_check, credentials

from app.core.http_header import HttpHeader
from app.core.variables import variables

logger = logging.getLogger(__name__)

APP_CHECK_HEADER = HttpHeader.FIREBASE_APP_CHECK.value


def init_app_check() -> None:
    """Initializes the Firebase Admin SDK for verifying App Check tokens.

    Called once at application startup. Verification cannot be switched off in
    any environment, so a missing `FIREBASE_CREDENTIALS_PATH` raises
    `RuntimeError` and startup aborts — the backend must never come up in a state
    where it answers unverified callers.
    """
    if firebase_admin._apps:
        logger.warning("Firebase Admin SDK is already initialized")
        return
    if not variables.firebase_credentials_path:
        raise RuntimeError("FIREBASE_CREDENTIALS_PATH is not set")
    credential = credentials.Certificate(str(variables.firebase_credentials_path))
    firebase_admin.initialize_app(credential)


async def verify_app_check(
    x_firebase_app_check: str | None = Header(default=None, alias=APP_CHECK_HEADER),
) -> None:
    """Verifies the App Check token from the `X-Firebase-AppCheck` header.

    This is the edge of the system: requests arrive here from the internet, so
    rejecting them here keeps an unverified caller away from everything behind it,
    including the GPU VMs and the SMTP credentials used by the email route. The
    inference VM verifies the same token again because it is independently
    reachable over the network.

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
