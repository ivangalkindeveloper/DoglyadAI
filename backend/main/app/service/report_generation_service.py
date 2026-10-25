from __future__ import annotations

import logging
from datetime import UTC, datetime

from app.core.configuration import Configuration
from app.core.language_code import LanguageCode
from app.error import InvalidReportResponseError
from app.model.neural_model.neural_model_service_operation import NeuralModelServiceOperation
from app.model.ultrasound.us_examination_model_report_response import USExaminationModelReportResponse
from app.model.ultrasound.us_examination_report import USExaminationReport
from app.model.ultrasound.us_examination_request import USExaminationRequest
from app.prompt import PromptFactory
from app.schema.us_examination_report_structured_output import us_examination_report_structured_output
from app.service import NeuralModelService, NeuralModelServiceRequest
from app.service.image_request_validator import ImageRequestValidator
from app.service.report_validator import ReportValidator
from app.service.text_length_validator import TextLengthValidator

logger = logging.getLogger(__name__)


class ReportGenerationService:
    def __init__(self, configuration: Configuration, model_service: NeuralModelService) -> None:
        self._configuration = configuration
        self._model_service = model_service
        self._validator = ReportValidator(configuration)
        self._images = ImageRequestValidator(configuration.server.max_image_bytes, configuration.photo_max_count)

    async def generate(
        self,
        body: USExaminationRequest,
        *,
        language_code: LanguageCode,
        app_check_token: str | None = None,
        request_id: str | None = None,
    ) -> USExaminationModelReportResponse:
        examination = body.examinationData
        limits = self._configuration.modules.scan
        for field, maximum in (
            ("examinationNumber", limits.examinationNumberMaxLength),
            ("patientName", limits.patientNameMaxLength),
            ("patientComplaints", limits.patientComplaintsMaxLength),
            ("examinationDescription", limits.examinationDescriptionMaxLength),
        ):
            TextLengthValidator.validate(getattr(examination, field), maximum, ["body", "examinationData", field])
        # Either editor can supply a saved template. Both independently configured
        # creation/editing limits must remain usable during report generation.
        template_maximum = max(
            self._configuration.modules.templateAdd.contentMaxLength,
            self._configuration.modules.templateEdit.contentMaxLength,
        )
        TextLengthValidator.validate(body.template, template_maximum, ["body", "template"])
        self._images.validate([photo.data for photo in body.examinationData.photos])
        prompt_factory = PromptFactory(language_code, self._configuration)
        settings = body.settingsAI

        neural_model = self._configuration.resolve_neural_model(settings.selectedNeuralModelId)
        examination_title = self._configuration.resolve_examination_title(
            examination.usExaminationTypeId,
            language_code,
        )

        logger.info(
            "Report request: model=%s, lang=%s, exam=%s, photos=%d",
            neural_model.id,
            language_code.value,
            examination_title,
            len(examination.photos),
        )

        response_text = await self._model_service.call(
            NeuralModelServiceRequest(
                operation=NeuralModelServiceOperation.GENERATE_REPORT,
                language_code=language_code,
                model_id=neural_model.id,
                system_prompt=prompt_factory.system_prompt(
                    settings,
                    is_recommendations_included=body.isRecommendationsIncluded,
                    is_photo_remarks=body.isPhotoRemarks and bool(examination.photos),
                    is_description_remarks=body.isDescriptionRemarks,
                ),
                prompt=prompt_factory.build_prompt(
                    examination,
                    examination_title,
                    body.template,
                ),
                structured_output=us_examination_report_structured_output(
                    is_recommendations_included=body.isRecommendationsIncluded,
                    is_photo_remarks=body.isPhotoRemarks,
                    is_description_remarks=body.isDescriptionRemarks,
                    photo_ids=[photo.id for photo in examination.photos],
                    language_code=language_code,
                    localization=self._configuration.l10n,
                ),
                temperature=settings.temperature,
                max_tokens=settings.maxTokens,
                photos=examination.photos,
                app_check_token=app_check_token,
                request_id=request_id,
            )
        )

        try:
            report = USExaminationReport.model_validate_json(response_text)
            self._validator.validate_content(report, examination, language_code=language_code)
            self._validator.validate_remarks(report, body)
        except ValueError as error:
            raise InvalidReportResponseError() from error

        return USExaminationModelReportResponse(
            date=datetime.now(UTC),
            modelId=neural_model.id,
            **report.model_dump(),
        )
