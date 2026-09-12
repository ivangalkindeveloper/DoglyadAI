from __future__ import annotations

import logging
import sys
from logging.handlers import TimedRotatingFileHandler

from app.core.variables import variables

_FORMAT = "%(asctime)s %(levelname)s %(name)s: %(message)s"


def setup_logging() -> None:
    """Configures stdout output and, when LOG_DIR is set, daily file rotation.

    Logs contain only technical metadata and never request payloads, so long
    retention is safe.
    """
    handlers: list[logging.Handler] = [logging.StreamHandler(sys.stdout)]

    if variables.log_dir:
        variables.log_dir.mkdir(parents=True, exist_ok=True)
        file_handler = TimedRotatingFileHandler(
            filename=variables.log_dir / "inference_backend.log",
            when="midnight",
            interval=1,
            backupCount=variables.log_retention_days,
            encoding="utf-8",
            utc=True,
        )
        # Files are named like inference_backend.log.2026-08-01.
        file_handler.suffix = "%Y-%m-%d"
        handlers.append(file_handler)

    formatter = logging.Formatter(_FORMAT)
    root = logging.getLogger()
    root.handlers.clear()
    root.setLevel(logging.INFO)
    for handler in handlers:
        handler.setFormatter(formatter)
        root.addHandler(handler)
