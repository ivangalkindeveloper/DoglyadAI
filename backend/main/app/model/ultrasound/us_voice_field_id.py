from __future__ import annotations

from enum import StrEnum


class USVoiceFieldId(StrEnum):
    EXAMINATION_NUMBER = "examination_number"
    PATIENT_NAME = "patient_name"
    PATIENT_GENDER = "patient_gender"
    PATIENT_DATE_OF_BIRTH = "patient_date_of_birth"
    PATIENT_HEIGHT_CM = "patient_height_cm"
    PATIENT_WEIGHT_KG = "patient_weight_kg"
    PATIENT_COMPLAINTS = "patient_complaints"
    EXAMINATION_DESCRIPTION = "examination_description"
