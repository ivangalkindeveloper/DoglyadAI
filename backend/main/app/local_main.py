from __future__ import annotations

import asyncio
from pathlib import Path

from app.core.application.local_application import LocalApplication
from app.core.configuration.variables import Variables

if __name__ == "__main__":
    asyncio.run(
        LocalApplication(
            Variables(),
            Path.home() / ".local/share/doglyad/report-generation.key",
        ).run(),
    )
