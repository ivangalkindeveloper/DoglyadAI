from __future__ import annotations

from typing import Annotated

from fastapi import Depends, Request

from app.core.configuration import Configuration
from app.core.get_configuration import get_configuration
from app.core.http_header import HttpHeader
from app.core.language_code import LanguageCode


async def get_request_language(
    request: Request, configuration: Annotated[Configuration, Depends(get_configuration)]
) -> LanguageCode:
    return configuration.language(request.headers.get(HttpHeader.ACCEPT_LANGUAGE.value))
