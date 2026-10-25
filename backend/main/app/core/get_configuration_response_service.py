from __future__ import annotations

from fastapi import Request

from app.core.main_container import MainContainer
from app.service.configuration_response_service import ConfigurationResponseService


async def get_configuration_response_service(request: Request) -> ConfigurationResponseService:
    container: MainContainer = request.app.state.container
    service: ConfigurationResponseService = container.configuration_responses
    return service
