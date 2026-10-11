from __future__ import annotations

from app.model.ultrasound.us_examination_report import USExaminationReport
from app.model.ultrasound.us_examination_request import USExaminationRequest


def validate_report_remarks(report: USExaminationReport, request: USExaminationRequest) -> None:
    if not request.isDescriptionRemarks and report.descriptionRemarks is not None:
        raise ValueError("Description remarks were not requested")
    if not request.isPhotoRemarks and report.photoRemarks:
        raise ValueError("Photo remarks were not requested")
    photo_ids = {photo.id for photo in request.examinationData.photos}
    remark_photo_ids = [remarks.photoId for remarks in report.photoRemarks]
    if len(set(remark_photo_ids)) != len(remark_photo_ids):
        raise ValueError("Photo remarks must be grouped by unique photo ID")
    if not set(remark_photo_ids).issubset(photo_ids):
        raise ValueError("Photo remarks refer to an unknown photo")
