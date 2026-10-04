from __future__ import annotations

from datetime import date
from math import isfinite

from app.model.ultrasound.us_voice_field_id import USVoiceFieldId
from app.model.ultrasound.us_voice_field_proposal import USVoiceFieldProposal
from app.model.ultrasound.us_voice_form_generation import USVoiceFormGeneration
from app.model.ultrasound.us_voice_form_parse_response import USVoiceFormParseResponse


def _valid_typed_value(proposal: USVoiceFieldProposal) -> bool:
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

    for proposal in generated.root:
        if proposal.field_id in seen:
            rejected.append(proposal.field_id)
            proposals = [item for item in proposals if item.field_id != proposal.field_id]
            continue
        seen.add(proposal.field_id)
        quote = proposal.evidence
        folded_quote = quote.casefold()
        if not quote.strip() or folded_text.count(folded_quote) != 1 or not _valid_typed_value(proposal):
            rejected.append(proposal.field_id)
            continue
        proposals.append(proposal)
    return USVoiceFormParseResponse(
        proposals=proposals,
        rejectedFieldIds=list(dict.fromkeys(rejected)),
        unmappedFindings=[],
    )
