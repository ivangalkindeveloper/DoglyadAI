from __future__ import annotations

import ssl


class FakeSMTP:
    instance: FakeSMTP | None = None

    def __init__(self, host: str, port: int, timeout: float) -> None:
        self.host = host
        self.port = port
        self.timeout = timeout
        self.context: ssl.SSLContext | None = None
        self.login_arguments: tuple[str, str] | None = None
        self.message: str | None = None
        self.is_quit_called = False
        self.is_closed = False
        FakeSMTP.instance = self

    def starttls(self, *, context: ssl.SSLContext) -> None:
        self.context = context

    def login(self, sender: str, password: str) -> None:
        self.login_arguments = (sender, password)

    def sendmail(self, sender: str, recipient: str, message: str) -> None:
        assert sender == "sender@example.com"
        assert recipient == "recipient@example.com"
        self.message = message

    def quit(self) -> None:
        self.is_quit_called = True

    def close(self) -> None:
        self.is_closed = True
