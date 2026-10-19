from __future__ import annotations

from enum import StrEnum


class TranscriberType(StrEnum):
    SF_SPEECH_RECOGNIZER = "sfSpeechRecognizer"
    SPEECH_ANALYZER = "speechAnalyzer"
    WHISPER_KIT = "whisperKit"
