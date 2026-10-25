"""Check non-root startup and mounted storage using synthetic Firebase credentials."""

from __future__ import annotations

import argparse
import os
import subprocess
import tempfile
import time
from pathlib import Path

_CREDENTIAL_FIXTURE = """
import json, os
from pathlib import Path
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
root = Path('/storage')
for name in ('secrets', 'logs'):
    (root / name).mkdir()
key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
(root / 'secrets/firebase.json').write_text(json.dumps({
    'type': 'service_account', 'project_id': 'synthetic-image-check',
    'private_key_id': 'synthetic', 'client_id': '100000000000000000000',
    'client_email': 'image-check@synthetic-image-check.iam.gserviceaccount.com',
    'token_uri': 'https://oauth2.googleapis.com/token',
    'private_key': key.private_bytes(serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8, serialization.NoEncryption()).decode(),
}))
(root / 'logs/backend.log').write_text('Synthetic previous root-era log\\n')
for path in root.rglob('*'):
    os.chown(path, int(os.environ['FIXTURE_UID']), int(os.environ['FIXTURE_GID']))
"""

_STORAGE_CHECK = """
import os
from pathlib import Path
assert os.geteuid() == 10001 and os.getegid() == 10001
credential = Path('/app/secrets/firebase.json')
assert credential.read_bytes()
try:
    credential.open('a')
except OSError:
    pass
else:
    raise AssertionError('Credentials must be read-only')
with Path('/app/logs/backend.log').open('a') as log:
    log.write('Non-root storage check\\n')
"""

_AUTH_CHECK = """
import sys
from urllib.error import HTTPError
from urllib.request import ProxyHandler, Request, build_opener
path = '/v1/application_config' if sys.argv[1] == 'main' else '/v1/generation'
request = Request('http://127.0.0.1:8000' + path,
    data=None if sys.argv[1] == 'main' else b'{}',
    headers={'Content-Type': 'application/json'})
try:
    build_opener(ProxyHandler({})).open(request, timeout=2)
except HTTPError as error:
    assert error.code == 401
else:
    raise AssertionError('App Check must be enforced')
"""


def verify_backend_image(image: str, service: str) -> None:
    def docker(*args: str, input_text: str | None = None) -> str:
        result = subprocess.run(
            ["docker", *args],
            input=input_text,
            text=True,
            capture_output=True,
            timeout=60,
        )
        if result.returncode:
            raise RuntimeError("Container image check failed")
        return result.stdout.strip()

    with tempfile.TemporaryDirectory(prefix="doglyad-image-check-") as temporary:
        mount = f"type=bind,source={temporary},target=/storage"
        docker(
            "run",
            "--rm",
            "-i",
            "--network",
            "none",
            "--user",
            "0:0",
            "--mount",
            mount,
            "--env",
            f"FIXTURE_UID={os.getuid()}",
            "--env",
            f"FIXTURE_GID={os.getgid()}",
            "--entrypoint",
            "python",
            image,
            "-",
            input_text=_CREDENTIAL_FIXTURE,
        )
        docker(
            "run",
            "--rm",
            "-i",
            "--network",
            "none",
            "--user",
            "0:0",
            "--mount",
            mount,
            "--entrypoint",
            "python",
            image,
            "-",
            input_text=Path(__file__)
            .with_name("prepare_backend_storage.py")
            .read_text(),
        )
        container = docker(
            "run",
            "--rm",
            "--detach",
            "--network",
            "none",
            "--env",
            "ENVIRONMENT=development",
            "--env",
            "MODEL_SERVICE_TYPE=mock",
            "--env",
            "SERVED_MODEL_ID=example/served-model",
            "--env",
            "FIREBASE_CREDENTIALS_PATH=/app/secrets/firebase.json",
            "--env",
            "LOG_DIR=/app/logs",
            "--mount",
            f"type=bind,source={temporary}/secrets,target=/app/secrets,readonly",
            "--mount",
            f"type=bind,source={temporary}/logs,target=/app/logs",
            image,
        )
        try:
            docker("exec", container, "python", "-c", _STORAGE_CHECK)
            for _ in range(60):
                try:
                    docker("exec", container, "python", "-c", _AUTH_CHECK, service)
                    break
                except RuntimeError:
                    time.sleep(0.25)
            else:
                raise RuntimeError(
                    "Non-root backend did not start with mounted credentials and logs"
                )
        finally:
            docker("rm", "--force", container)
    print(
        f"{service}: UID/GID 10001, credential access, log writes and App Check boundary passed"
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image")
    parser.add_argument("service", choices=("main", "inference"))
    arguments = parser.parse_args()
    verify_backend_image(arguments.image, arguments.service)
