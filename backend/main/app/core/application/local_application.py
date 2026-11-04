from __future__ import annotations

import asyncio
import os
from pathlib import Path
from urllib.parse import urlsplit

import uvicorn
from cryptography.fernet import Fernet

from app.core.application.application_factory import ApplicationFactory
from app.core.configuration.variables import Variables
from app.core.logging.logging_configurator import LoggingConfigurator
from app.service.report.report_generation_worker import ReportGenerationWorker


class LocalApplication:
    """Start the local API and its report worker with the same persistent key."""

    def __init__(
        self,
        variables: Variables,
        key_path: Path,
    ) -> None:
        self._variables = variables
        self._key_path = key_path

    def prepare(
        self,
    ) -> Variables:
        database = urlsplit(
            self._variables.billing_database_url or "",
        )
        if self._variables.environment != "development" or database.hostname not in {"127.0.0.1", "localhost", "::1"}:
            raise ValueError(
                "The local launcher requires development configuration and a loopback database",
            )
        key = self._variables.report_generation_encryption_key
        if not key:
            self._key_path.parent.mkdir(
                parents=True,
                exist_ok=True,
                mode=0o700,
            )
            try:
                descriptor = os.open(
                    self._key_path,
                    os.O_WRONLY | os.O_CREAT | os.O_EXCL,
                    0o600,
                )
            except FileExistsError:
                key = self._key_path.read_text().strip()
            else:
                with os.fdopen(
                    descriptor,
                    "w",
                ) as output:
                    key = Fernet.generate_key().decode()
                    output.write(
                        key,
                    )
        Fernet(
            key.encode(),
        )
        os.environ["REPORT_GENERATION_ENCRYPTION_KEY"] = key
        return self._variables.model_copy(
            update={"report_generation_encryption_key": key},
        )

    async def run(
        self,
    ) -> None:
        variables = self.prepare()
        LoggingConfigurator.configure(
            variables,
        )
        application = ApplicationFactory.create_main()
        server = uvicorn.Server(
            uvicorn.Config(
                application,
                host="0.0.0.0",
                port=8000,
            ),
        )
        api = asyncio.create_task(
            server.serve(),
        )
        worker = asyncio.create_task(
            ReportGenerationWorker(
                variables,
            ).run(),
        )
        try:
            done, _ = await asyncio.wait(
                {api, worker},
                return_when=asyncio.FIRST_COMPLETED,
            )
            for task in done:
                task.result()
        finally:
            server.should_exit = True
            worker.cancel()
            await asyncio.gather(
                worker,
                return_exceptions=True,
            )
            await api
