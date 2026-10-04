from __future__ import annotations

import json

from pydantic import Field, RootModel

from app.model.ultrasound.us_voice_numeric_field_generation import USVoiceNumericFieldGeneration
from app.model.ultrasound.us_voice_text_field_generation import USVoiceTextFieldGeneration


class USVoiceFormGeneration(RootModel[list[USVoiceTextFieldGeneration | USVoiceNumericFieldGeneration]]):
    # The eight form fields are the upper bound on useful proposals. Capping the
    # array in the generation grammar prevents repeated entries from exhausting
    # the model's token budget before it closes the JSON document.
    root: list[USVoiceTextFieldGeneration | USVoiceNumericFieldGeneration] = Field(max_length=8)

    @classmethod
    def structured_output(cls) -> str:
        return json.dumps(cls.model_json_schema(), ensure_ascii=False, separators=(",", ":"))
