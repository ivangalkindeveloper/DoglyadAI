from __future__ import annotations

import asyncio
import logging
import smtplib
from email.message import EmailMessage

from fastapi import APIRouter, HTTPException, Request, status

from app.core.limiter import limiter
from app.core.variables import variables
from app.model.report_email import ReportEmail

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post(
    "/send_report_email",
    status_code=status.HTTP_204_NO_CONTENT,
)
@limiter.limit("30/minute")
async def send_report_email(
    body: ReportEmail,
    request: Request,
) -> None:
    del request

    # Never log the recipient, subject, or body because they may contain private data.
    logger.info(
        "Send email: body_chars=%d attachments=%d attachment_bytes=%d",
        len(body.body),
        len(body.attachments),
        sum(len(attachment.data) for attachment in body.attachments),
    )

    try:
        await asyncio.to_thread(_send_report_email, body)
    except HTTPException:
        raise
    except Exception as error:
        logger.exception("Failed to send report email")
        raise HTTPException(
            status_code=500,
            detail="Failed to send the report email",
        ) from error


def _send_report_email(body: ReportEmail) -> None:
    sender = variables.email_sender
    password = variables.email_password
    smtp_host = variables.email_smtp_host
    smtp_port = variables.email_smtp_port
    if sender is None or password is None or smtp_host is None or smtp_port is None:
        raise RuntimeError("Email service is not configured")

    message = EmailMessage()
    message["Subject"] = body.subject
    message["From"] = sender
    message["To"] = body.recipientEmail
    message.set_content(body.body, charset="utf-8")

    for attachment in body.attachments:
        maintype, subtype = attachment.mimeType.split("/", maxsplit=1)
        message.add_attachment(
            bytes(attachment.data),
            maintype=maintype,
            subtype=subtype,
            filename=attachment.fileName,
        )

    server = smtplib.SMTP(smtp_host, smtp_port)
    try:
        server.starttls()
        server.login(sender, password)
        server.sendmail(
            sender,
            body.recipientEmail,
            message.as_string(),
        )
    finally:
        server.quit()
