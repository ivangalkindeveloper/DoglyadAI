from __future__ import annotations

import httpx

from app.core.application.main_container import MainContainer
from app.core.configuration.configuration import Configuration
from app.core.configuration.variables import Variables
from app.database.application_database import ApplicationDatabase
from app.service.billing.apple_subscription_verifier import AppleSubscriptionVerifier
from app.service.billing.checkout_payment_service import CheckoutPaymentService
from app.service.billing.robokassa_payment_provider import RobokassaPaymentProvider
from app.service.billing.subscription_service import SubscriptionService
from app.service.configuration.configuration_response_service import ConfigurationResponseService
from app.service.dictation.audio_parsing_service import AudioParsingService
from app.service.dictation.transcript_parsing_service import TranscriptParsingService
from app.service.email.report_email_service import ReportEmailService
from app.service.neural_model.neural_model_service_factory import NeuralModelServiceFactory
from app.service.report.report_generation_cipher import ReportGenerationCipher
from app.service.report.report_generation_jobs import ReportGenerationJobs
from app.service.report.report_generation_service import ReportGenerationService
from app.service.report.report_generation_store import ReportGenerationStore
from app.service.speech.t_one_transcription_service import TOneTranscriptionService


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
        database: ApplicationDatabase,
    ) -> SubscriptionService:
        config = self._configuration.server.billing.provider
        return SubscriptionService(
            database,
            self._configuration,
            self._variables,
            RobokassaPaymentProvider(
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
        subscription_service: SubscriptionService | None,
        *,
        is_speech_enabled: bool = False,
    ) -> MainContainer:
        configuration = self._configuration
        variables = self._variables
        model_service = NeuralModelServiceFactory.create(
            self._http_client,
            configuration.neural_models.values(),
            variables,
            configuration.server.inference,
        )
        report_generation_service = ReportGenerationService(
            configuration,
            model_service,
        )
        jobs = None
        if subscription_service is not None and variables.report_generation_encryption_key:
            jobs = ReportGenerationJobs(
                ReportGenerationStore(
                    subscription_service.database,
                    ReportGenerationCipher(
                        variables.report_generation_encryption_key,
                    ),
                    configuration.server.report_generation,
                ),
                report_generation_service,
                subscription_service,
            )
        speech_service = (
            TOneTranscriptionService(
                variables.t_one_model_path,
                configuration.server.speech,
            )
            if is_speech_enabled
            else None
        )
        parser_service = TranscriptParsingService(
            configuration,
            model_service,
        )
        return MainContainer(
            speech_transcription_service=speech_service,
            audio_parsing_service=AudioParsingService(
                configuration,
                speech_service,
                parser_service,
            )
            if speech_service is not None
            else None,
            report_jobs=jobs,
            configuration=configuration,
            configuration_response_service=ConfigurationResponseService(
                configuration,
            ),
            model_service=model_service,
            report_generation_service=report_generation_service,
            transcript_parsing_service=parser_service,
            report_email_service=ReportEmailService(
                variables,
                configuration.server.email,
                configuration.modules.workSettings,
            ),
            subscription_service=subscription_service,
            checkout_payment_service=CheckoutPaymentService(
                subscription_service,
                configuration,
            )
            if subscription_service is not None
            else None,
        )
