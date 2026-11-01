from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, status

from app.core.application.service_dependencies import ServiceDependencies
from app.core.billing.billing_dependencies import BillingDependencies
from app.model.report_email import ReportEmail
from app.service.email.report_email_service import ReportEmailService

router = APIRouter(
    dependencies=[
        Depends(
            BillingDependencies.email_access,
        )
    ],
)


@router.post(
    "/send_report_email",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def send_report_email(
    body: ReportEmail,
    service: Annotated[
        ReportEmailService,
        Depends(
            ServiceDependencies.report_email,
        ),
    ],
) -> None:
    await service.send(
        body,
    )
