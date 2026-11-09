from __future__ import annotations

import asyncio
import smtplib
import ssl
from email import policy
from email.parser import Parser
from unittest.mock import patch

import pytest

from app.core.configuration.configuration import Configuration
from app.core.configuration.variables import Variables
from app.error import ApiError
from app.model.report_email import ReportEmail
from app.service.email.report_email_service import ReportEmailService
from tests.support.send_report_email.fake_smtp import FakeSMTP


@pytest.fixture
def service(
    variables: Variables,
    configuration: Configuration,
    monkeypatch: pytest.MonkeyPatch,
) -> ReportEmailService:
    monkeypatch.setattr(
        variables,
        "email_sender",
        "sender@example.com",
    )
    monkeypatch.setattr(
        variables,
        "email_password",
        "password",
    )
    monkeypatch.setattr(
        variables,
        "email_smtp_host",
        "smtp.example.com",
    )
    monkeypatch.setattr(
        variables,
        "email_smtp_port",
        587,
    )
    monkeypatch.setattr(
        "app.service.email.report_email_service.smtplib.SMTP",
        FakeSMTP,
    )
    return ReportEmailService(
        variables,
        configuration.server.email,
        configuration.modules.workSettings,
    )


@pytest.fixture
def body() -> ReportEmail:
    return ReportEmail.model_validate(
        {
            "recipientEmail": "recipient@example.com",
            "subject": "Ultrasound report",
            "body": "Report body",
            "attachments": [{"fileName": "ultrasound-1.jpg", "mimeType": "image/jpeg", "data": "c2Nhbi1pbWFnZQ=="}],
        },
    )


def test_send_report_email_adds_binary_attachments_with_verified_tls_and_timeout(
    service: ReportEmailService,
    body: ReportEmail,
    configuration: Configuration,
) -> None:
    asyncio.run(
        service.send(
            body,
        ),
    )
    smtp = FakeSMTP.instance
    assert smtp is not None
    assert (smtp.host, smtp.port) == ("smtp.example.com", 587)
    assert smtp.timeout == configuration.server.email.socket_timeout_seconds
    assert smtp.context is not None
    assert smtp.context.verify_mode == ssl.CERT_REQUIRED
    assert smtp.context.check_hostname
    assert smtp.login_arguments == ("sender@example.com", "password")
    assert smtp.message is not None
    assert smtp.is_quit_called
    message = Parser(
        policy=policy.default,
    ).parsestr(
        smtp.message,
    )
    assert (
        message.get_body(
            preferencelist=("plain",),
        )
        .get_content()
        .strip()
        == "Report body"
    )
    attachments = list(
        message.iter_attachments(),
    )
    assert (
        len(
            attachments,
        )
        == 1
    )
    assert attachments[0].get_filename() == "ultrasound-1.jpg"
    assert attachments[0].get_content_type() == "image/jpeg"
    assert (
        attachments[0].get_payload(
            decode=True,
        )
        == b"scan-image"
    )


def test_quit_failure_does_not_turn_accepted_email_into_failure(
    service: ReportEmailService,
    body: ReportEmail,
) -> None:
    with patch.object(
        FakeSMTP,
        "quit",
        side_effect=smtplib.SMTPServerDisconnected(
            "disconnected",
        ),
    ):
        asyncio.run(
            service.send(
                body,
            ),
        )
    assert FakeSMTP.instance is not None
    assert FakeSMTP.instance.message is not None
    assert FakeSMTP.instance.is_closed


def test_smtp_failure_does_not_log_recipient_or_remote_reply(
    service: ReportEmailService,
    body: ReportEmail,
    caplog: pytest.LogCaptureFixture,
) -> None:
    error = smtplib.SMTPRecipientsRefused(
        {body.recipientEmail: (550, b"Sensitive remote reply")},
    )
    with (
        patch.object(
            FakeSMTP,
            "sendmail",
            side_effect=error,
        ),
        pytest.raises(
            ApiError,
        ) as raised,
    ):
        asyncio.run(
            service.send(
                body,
            ),
        )
    assert raised.value.status_code == 500
    assert body.recipientEmail not in caplog.text
    assert "Sensitive remote reply" not in caplog.text
    assert all(
        (record.exc_info is None for record in caplog.records),
    )


def test_oversized_attachment_is_rejected_before_smtp(
    service: ReportEmailService,
    body: ReportEmail,
    configuration: Configuration,
) -> None:
    body.attachments[0].data = b"x" * (configuration.server.email.max_attachment_bytes + 1)
    with (
        patch(
            "app.service.email.report_email_service.smtplib.SMTP",
        ) as smtp,
        pytest.raises(
            ApiError,
        ) as raised,
    ):
        asyncio.run(
            service.send(
                body,
            ),
        )
    assert raised.value.status_code == 413
    smtp.assert_not_called()
