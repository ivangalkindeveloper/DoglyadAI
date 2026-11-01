from __future__ import annotations

import argparse
import os
import subprocess
from pathlib import Path

from dotenv import dotenv_values

from evaluation.voice.common import ROOT


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Run the protected main backend locally for the ASR/extraction experiment"
    )
    parser.add_argument("--port", type=int, default=18000)
    parser.add_argument("--endpoint-map", type=Path)
    parser.add_argument("--config-dir", type=Path)
    args = parser.parse_args()
    backend = ROOT / "backend/main"
    environment = os.environ.copy()
    for name in (".env", ".env.development"):
        environment.update(
            {key: value for key, value in dotenv_values(backend / "secrets" / name).items() if value is not None}
        )
    environment.update(
        ENVIRONMENT="development",
        MODEL_SERVICE_TYPE="inference",
        FIREBASE_CREDENTIALS_PATH=str(backend / "secrets/firebase_credentials.json"),
        INFERENCE_ENDPOINTS_PATH=str((args.endpoint_map or backend / "secrets/inference_endpoints.json").resolve()),
        LOG_DIR=str(ROOT / "build/voice-eval/asr-matrix-2026-10-24/main-logs"),
    )
    if args.config_dir:
        environment["CONFIG_DIR"] = str(args.config_dir.resolve())
    python = ROOT / ".venv311/bin/python"
    subprocess.run(
        [str(python), "-m", "uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", str(args.port)],
        cwd=backend,
        env=environment,
        check=True,
    )


if __name__ == "__main__":
    main()
