from __future__ import annotations

from app.core.application.application_factory import ApplicationFactory
from app.core.logging.logging_configurator import LoggingConfigurator

app = ApplicationFactory.create_payment()
LoggingConfigurator.configure(
    app.state.variables,
)
