from __future__ import annotations

from email import policy
from email.parser import Parser

import pytest

from app.core.variables import variables
from app.model.report_email import ReportEmail
from app.route import send_report_email as route


class FakeSMTP:
    instance: FakeSMTP | None = None

    def __init__(self, host: str, port: int) -> None:
        self.host = host
        self.port = port
        self.login_arguments: tuple[str, str] | None = None
        self.message: str | None = None
        self.quit_called = False
        FakeSMTP.instance = self

    def starttls(self) -> None:
        return None

    def login(self, sender: str, password: str) -> None:
        self.login_arguments = (sender, password)

    def sendmail(self, sender: str, recipient: str, message: str) -> None:
        assert sender == "sender@example.com"
        assert recipient == "recipient@example.com"
        self.message = message

    def quit(self) -> None:
        self.quit_called = True


def test_send_report_email_adds_binary_attachments(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(variables, "email_sender", "sender@example.com")
    monkeypatch.setattr(variables, "email_password", "password")
    monkeypatch.setattr(variables, "email_smtp_host", "smtp.example.com")
    monkeypatch.setattr(variables, "email_smtp_port", 587)
    monkeypatch.setattr(route.smtplib, "SMTP", FakeSMTP)

    body = ReportEmail.model_validate(
        {
            "recipientEmail": "recipient@example.com",
            "subject": "Ultrasound report",
            "body": "Report body",
            "attachments": [
                {
                    "fileName": "ultrasound-1.jpg",
                    "mimeType": "image/jpeg",
                    "data": "c2Nhbi1pbWFnZQ==",
                }
            ],
        }
    )

    route._send_report_email(body)

    smtp = FakeSMTP.instance
    assert smtp is not None
    assert smtp.host == "smtp.example.com"
    assert smtp.port == 587
    assert smtp.login_arguments == ("sender@example.com", "password")
    assert smtp.message is not None
    assert smtp.quit_called is True

    message = Parser(policy=policy.default).parsestr(smtp.message)
    assert message.get_body(preferencelist=("plain",)).get_content().strip() == "Report body"
    attachments = list(message.iter_attachments())
    assert len(attachments) == 1
    assert attachments[0].get_filename() == "ultrasound-1.jpg"
    assert attachments[0].get_content_type() == "image/jpeg"
    assert attachments[0].get_payload(decode=True) == b"scan-image"
