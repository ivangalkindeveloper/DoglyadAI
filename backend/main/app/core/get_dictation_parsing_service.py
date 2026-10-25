from __future__ import annotations

from fastapi import Request

from app.core.main_container import MainContainer
from app.service.dictation_parsing_service import DictationParsingService


async def get_dictation_parsing_service(request: Request) -> DictationParsingService:
    container: MainContainer = request.app.state.container
    service: DictationParsingService = container.dictation_parsing
    return service
