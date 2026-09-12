from __future__ import annotations

from pydantic import BaseModel, Field

from app.model.report_email_attachment import ReportEmailAttachment


class ReportEmail(BaseModel):
    recipientEmail: str
    subject: str
    body: str
    attachments: list[ReportEmailAttachment] = Field(default_factory=list)
