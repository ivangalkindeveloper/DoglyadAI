from __future__ import annotations

import re
from decimal import Decimal

from app.core.configuration import Configuration
from app.core.language_code import LanguageCode
from app.error import (
    EmptyReportDescriptionError,
    InvalidPhotoRemarksError,
    ReportMeasurementsMismatchError,
    UnexpectedReportRemarksError,
    UnverifiedReportSectionError,
)
from app.model.ultrasound.us_examination_data import USExaminationData
from app.model.ultrasound.us_examination_report import USExaminationReport
from app.model.ultrasound.us_examination_request import USExaminationRequest
from app.service.clinical_value_is_supported import clinical_value_is_supported


class ReportValidator:
    def __init__(self, configuration: Configuration) -> None:
        self._configuration = configuration

    def validate_content(
        self, report: USExaminationReport, examination: USExaminationData, *, language_code: LanguageCode
    ) -> None:
        """Remove proven misplaced sections and reject altered explicit measurements.

        Literal cross-section copies can be repaired without another generation. Other
        semantic failures are surfaced rather than deleting potentially clinical facts.
        """
        localization = self._configuration.voice_source_localization(language_code)
        description = report.description
        for pattern_key, supported in (
            ("reportConclusionSectionPattern", report.conclusion),
            ("reportComplaintsSectionPattern", examination.patientComplaints),
        ):
            pattern = self._configuration.text(language_code, pattern_key)
            for marker in list(re.finditer(pattern, description, re.IGNORECASE))[::-1]:
                source_value = supported
                lead = marker.groupdict().get("lead")
                if source_value and lead:
                    source_value = re.sub(r"^" + re.escape(lead) + r"\s+", "", source_value, flags=re.IGNORECASE)
                # A section can contain multiple sentences. Try sentence boundaries,
                # retaining any following findings such as the bladder volume.
                ends = [
                    marker.end() + end.end() for end in re.finditer(r"[.!?](?=\s|$)|$", description[marker.end() :])
                ]
                end = next(
                    (
                        end
                        for end in ends
                        if source_value
                        and clinical_value_is_supported(
                            description[marker.end() : end], source_value, localization=localization, is_complete=True
                        )
                    ),
                    None,
                )
                if end is None:
                    raise UnverifiedReportSectionError()
                description = (description[: marker.start()].rstrip() + " " + description[end:].lstrip()).strip()
        if not description:
            raise EmptyReportDescriptionError()
        pattern = self._configuration.text(language_code, "reportMeasurementPattern")
        expected = self._measurements(examination.examinationDescription, pattern)
        actual = self._measurements(description + " " + report.conclusion, pattern)
        if expected and (not expected <= actual or (not examination.photos and not actual <= expected)):
            raise ReportMeasurementsMismatchError()
        report.description = description

    @staticmethod
    def validate_remarks(report: USExaminationReport, request: USExaminationRequest) -> None:
        if not request.isDescriptionRemarks and report.descriptionRemarks is not None:
            raise UnexpectedReportRemarksError()
        if not request.isPhotoRemarks and report.photoRemarks:
            raise UnexpectedReportRemarksError()
        photo_ids = {photo.id for photo in request.examinationData.photos}
        remark_photo_ids = [remarks.photoId for remarks in report.photoRemarks]
        if len(set(remark_photo_ids)) != len(remark_photo_ids):
            raise InvalidPhotoRemarksError()
        if not set(remark_photo_ids).issubset(photo_ids):
            raise InvalidPhotoRemarksError()

    @staticmethod
    def _measurements(text: str, pattern: str) -> set[tuple[str, Decimal]]:
        result: set[tuple[str, Decimal]] = set()
        for match in re.finditer(pattern, text, re.IGNORECASE):
            value = Decimal(match["value"].replace(",", "."))
            if match["centimeter"]:
                result.add(("length", value * 10))
            elif match["millimeter"]:
                result.add(("length", value))
            else:
                result.add(("volume", value))
        return result
