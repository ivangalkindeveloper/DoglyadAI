from __future__ import annotations

import json


def voice_form_prompt(examination_title: str, transcript: str, contextual_strings: list[str]) -> str:
    return json.dumps(
        {"examinationType": examination_title, "contextualStrings": contextual_strings, "transcript": transcript},
        ensure_ascii=False,
    )
