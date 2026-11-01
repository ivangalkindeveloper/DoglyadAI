from __future__ import annotations

from typing import Annotated

from fastapi import Depends, Request

from app.core.application.service_dependencies import ServiceDependencies
from app.core.configuration.configuration import Configuration
from app.core.http.http_header import HttpHeader
from app.core.localization.language_code import LanguageCode


class LocalizationDependencies:
    @staticmethod
    async def language(
        request: Request,
        configuration: Annotated[
            Configuration,
            Depends(
                ServiceDependencies.configuration,
            ),
        ],
    ) -> LanguageCode:
        return configuration.language(
            request.headers.get(
                HttpHeader.ACCEPT_LANGUAGE.value,
            ),
        )
