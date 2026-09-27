from __future__ import annotations

from enum import StrEnum


class HttpHeader(StrEnum):
    ACCEPT_LANGUAGE = "Accept-Language"
    CONTENT_LANGUAGE = "Content-Language"
    VARY = "Vary"
    FIREBASE_APP_CHECK = "X-Firebase-AppCheck"
    REQUEST_ID = "X-Request-ID"
