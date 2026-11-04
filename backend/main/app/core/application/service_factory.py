from __future__ import annotations

import httpx

from app.core.application.main_container import MainContainer
from app.core.configuration.configuration import Configuration
from app.core.configuration.variables import Variables
from app.database.billing_database import BillingDatabase
from app.service.billing.apple_subscription_verifier import AppleSubscriptionVerifier
from app.service.billing.sdk_payment_service import SDKPaymentService
from app.service.billing.subscription_service import SubscriptionService
from app.service.billing.yookassa_payment_provider import YooKassaPaymentProvider
from app.service.configuration.configuration_response_service import ConfigurationResponseService
from app.service.dictation.dictation_parsing_service import DictationParsingService
from app.service.email.report_email_service import ReportEmailService
from app.service.neural_model.neural_model_service_factory import NeuralModelServiceFactory
from app.service.report.report_generation_cipher import ReportGenerationCipher
from app.service.report.report_generation_jobs import ReportGenerationJobs
from app.service.report.report_generation_service import ReportGenerationService
from app.service.report.report_generation_store import ReportGenerationStore


class ServiceFactory:
    """Assemble services around resources owned by the calling process's lifespan."""

    def __init__(
        self,
        http_client: httpx.AsyncClient,
        configuration: Configuration,
        variables: Variables,
    ) -> None:
        self._http_client = http_client
        self._configuration = configuration
        self._variables = variables

    def create_subscriptions(
        self,
        database: BillingDatabase,
    ) -> SubscriptionService:
        config = self._configuration.server.billing.provider
        return SubscriptionService(
            database,
            self._configuration,
            self._variables,
            YooKassaPaymentProvider(
                self._http_client,
                self._variables,
                config,
            ),
            AppleSubscriptionVerifier(
                self._http_client,
                self._variables,
                config,
            ),
        )

    def create_main_container(
        self,
        subscriptions: SubscriptionService | None,
    ) -> MainContainer:
        configuration = self._configuration
        variables = self._variables
        model_service = NeuralModelServiceFactory.create(
            self._http_client,
            configuration.neural_models.values(),
            variables,
            configuration.server.inference,
        )
        reports = ReportGenerationService(
            configuration,
            model_service,
        )
        jobs = None
        if subscriptions is not None and variables.report_generation_encryption_key:
            jobs = ReportGenerationJobs(
                ReportGenerationStore(
                    subscriptions.database,
                    ReportGenerationCipher(
                        variables.report_generation_encryption_key,
                    ),
                    configuration.server.report_generation,
                ),
                reports,
                subscriptions,
            )
        return MainContainer(
            report_jobs=jobs,
            configuration=configuration,
            configuration_responses=ConfigurationResponseService(
                configuration,
            ),
            model_service=model_service,
            report_generation=reports,
            dictation_parsing=DictationParsingService(
                configuration,
                model_service,
            ),
            report_email=ReportEmailService(
                variables,
                configuration.server.email,
                configuration.modules.userSettings,
            ),
            subscriptions=subscriptions,
            sdk_payments=SDKPaymentService(
                subscriptions,
                configuration,
                variables,
            )
            if subscriptions is not None
            else None,
        )
