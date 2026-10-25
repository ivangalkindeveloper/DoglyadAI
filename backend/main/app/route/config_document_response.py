from __future__ import annotations

from fastapi import Response

from app.core.http_header import HttpHeader
from app.core.language_code import LanguageCode


def config_document_response(content: str, language: LanguageCode) -> Response:
    return Response(
        content=content,
        media_type="application/json",
        headers={
            HttpHeader.CONTENT_LANGUAGE.value: language.value,
            HttpHeader.VARY.value: HttpHeader.ACCEPT_LANGUAGE.value,
        },
    )
