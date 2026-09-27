from __future__ import annotations

import logging
from collections.abc import Callable

from fastapi import Request, Response

from app.core.http_header import HttpHeader
from app.core.language_code import LanguageCode
from app.core.locale import resolve_language

logger = logging.getLogger(__name__)


def config_document_response(request: Request, resolve_document: Callable[[LanguageCode], str]) -> Response:
    """Return the selected language of a configured document."""
    language = resolve_language(request.headers.get(HttpHeader.ACCEPT_LANGUAGE.value))
    logger.info("Config document served: %s", request.url.path)
    return Response(
        content=resolve_document(language),
        media_type="application/json",
        headers={
            HttpHeader.CONTENT_LANGUAGE.value: language.value,
            HttpHeader.VARY.value: HttpHeader.ACCEPT_LANGUAGE.value,
        },
    )
