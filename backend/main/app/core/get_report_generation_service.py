from __future__ import annotations

from fastapi import Request

from app.core.main_container import MainContainer
from app.service.report_generation_service import ReportGenerationService


async def get_report_generation_service(request: Request) -> ReportGenerationService:
    container: MainContainer = request.app.state.container
    service: ReportGenerationService = container.report_generation
    return service
