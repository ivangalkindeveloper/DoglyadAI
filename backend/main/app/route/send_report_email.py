from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, status

from app.core.get_report_email_service import get_report_email_service
from app.model.report_email import ReportEmail
from app.service.report_email_service import ReportEmailService

router = APIRouter()


@router.post("/send_report_email", status_code=status.HTTP_204_NO_CONTENT)
async def send_report_email(
    body: ReportEmail, service: Annotated[ReportEmailService, Depends(get_report_email_service)]
) -> None:
    await service.send(body)
