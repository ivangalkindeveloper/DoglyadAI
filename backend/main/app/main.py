from __future__ import annotations

from app.core.create_app import create_app
from app.core.setup_logging import setup_logging

app = create_app()
setup_logging(app.state.variables)
