from __future__ import annotations

import os

# `app.core.configuration.variables` instantiates `Variables()` at import time, which requires
# ENVIRONMENT to be set (there is no default and no env_file is configured).
# Provide it so the app package can be imported under pytest without a real
# `backend/main/secrets/.env` present.
os.environ.setdefault(
    "ENVIRONMENT",
    "development",
)

import pytest
from fastapi import FastAPI

from app.core.application.application_factory import ApplicationFactory
from app.core.application.main_container import MainContainer
from app.core.configuration.configuration import Configuration
from app.core.configuration.configuration_loader import ConfigurationLoader
from app.core.configuration.variables import Variables
from app.service.configuration.configuration_response_service import ConfigurationResponseService
from app.service.dictation.dictation_parsing_service import DictationParsingService
from app.service.email.report_email_service import ReportEmailService
from app.service.neural_model.mock_neural_model_service import MockNeuralModelService
from app.service.report.report_generation_service import ReportGenerationService


@pytest.fixture
def variables() -> Variables:
    return Variables(
        environment="development",
    )


@pytest.fixture
def configuration(
    variables: Variables,
) -> Configuration:
    return ConfigurationLoader(
        variables.configuration_directory,
    ).load()


@pytest.fixture
def app(
    configuration: Configuration,
    variables: Variables,
) -> FastAPI:
    application = ApplicationFactory.create_main(
        variables,
    )
    model_service = MockNeuralModelService()
    application.state.container = MainContainer(
        configuration=configuration,
        configuration_responses=ConfigurationResponseService(
            configuration,
        ),
        model_service=model_service,
        report_generation=ReportGenerationService(
            configuration,
            model_service,
        ),
        dictation_parsing=DictationParsingService(
            configuration,
            model_service,
        ),
        report_email=ReportEmailService(
            variables,
            configuration.server.email,
            configuration.modules.userSettings,
        ),
    )
    from app.core.billing.billing_dependencies import BillingDependencies
    from tests.support.billing.unmetered_request import UnmeteredRequest

    application.dependency_overrides[BillingDependencies.report_access] = lambda: UnmeteredRequest()
    application.dependency_overrides[BillingDependencies.dictation_access] = lambda: None
    application.dependency_overrides[BillingDependencies.email_access] = lambda: None
    return application
