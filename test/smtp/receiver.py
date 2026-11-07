"""Local SMTP receiver: STARTTLS, authentication, attachments and one-shot failures."""

from email import policy
from email.parser import BytesParser
import hashlib
import json
from pathlib import Path
import signal
import ssl
import sys
import uuid

from aiosmtpd.controller import Controller
from aiosmtpd.smtp import AuthResult, LoginPassword

DATA = Path("/data")


class Receiver:
    async def handle_DATA(self, server, session, envelope):
        failure = DATA / "fail-next"
        if failure.exists():
            failure.unlink()
            with (DATA / "rejected.log").open("a") as log:
                log.write("451\n")
            return "451 4.3.0 Regression delivery failure"
        if not session.ssl or not session.authenticated:
            return "530 Authentication and STARTTLS required"
        identity = uuid.uuid4().hex
        (DATA / f"{identity}.eml").write_bytes(envelope.original_content)
        (DATA / f"{identity}.json").write_text(
            json.dumps(
                {"recipients": envelope.rcpt_tos, "tls": True, "authenticated": True}
            )
        )
        return "250 2.0.0 Accepted by regression receiver"


def authenticate(server, session, envelope, mechanism, credentials):
    valid = (
        isinstance(credentials, LoginPassword)
        and credentials.login == b"regression@example.invalid"
        and credentials.password == b"regression"
    )
    return AuthResult(success=valid, handled=False)


def export_messages():
    result = []
    for path in sorted(DATA.glob("*.eml"), key=lambda item: item.stat().st_mtime_ns):
        message = BytesParser(policy=policy.default).parsebytes(path.read_bytes())
        body = message.get_body(preferencelist=("plain",))
        result.append(
            {
                "id": path.stem,
                "subject": str(message["Subject"]),
                "recipient": str(message["To"]),
                "body": body.get_content() if body else "",
                "attachments": [
                    {
                        "fileName": part.get_filename(),
                        "mimeType": part.get_content_type(),
                        "size": len(part.get_payload(decode=True)),
                        "sha256": hashlib.sha256(
                            part.get_payload(decode=True)
                        ).hexdigest(),
                        "isJPEG": part.get_payload(decode=True).startswith(
                            b"\xff\xd8\xff"
                        ),
                    }
                    for part in message.iter_attachments()
                ],
                **json.loads(path.with_suffix(".json").read_text()),
            }
        )
    return result


if __name__ == "__main__":
    DATA.mkdir(exist_ok=True)
    if sys.argv[1:] == ["export"]:
        print(json.dumps(export_messages(), ensure_ascii=False))
    elif sys.argv[1:] == ["status"]:
        rejected = DATA / "rejected.log"
        print(
            json.dumps(
                {
                    "messages": export_messages(),
                    "rejectedCount": len(rejected.read_text().splitlines())
                    if rejected.exists()
                    else 0,
                    "pendingFailure": (DATA / "fail-next").exists(),
                },
                ensure_ascii=False,
            )
        )
    elif sys.argv[1:] == ["fail-next"]:
        (DATA / "fail-next").touch()
    else:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain("/tls/certificate.pem", "/tls/private-key.pem")
        controller = Controller(
            Receiver(),
            hostname="0.0.0.0",
            port=1025,
            tls_context=context,
            require_starttls=True,
            auth_required=True,
            authenticator=authenticate,
        )
        controller.start()
        signal.pause()
