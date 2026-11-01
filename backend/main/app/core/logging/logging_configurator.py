from __future__ import annotations

import logging
import sys
from logging.handlers import TimedRotatingFileHandler

from app.core.configuration.variables import Variables
from app.core.logging.request_id_log_filter import RequestIdLogFilter


class LoggingConfigurator:
    FORMAT = "%(asctime)s %(levelname)s %(name)s request_id=%(request_id)s: %(message)s"

    @classmethod
    def configure(
        cls,
        variables: Variables,
    ) -> None:
        """Configures stdout output and, when LOG_DIR is set, daily file rotation.

        Logs never contain patient data — only technical metadata, so long
        retention is safe.
        """
        handlers: list[logging.Handler] = [
            logging.StreamHandler(
                sys.stdout,
            )
        ]

        if variables.log_dir:
            variables.log_dir.mkdir(
                parents=True,
                exist_ok=True,
            )
            file_handler = TimedRotatingFileHandler(
                filename=variables.log_dir / "backend.log",
                when="midnight",
                interval=1,
                backupCount=variables.log_retention_days,
                encoding="utf-8",
                utc=True,
            )
            # Files are named like backend.log.2026-08-01.
            file_handler.suffix = "%Y-%m-%d"
            handlers.append(
                file_handler,
            )

        formatter = logging.Formatter(
            cls.FORMAT,
        )
        root = logging.getLogger()
        root.handlers.clear()
        root.setLevel(
            logging.INFO,
        )
        for handler in handlers:
            handler.setFormatter(
                formatter,
            )
            handler.addFilter(
                RequestIdLogFilter(),
            )
            root.addHandler(
                handler,
            )
