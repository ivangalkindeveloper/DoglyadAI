from __future__ import annotations

from fastapi import Request

from app.core.application.main_container import MainContainer
from app.core.configuration.configuration import Configuration
from app.error.billing_unavailable_error import BillingUnavailableError
from app.error.report_generation_unavailable_error import ReportGenerationUnavailableError
from app.error.speech_unavailable_error import SpeechUnavailableError
from app.service.billing.checkout_payment_service import CheckoutPaymentService
from app.service.billing.subscription_service import SubscriptionService
from app.service.configuration.configuration_response_service import ConfigurationResponseService
from app.service.dictation.audio_parsing_service import AudioParsingService
from app.service.dictation.transcript_parsing_service import TranscriptParsingService
from app.service.email.report_email_service import ReportEmailService
from app.service.report.report_generation_jobs import ReportGenerationJobs


class ServiceDependencies:
    """Typed FastAPI dependencies for already-created application services."""

    def __init__(
        self,
    ) -> None:
        pass

    @staticmethod
    async def configuration(
        request: Request,
    ) -> Configuration:
        container: MainContainer = request.app.state.container
        return container.configuration

    @staticmethod
    async def configuration_responses(
        request: Request,
    ) -> ConfigurationResponseService:
        container: MainContainer = request.app.state.container
        return container.configuration_response_service

    @staticmethod
    async def transcript_parsing(
        request: Request,
    ) -> TranscriptParsingService:
        container: MainContainer = request.app.state.container
        return container.transcript_parsing_service

    @staticmethod
    async def report_email(
        request: Request,
    ) -> ReportEmailService:
        container: MainContainer = request.app.state.container
        return container.report_email_service

    @staticmethod
    async def subscriptions(
        request: Request,
    ) -> SubscriptionService:
        container: MainContainer = request.app.state.container
        if container.subscription_service is None:
            raise BillingUnavailableError()
        return container.subscription_service

    @staticmethod
    async def checkout_payments(
        request: Request,
    ) -> CheckoutPaymentService:
        container: MainContainer = request.app.state.container
        if container.checkout_payment_service is None:
            raise BillingUnavailableError()
        return container.checkout_payment_service

    @staticmethod
    async def report_jobs(
        request: Request,
    ) -> ReportGenerationJobs:
        container: MainContainer = request.app.state.container
        if container.report_jobs is None:
            raise ReportGenerationUnavailableError()
        return container.report_jobs

    @staticmethod
    async def audio_parsing(
        request: Request,
    ) -> AudioParsingService:
        container: MainContainer = request.app.state.container
        if container.audio_parsing_service is None:
            raise SpeechUnavailableError()
        return container.audio_parsing_service
