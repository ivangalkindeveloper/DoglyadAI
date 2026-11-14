from __future__ import annotations

import asyncio
import logging

import firebase_admin
from fastapi import Header
from firebase_admin import app_check, credentials

from app.core.configuration.variables import Variables
from app.core.http.http_header import HttpHeader
from app.error import InvalidAppCheckTokenError, MissingAppCheckTokenError

logger = logging.getLogger(
    __name__,
)


class AppCheck:
    HEADER = HttpHeader.FIREBASE_APP_CHECK.value

    def __init__(
        self,
    ) -> None:
        pass

    @staticmethod
    def initialize(
        variables: Variables,
    ) -> None:
        if firebase_admin._apps:
            logger.warning(
                "Firebase Admin SDK is already initialized",
            )
            return
        if not variables.firebase_credentials_path:
            raise RuntimeError(
                "FIREBASE_CREDENTIALS_PATH is not set",
            )
        credential = credentials.Certificate(
            str(
                variables.firebase_credentials_path,
            ),
        )
        firebase_admin.initialize_app(
            credential,
        )

    @staticmethod
    async def verify(
        x_firebase_app_check: str | None = Header(
            default=None,
            alias=HttpHeader.FIREBASE_APP_CHECK.value,
        ),
    ) -> None:
        if not x_firebase_app_check:
            raise MissingAppCheckTokenError()
        try:
            await asyncio.to_thread(
                app_check.verify_token,
                x_firebase_app_check,
            )
        except ValueError as error:
            raise InvalidAppCheckTokenError() from error
