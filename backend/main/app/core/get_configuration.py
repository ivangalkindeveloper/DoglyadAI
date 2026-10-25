from __future__ import annotations

from fastapi import Request

from app.core.configuration import Configuration
from app.core.main_container import MainContainer


async def get_configuration(request: Request) -> Configuration:
    container: MainContainer = request.app.state.container
    service: Configuration = container.configuration
    return service
