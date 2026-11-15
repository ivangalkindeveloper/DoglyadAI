from __future__ import annotations

from enum import StrEnum


class NeuralModelServiceOperation(StrEnum):
    GENERATE_REPORT = "generate_report"
    PARSE_TRANSCRIPT = "parse_transcript"
