from __future__ import annotations

from dataclasses import dataclass

from app.core.configuration.configuration import Configuration
from app.service.billing.checkout_payment_service import CheckoutPaymentService
from app.service.billing.subscription_service import SubscriptionService
from app.service.configuration.configuration_response_service import ConfigurationResponseService
from app.service.dictation.audio_parsing_service import AudioParsingService
from app.service.dictation.transcript_parsing_service import TranscriptParsingService
from app.service.email.report_email_service import ReportEmailService
from app.service.neural_model.neural_model_service import NeuralModelService
from app.service.report.report_generation_jobs import ReportGenerationJobs
from app.service.report.report_generation_service import ReportGenerationService
from app.service.speech.t_one_transcription_service import TOneTranscriptionService


@dataclass(
    frozen=True,
)
class MainContainer:
    configuration: Configuration
    configuration_response_service: ConfigurationResponseService
    model_service: NeuralModelService
    report_generation_service: ReportGenerationService
    transcript_parsing_service: TranscriptParsingService
    report_email_service: ReportEmailService
    report_jobs: ReportGenerationJobs | None = None
    subscription_service: SubscriptionService | None = None
    checkout_payment_service: CheckoutPaymentService | None = None
    speech_transcription_service: TOneTranscriptionService | None = None
    audio_parsing_service: AudioParsingService | None = None
