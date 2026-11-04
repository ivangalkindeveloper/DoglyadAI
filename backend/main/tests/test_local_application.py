from __future__ import annotations

import asyncio
import os
from pathlib import Path
from unittest.mock import AsyncMock, patch

import pytest
from cryptography.fernet import Fernet

from app.core.application.local_application import LocalApplication
from app.core.configuration.variables import Variables


def test_local_key_survives_restart_and_is_private(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv(
        "REPORT_GENERATION_ENCRYPTION_KEY",
        "",
    )
    variables = Variables(
        environment="development",
        billing_database_url="postgresql+asyncpg://local@127.0.0.1:5433/billing",
    )
    path = tmp_path / "private" / "report.key"
    first = LocalApplication(
        variables,
        path,
    ).prepare()
    token = Fernet(
        first.report_generation_encryption_key.encode(),
    ).encrypt(
        b"synthetic",
    )
    second = LocalApplication(
        variables,
        path,
    ).prepare()
    assert (
        Fernet(
            second.report_generation_encryption_key.encode(),
        ).decrypt(
            token,
        )
        == b"synthetic"
    )
    assert os.environ["REPORT_GENERATION_ENCRYPTION_KEY"] == second.report_generation_encryption_key
    assert path.stat().st_mode & 0o777 == 0o600


@pytest.mark.parametrize(
    "environment,url",
    [
        ("production", "postgresql://localhost/billing"),
        ("development", "postgresql://remote.example/billing"),
        ("development", ""),
    ],
)
def test_local_launcher_rejects_nonlocal_configuration(
    tmp_path: Path,
    environment: str,
    url: str,
) -> None:
    variables = Variables.model_validate(
        {"environment": environment, "billing_database_url": url},
    )
    path = tmp_path / "report.key"
    with pytest.raises(
        ValueError,
        match="loopback",
    ):
        LocalApplication(
            variables,
            path,
        ).prepare()
    assert not path.exists()


def test_stopping_api_stops_local_worker(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv(
        "REPORT_GENERATION_ENCRYPTION_KEY",
        "",
    )
    variables = Variables(
        environment="development",
        billing_database_url="postgresql+asyncpg://local@127.0.0.1:5433/billing",
    )

    async def run() -> None:
        started = asyncio.Event()
        stopped = asyncio.Event()

        async def worker_run() -> None:
            started.set()
            try:
                await asyncio.Event().wait()
            finally:
                stopped.set()

        async def api_run() -> None:
            await started.wait()

        with (
            patch(
                "app.core.application.local_application.ApplicationFactory.create_main",
            ),
            patch(
                "app.core.application.local_application.LoggingConfigurator.configure",
            ),
            patch(
                "app.core.application.local_application.uvicorn.Server",
            ) as server,
            patch(
                "app.core.application.local_application.ReportGenerationWorker.run",
                side_effect=worker_run,
            ) as worker,
        ):
            server.return_value.serve = AsyncMock(
                side_effect=api_run,
            )
            await LocalApplication(
                variables,
                tmp_path / "key",
            ).run()
            worker.assert_awaited_once()
            assert stopped.is_set()
            assert server.return_value.should_exit

    asyncio.run(
        run(),
    )
