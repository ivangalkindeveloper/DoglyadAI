from __future__ import annotations

from datetime import date
from math import isfinite

from app.model.ultrasound.us_voice_field_accuracy import USVoiceFieldAccuracy
from app.model.ultrasound.us_voice_field_id import USVoiceFieldId
from app.model.ultrasound.us_voice_field_proposal import USVoiceFieldProposal
from app.model.ultrasound.us_voice_form_generation import USVoiceFormGeneration
from app.model.ultrasound.us_voice_form_parse_response import USVoiceFormParseResponse
from app.model.ultrasound.us_voice_source_localization import USVoiceSourceLocalization
from app.service.clinical_value_is_supported import clinical_value_is_supported
from app.service.gender_from_evidence import gender_from_evidence
from app.service.has_birth_date_cue import has_birth_date_cue
from app.service.has_content_outside_evidence import has_content_outside_evidence
from app.service.has_examination_number_evidence import has_examination_number_evidence
from app.service.labeled_birth_date import labeled_birth_date
from app.service.labeled_clinical_text import labeled_clinical_text
from app.service.labeled_examination_number import labeled_examination_number
from app.service.labeled_measurement import labeled_measurement
from app.service.labeled_patient_gender import labeled_patient_gender
from app.service.normalize_patient_name import normalize_patient_name
from app.service.patient_name_metadata_evidence import patient_name_metadata_evidence
from app.service.repair_patient_name_evidence import repair_patient_name_evidence
from app.service.source_birth_date import source_birth_date
from app.service.source_measurement import source_measurement


def _valid_typed_value(field: USVoiceFieldId, value: str | float) -> bool:
    match field:
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
    *,
    localization: USVoiceSourceLocalization,
) -> USVoiceFormParseResponse:
    proposals: list[USVoiceFieldProposal] = []
    seen: set[USVoiceFieldId] = set()
    folded_text = transcript.casefold()
    description_evidence = next(
        (
            item.evidence
            for item in generated.root
            if item.field_id is USVoiceFieldId.EXAMINATION_DESCRIPTION
            and isinstance(item.value, str)
            and item.evidence.strip()
            and folded_text.count(item.evidence.casefold()) == 1
        ),
        None,
    )
    clinical_text = labeled_clinical_text(
        transcript,
        description_evidence=description_evidence,
        localization=localization,
    )
    number_section = labeled_examination_number(transcript, localization=localization)
    birthday_section = labeled_birth_date(transcript, localization=localization)
    gender_section = labeled_patient_gender(transcript, localization=localization)
    measurements = {
        field: section
        for field in (USVoiceFieldId.PATIENT_HEIGHT_CM, USVoiceFieldId.PATIENT_WEIGHT_KG)
        if (section := labeled_measurement(transcript, field, localization=localization)) is not None
    }

    for proposal in generated.root:
        if proposal.field_id in measurements:
            continue
        if proposal.field_id in seen:
            proposals = [item for item in proposals if item.fieldId != proposal.field_id]
            continue
        seen.add(proposal.field_id)
        quote = proposal.evidence
        if proposal.field_id is USVoiceFieldId.PATIENT_NAME and folded_text.count(quote.casefold()) != 1:
            quote = repair_patient_name_evidence(transcript, str(proposal.value), localization=localization) or quote
        folded_quote = quote.casefold()
        if not quote.strip() or folded_text.count(folded_quote) != 1:
            continue
        if proposal.field_id is USVoiceFieldId.EXAMINATION_NUMBER and number_section is not None:
            continue
        if proposal.field_id is USVoiceFieldId.PATIENT_DATE_OF_BIRTH and birthday_section is not None:
            continue
        if proposal.field_id is USVoiceFieldId.PATIENT_GENDER and gender_section is not None:
            continue
        if proposal.field_id is USVoiceFieldId.EXAMINATION_NUMBER and not has_examination_number_evidence(
            transcript, quote, str(proposal.value), localization=localization
        ):
            continue
        checked = USVoiceFieldProposal(
            fieldId=proposal.field_id, value=proposal.value, evidence=proposal.evidence, accuracy=proposal.accuracy
        )
        checked.evidence = quote
        if proposal.field_id is USVoiceFieldId.PATIENT_GENDER:
            gender = gender_from_evidence(quote, localization=localization)
            if gender is None:
                continue
            checked.value = gender
        if proposal.field_id is USVoiceFieldId.PATIENT_DATE_OF_BIRTH:
            if not has_birth_date_cue(transcript, quote, localization=localization):
                continue
            birthday = source_birth_date(quote, localization=localization)
            if birthday is None:
                checked.accuracy = USVoiceFieldAccuracy.QUESTIONABLE
            else:
                checked.value = birthday
        if not _valid_typed_value(checked.fieldId, checked.value):
            continue
        if proposal.field_id in {USVoiceFieldId.PATIENT_HEIGHT_CM, USVoiceFieldId.PATIENT_WEIGHT_KG}:
            measurement = source_measurement(quote, proposal.field_id, localization=localization)
            if measurement is None:
                continue
            checked.value = measurement
        if proposal.field_id is USVoiceFieldId.PATIENT_NAME and (
            str(proposal.value).casefold() not in folded_quote
            or any(folded_quote in item.evidence.casefold() for item in clinical_text.values())
        ):
            continue
        if proposal.field_id is USVoiceFieldId.PATIENT_NAME:
            checked.value = normalize_patient_name(str(checked.value))
        if proposal.field_id in {USVoiceFieldId.PATIENT_COMPLAINTS, USVoiceFieldId.EXAMINATION_DESCRIPTION}:
            # The model may repair an ASR word or disagree with the transcript.
            # Keep its value and verbatim quote for physician review. Source
            # sections only establish full coverage or fill an omitted field.
            clinical_section = clinical_text.get(proposal.field_id)
            if (
                clinical_section is None
                or clinical_section.accuracy is USVoiceFieldAccuracy.QUESTIONABLE
                or not (
                    clinical_value_is_supported(
                        str(checked.value), str(clinical_section.value), localization=localization, is_complete=True
                    )
                    and clinical_value_is_supported(str(checked.value), quote, localization=localization)
                )
            ):
                checked.accuracy = USVoiceFieldAccuracy.QUESTIONABLE
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
                    fieldId=field,
                    value=value,
                    evidence=evidence,
                    accuracy=USVoiceFieldAccuracy.FULL,
                )
            )
    for field, (measurement, evidence) in measurements.items():
        proposals.append(
            USVoiceFieldProposal(
                fieldId=field,
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
        if item.fieldId is USVoiceFieldId.PATIENT_NAME
        and (
            repaired_name_quote := patient_name_metadata_evidence(
                transcript, str(item.value), localization=localization
            )
        )
        is not None
    )
    excluded_evidence.extend(
        item.evidence for item in clinical_text.values() if item.fieldId is USVoiceFieldId.PATIENT_COMPLAINTS
    )
    for item in proposals[:]:
        if item.fieldId is USVoiceFieldId.EXAMINATION_DESCRIPTION and not has_content_outside_evidence(
            item.evidence, excluded_evidence
        ):
            proposals.remove(item)
    return USVoiceFormParseResponse(
        proposals=[
            *proposals,
            *(
                item
                for field, item in clinical_text.items()
                if all(proposal.fieldId is not field for proposal in proposals)
            ),
        ],
    )
