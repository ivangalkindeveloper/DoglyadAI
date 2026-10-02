from __future__ import annotations

from datetime import date
from math import isfinite

from app.model.ultrasound.us_voice_field_id import USVoiceFieldId
from app.model.ultrasound.us_voice_field_proposal import USVoiceFieldProposal
from app.model.ultrasound.us_voice_form_generation import USVoiceFormGeneration
from app.model.ultrasound.us_voice_form_parse_response import USVoiceFormParseResponse


def _valid_typed_value(proposal: USVoiceFieldProposal) -> bool:
    value = proposal.value.strip()
    if not value:
        return False
    match proposal.fieldId:
        case USVoiceFieldId.PATIENT_GENDER:
            return value in {"male", "female"}
        case USVoiceFieldId.PATIENT_DATE_OF_BIRTH:
            try:
                return date.fromisoformat(value).isoformat() == value
            except ValueError:
                return False
        case USVoiceFieldId.PATIENT_HEIGHT_CM | USVoiceFieldId.PATIENT_WEIGHT_KG:
            try:
                number = float(value)
            except ValueError:
                return False
            return isfinite(number) and number > 0
        case (
            USVoiceFieldId.EXAMINATION_NUMBER
            | USVoiceFieldId.PATIENT_NAME
            | USVoiceFieldId.PATIENT_COMPLAINTS
            | USVoiceFieldId.EXAMINATION_DESCRIPTION
        ):
            return True


def validate_voice_form_generation(
    generated: USVoiceFormGeneration,
    transcript: str,
) -> USVoiceFormParseResponse:
    proposals: list[USVoiceFieldProposal] = []
    rejected: list[USVoiceFieldId] = []
    seen: set[USVoiceFieldId] = set()
    folded_text = transcript.casefold()

    for proposal in generated.proposals:
        if proposal.fieldId in seen:
            rejected.append(proposal.fieldId)
            proposals = [item for item in proposals if item.fieldId != proposal.fieldId]
            continue
        seen.add(proposal.fieldId)
        quote = proposal.sourceQuote
        folded_quote = quote.casefold()
        if not quote.strip() or folded_text.count(folded_quote) != 1 or not _valid_typed_value(proposal):
            rejected.append(proposal.fieldId)
            continue
        proposals.append(proposal)

    findings = [
        finding
        for finding in generated.unmappedFindings
        if finding.strip() and folded_text.count(finding.casefold()) == 1
    ]
    return USVoiceFormParseResponse(
        proposals=proposals,
        rejectedFieldIds=list(dict.fromkeys(rejected)),
        unmappedFindings=list(dict.fromkeys(findings)),
    )
