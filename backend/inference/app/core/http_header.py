from __future__ import annotations

from enum import StrEnum


class HttpHeader(StrEnum):
    FIREBASE_APP_CHECK = "X-Firebase-AppCheck"
    REQUEST_ID = "X-Request-ID"
