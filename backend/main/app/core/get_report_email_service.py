from __future__ import annotations

from fastapi import Request

from app.core.main_container import MainContainer
from app.service.report_email_service import ReportEmailService


async def get_report_email_service(request: Request) -> ReportEmailService:
    container: MainContainer = request.app.state.container
    service: ReportEmailService = container.report_email
    return service
