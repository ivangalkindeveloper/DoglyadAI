from __future__ import annotations

from enum import StrEnum


class TranscriptParserType(StrEnum):
    FOUNDATION_MODELS = "foundationModels"
    SERVER = "server"
