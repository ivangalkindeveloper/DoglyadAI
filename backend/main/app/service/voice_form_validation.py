from __future__ import annotations

from datetime import date
from math import isfinite

from app.model.ultrasound.us_voice_field_accuracy import USVoiceFieldAccuracy
from app.model.ultrasound.us_voice_field_id import USVoiceFieldId
from app.model.ultrasound.us_voice_field_proposal import USVoiceFieldProposal
from app.model.ultrasound.us_voice_form_generation import USVoiceFormGeneration
from app.model.ultrasound.us_voice_form_parse_response import USVoiceFormParseResponse
from app.model.ultrasound.us_voice_numeric_field_generation import USVoiceNumericFieldGeneration
from app.model.ultrasound.us_voice_text_field_generation import USVoiceTextFieldGeneration
from app.service.voice_form_birth_date import has_birth_date_cue, labeled_birth_date, source_birth_date
from app.service.voice_form_clinical_text import (
    clinical_value_is_supported,
    has_content_outside_evidence,
    labeled_clinical_text,
)
from app.service.voice_form_gender import gender_from_evidence, labeled_patient_gender
from app.service.voice_form_measurement import labeled_measurement, source_measurement
from app.service.voice_form_name_evidence import patient_name_metadata_evidence, repair_patient_name_evidence
from app.service.voice_form_number_evidence import has_examination_number_evidence, labeled_examination_number


def _valid_typed_value(proposal: USVoiceTextFieldGeneration | USVoiceNumericFieldGeneration) -> bool:
    value = proposal.value
    match proposal.field_id:
        case USVoiceFieldId.PATIENT_GENDER:
            return isinstance(value, str) and value in {"male", "female"}
        case USVoiceFieldId.PATIENT_DATE_OF_BIRTH:
            if not isinstance(value, str):
                return False
            try:
                return date.fromisoformat(value).isoformat() == value
            except ValueError:
                return False
        case USVoiceFieldId.PATIENT_HEIGHT_CM | USVoiceFieldId.PATIENT_WEIGHT_KG:
            return isinstance(value, float) and isfinite(value) and value > 0
        case (
            USVoiceFieldId.EXAMINATION_NUMBER
            | USVoiceFieldId.PATIENT_NAME
            | USVoiceFieldId.PATIENT_COMPLAINTS
            | USVoiceFieldId.EXAMINATION_DESCRIPTION
        ):
            return isinstance(value, str) and bool(value.strip())


def validate_voice_form_generation(
    generated: USVoiceFormGeneration,
    transcript: str,
) -> USVoiceFormParseResponse:
    proposals: list[USVoiceFieldProposal] = []
    rejected: list[USVoiceFieldId] = []
    seen: set[USVoiceFieldId] = set()
    folded_text = transcript.casefold()
    description_evidence = next(
        (
            item.evidence
            for item in generated.root
            if item.field_id is USVoiceFieldId.EXAMINATION_DESCRIPTION
            and isinstance(item.value, str)
            and clinical_value_is_supported(item.value, item.evidence)
        ),
        None,
    )
    clinical_text = labeled_clinical_text(transcript, description_evidence=description_evidence)
    number_section = labeled_examination_number(transcript)
    birthday_section = labeled_birth_date(transcript)
    gender_section = labeled_patient_gender(transcript)
    measurements = {
        field: section
        for field in (USVoiceFieldId.PATIENT_HEIGHT_CM, USVoiceFieldId.PATIENT_WEIGHT_KG)
        if (section := labeled_measurement(transcript, field)) is not None
    }

    for proposal in generated.root:
        if proposal.field_id in clinical_text or proposal.field_id in measurements:
            continue
        if proposal.field_id in seen:
            rejected.append(proposal.field_id)
            proposals = [item for item in proposals if item.field_id != proposal.field_id]
            continue
        seen.add(proposal.field_id)
        quote = proposal.evidence
        if proposal.field_id is USVoiceFieldId.PATIENT_NAME and folded_text.count(quote.casefold()) != 1:
            quote = repair_patient_name_evidence(transcript, str(proposal.value)) or quote
        folded_quote = quote.casefold()
        if not quote.strip() or folded_text.count(folded_quote) != 1 or not _valid_typed_value(proposal):
            rejected.append(proposal.field_id)
            continue
        if proposal.field_id is USVoiceFieldId.EXAMINATION_NUMBER and number_section is not None:
            continue
        if proposal.field_id is USVoiceFieldId.PATIENT_DATE_OF_BIRTH and birthday_section is not None:
            continue
        if proposal.field_id is USVoiceFieldId.PATIENT_GENDER and gender_section is not None:
            continue
        if proposal.field_id is USVoiceFieldId.EXAMINATION_NUMBER and not has_examination_number_evidence(
            transcript, quote, str(proposal.value)
        ):
            rejected.append(proposal.field_id)
            continue
        checked = USVoiceFieldProposal.model_validate(proposal.model_dump())
        checked.evidence = quote
        if proposal.field_id is USVoiceFieldId.PATIENT_GENDER:
            gender = gender_from_evidence(quote)
            if gender is None:
                rejected.append(proposal.field_id)
                continue
            checked.value = gender
        if proposal.field_id in {USVoiceFieldId.PATIENT_HEIGHT_CM, USVoiceFieldId.PATIENT_WEIGHT_KG}:
            measurement = source_measurement(quote, proposal.field_id)
            if measurement is None:
                rejected.append(proposal.field_id)
                continue
            checked.value = measurement
        if proposal.field_id is USVoiceFieldId.PATIENT_NAME and (
            str(proposal.value).casefold() not in folded_quote
            or any(folded_quote in item.evidence.casefold() for item in clinical_text.values())
        ):
            rejected.append(proposal.field_id)
            continue
        if proposal.field_id in {USVoiceFieldId.PATIENT_COMPLAINTS, USVoiceFieldId.EXAMINATION_DESCRIPTION}:
            if not clinical_value_is_supported(str(checked.value), quote):
                rejected.append(proposal.field_id)
                continue
            # A matching excerpt alone does not prove that the model kept all
            # relevant clinical sentences or normalized a correction correctly.
            # Explicit source sections are copied above without model rewriting.
            checked.accuracy = USVoiceFieldAccuracy.QUESTIONABLE
        if proposal.field_id is USVoiceFieldId.PATIENT_DATE_OF_BIRTH:
            if not has_birth_date_cue(transcript, quote):
                rejected.append(proposal.field_id)
                continue
            birthday = source_birth_date(quote)
            if birthday is None:
                checked.accuracy = USVoiceFieldAccuracy.QUESTIONABLE
            else:
                checked.value = birthday
        proposals.append(checked)
    for field, scalar_section in (
        (USVoiceFieldId.PATIENT_DATE_OF_BIRTH, birthday_section),
        (USVoiceFieldId.EXAMINATION_NUMBER, number_section),
        (USVoiceFieldId.PATIENT_GENDER, gender_section),
    ):
        if scalar_section is not None:
            value, evidence = scalar_section
            proposals.append(
                USVoiceFieldProposal(
                    field_id=field,
                    value=value,
                    evidence=evidence,
                    accuracy=USVoiceFieldAccuracy.FULL,
                )
            )
    for field, (measurement, evidence) in measurements.items():
        proposals.append(
            USVoiceFieldProposal(
                field_id=field,
                value=measurement,
                evidence=evidence,
                accuracy=USVoiceFieldAccuracy.FULL,
            )
        )
    # Only independently bounded source sections establish metadata coverage.
    # A generated quote may contain the entire dictation, including findings.
    excluded_evidence = [
        section[1]
        for section in (number_section, birthday_section, gender_section, *measurements.values())
        if section is not None
    ]
    excluded_evidence.extend(
        repaired_name_quote
        for item in proposals
        if item.field_id is USVoiceFieldId.PATIENT_NAME
        and (repaired_name_quote := patient_name_metadata_evidence(transcript, str(item.value))) is not None
    )
    excluded_evidence.extend(
        item.evidence for item in clinical_text.values() if item.field_id is USVoiceFieldId.PATIENT_COMPLAINTS
    )
    for item in proposals[:]:
        if item.field_id is USVoiceFieldId.EXAMINATION_DESCRIPTION and not has_content_outside_evidence(
            item.evidence, excluded_evidence
        ):
            proposals.remove(item)
            rejected.append(item.field_id)
    return USVoiceFormParseResponse(
        proposals=[*proposals, *clinical_text.values()],
        rejectedFieldIds=list(
            dict.fromkeys(field for field in rejected if field not in {item.field_id for item in proposals})
        ),
        unmappedFindings=[],
    )
