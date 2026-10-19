from __future__ import annotations

from pydantic import BaseModel, Field

from app.model.transcriber_type import TranscriberType
from app.model.transcript_parser_type import TranscriptParserType


class SettingsAI(BaseModel):
    transcriberType: TranscriberType = TranscriberType.WHISPER_KIT
    transcriptParserType: TranscriptParserType = TranscriptParserType.SERVER
    selectedNeuralModelId: str | None = None
    isMarkdown: bool = Field(default=False)
    temperature: float | None = Field(default=None, ge=0.0, le=2.0)
    maxTokens: int | None = Field(default=None, gt=0, le=4096)
