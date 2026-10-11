from __future__ import annotations

import json


def voice_form_prompt(examination_title: str, transcript: str) -> str:
    return json.dumps(
        {"examinationType": examination_title, "transcript": transcript},
        ensure_ascii=False,
    )
