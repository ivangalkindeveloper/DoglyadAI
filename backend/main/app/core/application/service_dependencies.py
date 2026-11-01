from __future__ import annotations

from fastapi import Request

from app.core.application.main_container import MainContainer
from app.core.configuration.configuration import Configuration
from app.error.billing_unavailable_error import BillingUnavailableError
from app.service.billing.sdk_payment_service import SDKPaymentService
from app.service.billing.subscription_service import SubscriptionService
from app.service.configuration.configuration_response_service import ConfigurationResponseService
from app.service.dictation.dictation_parsing_service import DictationParsingService
from app.service.email.report_email_service import ReportEmailService
from app.service.report.report_generation_service import ReportGenerationService


class ServiceDependencies:
    """Typed FastAPI dependencies for already-created application services."""

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
        return container.configuration_responses

    @staticmethod
    async def report_generation(
        request: Request,
    ) -> ReportGenerationService:
        container: MainContainer = request.app.state.container
        return container.report_generation

    @staticmethod
    async def dictation_parsing(
        request: Request,
    ) -> DictationParsingService:
        container: MainContainer = request.app.state.container
        return container.dictation_parsing

    @staticmethod
    async def report_email(
        request: Request,
    ) -> ReportEmailService:
        container: MainContainer = request.app.state.container
        return container.report_email

    @staticmethod
    async def subscriptions(
        request: Request,
    ) -> SubscriptionService:
        container: MainContainer = request.app.state.container
        if container.subscriptions is None:
            raise BillingUnavailableError()
        return container.subscriptions

    @staticmethod
    async def sdk_payments(
        request: Request,
    ) -> SDKPaymentService:
        container: MainContainer = request.app.state.container
        if container.sdk_payments is None:
            raise BillingUnavailableError()
        return container.sdk_payments
