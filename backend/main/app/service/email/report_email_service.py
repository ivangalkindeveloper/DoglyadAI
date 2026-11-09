from __future__ import annotations

import asyncio
import logging
import smtplib
import ssl
from contextlib import suppress
from email.message import EmailMessage

from app.core.configuration.variables import Variables
from app.error import (
    AttachmentsTooLargeError,
    AttachmentTooLargeError,
    ReportEmailSendError,
    ServiceNotConfiguredError,
    TooManyAttachmentsError,
)
from app.model.email_config import EmailConfig
from app.model.report_email import ReportEmail
from app.model.work_settings_config import WorkSettingsConfig
from app.service.validation.text_length_validator import TextLengthValidator

logger = logging.getLogger(
    __name__,
)


class ReportEmailService:
    def __init__(
        self,
        variables: Variables,
        config: EmailConfig,
        work_settings: WorkSettingsConfig,
    ) -> None:
        self._variables = variables
        self._config = config
        self._work_settings = work_settings

    async def send(
        self,
        body: ReportEmail,
    ) -> None:
        TextLengthValidator.validate(
            body.recipientEmail,
            self._work_settings.emailMaxLength,
            ["body", "recipientEmail"],
        )
        sizes = [
            len(
                attachment.data,
            )
            for attachment in body.attachments
        ]
        if (
            len(
                sizes,
            )
            > self._config.max_attachments
        ):
            raise TooManyAttachmentsError()
        if any(
            (size > self._config.max_attachment_bytes for size in sizes),
        ):
            raise AttachmentTooLargeError()
        if (
            sum(
                sizes,
            )
            > self._config.max_total_attachment_bytes
        ):
            raise AttachmentsTooLargeError()
        logger.info(
            "Send email: body_chars=%d attachments=%d attachment_bytes=%d",
            len(
                body.body,
            ),
            len(
                sizes,
            ),
            sum(
                sizes,
            ),
        )
        try:
            await asyncio.to_thread(
                self._send,
                body,
            )
        except (OSError, smtplib.SMTPException) as error:
            raise ReportEmailSendError() from error

    def _send(
        self,
        body: ReportEmail,
    ) -> None:
        sender = self._variables.email_sender
        password = self._variables.email_password
        host = self._variables.email_smtp_host
        port = self._variables.email_smtp_port
        if sender is None or password is None or host is None or port is None:
            raise ServiceNotConfiguredError()
        message = EmailMessage()
        message["Subject"] = body.subject
        message["From"] = sender
        message["To"] = body.recipientEmail
        message.set_content(
            body.body,
            charset="utf-8",
        )
        for attachment in body.attachments:
            maintype, subtype = attachment.mimeType.split(
                "/",
                maxsplit=1,
            )
            message.add_attachment(
                bytes(
                    attachment.data,
                ),
                maintype=maintype,
                subtype=subtype,
                filename=attachment.fileName,
            )
        server = smtplib.SMTP(
            host,
            port,
            timeout=self._config.socket_timeout_seconds,
        )
        try:
            server.starttls(
                context=ssl.create_default_context(),
            )
            server.login(
                sender,
                password,
            )
            server.sendmail(
                sender,
                body.recipientEmail,
                message.as_string(),
            )
        finally:
            try:
                server.quit()
            except (OSError, smtplib.SMTPException):
                # Failure to end the session does not undo an accepted message.
                with suppress(
                    OSError,
                    smtplib.SMTPException,
                ):
                    server.close()
