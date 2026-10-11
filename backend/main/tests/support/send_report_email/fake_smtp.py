from __future__ import annotations


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
