from __future__ import annotations

from dataclasses import dataclass

from app.core.configuration import Configuration
from app.service.configuration_response_service import ConfigurationResponseService
from app.service.dictation_parsing_service import DictationParsingService
from app.service.neural_model_service import NeuralModelService
from app.service.report_email_service import ReportEmailService
from app.service.report_generation_service import ReportGenerationService


@dataclass(frozen=True)
class MainContainer:
    configuration: Configuration
    configuration_responses: ConfigurationResponseService
    model_service: NeuralModelService
    report_generation: ReportGenerationService
    dictation_parsing: DictationParsingService
    report_email: ReportEmailService
