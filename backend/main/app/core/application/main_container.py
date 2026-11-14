from __future__ import annotations

from dataclasses import dataclass

from app.core.configuration.configuration import Configuration
from app.service.billing.checkout_payment_service import CheckoutPaymentService
from app.service.billing.subscription_service import SubscriptionService
from app.service.configuration.configuration_response_service import ConfigurationResponseService
from app.service.dictation.dictation_parsing_service import DictationParsingService
from app.service.email.report_email_service import ReportEmailService
from app.service.neural_model.neural_model_service import NeuralModelService
from app.service.report.report_generation_jobs import ReportGenerationJobs
from app.service.report.report_generation_service import ReportGenerationService


@dataclass(
    frozen=True,
)
class MainContainer:
    configuration: Configuration
    configuration_responses: ConfigurationResponseService
    model_service: NeuralModelService
    report_generation: ReportGenerationService
    dictation_parsing: DictationParsingService
    report_email: ReportEmailService
    report_jobs: ReportGenerationJobs | None = None
    subscriptions: SubscriptionService | None = None
    checkout_payments: CheckoutPaymentService | None = None
