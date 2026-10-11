from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field

from app.model.ultrasound.us_voice_form_generation import USVoiceFormGeneration


class MockVoiceFormFixture(BaseModel):
    model_config = ConfigDict(extra="forbid")

    transcript: str = Field(min_length=1)
    generation: USVoiceFormGeneration
