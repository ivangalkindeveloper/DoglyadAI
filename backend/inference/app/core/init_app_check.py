from __future__ import annotations

import firebase_admin
from firebase_admin import credentials

from app.core.variables import variables
from app.core.verify_app_check import logger


def init_app_check() -> None:
    """Initializes the Firebase Admin SDK for verifying App Check tokens.

    Called once at application startup. Verification cannot be switched off, so a
    missing `FIREBASE_CREDENTIALS_PATH` raises `RuntimeError` and startup aborts —
    the service must never come up in a state where it answers unverified callers.
    """
    if firebase_admin._apps:
        logger.warning("Firebase Admin SDK is already initialized")
        return
    if not variables.firebase_credentials_path:
        raise RuntimeError("FIREBASE_CREDENTIALS_PATH is not set")
    credential = credentials.Certificate(str(variables.firebase_credentials_path))
    firebase_admin.initialize_app(credential)
