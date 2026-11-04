from __future__ import annotations

import logging
from datetime import UTC, datetime

from app.core.configuration.configuration import Configuration
from app.core.localization.language_code import LanguageCode
from app.error import InvalidReportResponseError
from app.model.neural_model.neural_model_service_operation import NeuralModelServiceOperation
from app.model.neural_model.neural_model_service_request import NeuralModelServiceRequest
from app.model.ultrasound.us_examination_model_report_response import USExaminationModelReportResponse
from app.model.ultrasound.us_examination_report import USExaminationReport
from app.model.ultrasound.us_examination_request import USExaminationRequest
from app.model.ultrasound.us_report_preview_response import USReportPreviewResponse
from app.prompt import PromptFactory
from app.schema.us_examination_report_structured_output import us_examination_report_structured_output
from app.service.neural_model.neural_model_service import NeuralModelService
from app.service.report.report_validator import ReportValidator
from app.service.validation.image_request_validator import ImageRequestValidator
from app.service.validation.text_length_validator import TextLengthValidator

logger = logging.getLogger(
    __name__,
)


class ReportGenerationService:
    def __init__(
        self,
        configuration: Configuration,
        model_service: NeuralModelService,
    ) -> None:
        self._configuration = configuration
        self._model_service = model_service
        self._validator = ReportValidator(
            configuration,
        )
        self._images = ImageRequestValidator(
            configuration.server.max_image_bytes,
            configuration.photo_max_count,
        )

    async def generate(
        self,
        body: USExaminationRequest,
        *,
        language_code: LanguageCode,
        app_check_token: str | None = None,
        request_id: str | None = None,
    ) -> USExaminationModelReportResponse:
        prepared = self.prepare(
            body,
            language_code=language_code,
            app_check_token=app_check_token,
            request_id=request_id,
        )
        response_text = await self._model_service.call(
            prepared,
        )
        return self.complete(
            response_text,
            body,
            model_id=prepared.model_id,
            language_code=language_code,
        )

    def prepare(
        self,
        body: USExaminationRequest,
        *,
        language_code: LanguageCode,
        app_check_token: str | None = None,
        request_id: str | None = None,
    ) -> NeuralModelServiceRequest:
        examination = body.examinationData
        limits = self._configuration.modules.scan
        for field, maximum in (
            ("examinationNumber", limits.examinationNumberMaxLength),
            ("patientName", limits.patientNameMaxLength),
            ("patientComplaints", limits.patientComplaintsMaxLength),
            ("examinationDescription", limits.examinationDescriptionMaxLength),
        ):
            TextLengthValidator.validate(
                getattr(
                    examination,
                    field,
                ),
                maximum,
                ["body", "examinationData", field],
            )
        # Either editor can supply a saved template. Both independently configured
        # creation/editing limits must remain usable during report generation.
        template_maximum = max(
            self._configuration.modules.templateAdd.contentMaxLength,
            self._configuration.modules.templateEdit.contentMaxLength,
        )
        TextLengthValidator.validate(
            body.template,
            template_maximum,
            ["body", "template"],
        )
        self._images.validate(
            [photo.data for photo in body.examinationData.photos],
        )
        prompt_factory = PromptFactory(
            language_code,
            self._configuration,
        )
        settings = body.settingsAI

        neural_model = self._configuration.resolve_neural_model(
            settings.selectedNeuralModelId,
        )
        examination_title = self._configuration.resolve_examination_title(
            examination.usExaminationTypeId,
            language_code,
        )

        logger.info(
            "Report request: model=%s, lang=%s, exam=%s, photos=%d",
            neural_model.id,
            language_code.value,
            examination_title,
            len(
                examination.photos,
            ),
        )

        structured_output = us_examination_report_structured_output(
            is_recommendations_included=body.isRecommendationsIncluded,
            is_photo_remarks=body.isPhotoRemarks,
            is_description_remarks=body.isDescriptionRemarks,
            photo_ids=[photo.id for photo in examination.photos],
            language_code=language_code,
            localization=self._configuration.l10n,
        )
        return NeuralModelServiceRequest(
            operation=NeuralModelServiceOperation.GENERATE_REPORT,
            language_code=language_code,
            model_id=neural_model.id,
            system_prompt=prompt_factory.system_prompt(
                settings,
                is_recommendations_included=body.isRecommendationsIncluded,
                is_photo_remarks=body.isPhotoRemarks
                and bool(
                    examination.photos,
                ),
                is_description_remarks=body.isDescriptionRemarks,
                structured_output=structured_output,
            ),
            prompt=prompt_factory.build_prompt(
                examination,
                examination_title,
                body.template,
            ),
            structured_output=structured_output,
            temperature=settings.temperature,
            max_tokens=settings.maxTokens,
            repetition_penalty=self._configuration.server.report_generation.repetition_penalty,
            photos=examination.photos,
            app_check_token=app_check_token,
            request_id=request_id,
            report_measurements=self._validator.measurement_fragments(
                examination.examinationDescription,
                language_code=language_code,
            ),
        )

    def preview(
        self,
        response_text: str,
    ) -> USReportPreviewResponse:
        report = USReportPreviewResponse.parse_partial(
            response_text,
        )
        self._validator.validate_output(
            report,
        )
        return report

    def complete(
        self,
        response_text: str,
        body: USExaminationRequest,
        *,
        model_id: str,
        language_code: LanguageCode,
    ) -> USExaminationModelReportResponse:
        examination = body.examinationData
        try:
            # Check raw strings before the final model trims optional sections.
            self.preview(
                response_text,
            )
            report = USExaminationReport.model_validate_json(
                response_text,
            )
            self._validator.validate_content(
                report,
                examination,
                language_code=language_code,
            )
            self._validator.validate_remarks(
                report,
                body,
            )
        except ValueError as error:
            raise InvalidReportResponseError() from error

        return USExaminationModelReportResponse(
            date=datetime.now(
                UTC,
            ),
            modelId=model_id,
            **report.model_dump(),
        )
