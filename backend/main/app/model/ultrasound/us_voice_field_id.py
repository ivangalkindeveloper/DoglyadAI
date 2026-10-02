from __future__ import annotations

from enum import StrEnum


class USVoiceFieldId(StrEnum):
    EXAMINATION_NUMBER = "examinationNumber"
    PATIENT_NAME = "patientName"
    PATIENT_GENDER = "patientGender"
    PATIENT_DATE_OF_BIRTH = "patientDateOfBirth"
    PATIENT_HEIGHT_CM = "patientHeightCM"
    PATIENT_WEIGHT_KG = "patientWeightKG"
    PATIENT_COMPLAINTS = "patientComplaints"
    EXAMINATION_DESCRIPTION = "examinationDescription"
