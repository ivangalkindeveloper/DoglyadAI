"""Generate private, short-lived SMTP test certificates without disabling TLS checks."""

from pathlib import Path
import subprocess

import certifi


def prepare_mail_tls(directory: Path) -> str:
    directory.mkdir(parents=True, mode=0o700, exist_ok=True)
    directory.chmod(0o700)
    key = directory / "private-key.pem"
    certificate = directory / "certificate.pem"
    subprocess.run(
        [
            "openssl",
            "req",
            "-x509",
            "-newkey",
            "rsa:2048",
            "-nodes",
            "-keyout",
            str(key),
            "-out",
            str(certificate),
            "-days",
            "2",
            "-subj",
            "/CN=mail",
            "-addext",
            "subjectAltName=DNS:mail",
            "-addext",
            "basicConstraints=critical,CA:TRUE",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=True,
    )
    key.chmod(0o600)
    (directory / "ca-bundle.pem").write_bytes(
        Path(certifi.where()).read_bytes() + b"\n" + certificate.read_bytes()
    )
    return str(directory.resolve())
