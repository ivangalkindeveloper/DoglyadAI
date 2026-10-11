from __future__ import annotations

import re

_GENDERS = {
    "male": "male",
    "female": "female",
    "man": "male",
    "woman": "female",
    "мужчина": "male",
    "женщина": "female",
}
_WORD = "(?:" + "|".join(_GENDERS) + ")"
_LABEL = re.compile(rf"\b(?:gender|sex|пол)\s*(?:is\s*)?:?\s*(?P<gender>{_WORD})\b", re.IGNORECASE)
_FETAL = re.compile(r"\b(?:fetal|fetus|foetus|плод|плода|эмбрион)\b", re.IGNORECASE)


def labeled_patient_gender(transcript: str) -> tuple[str, str] | None:
    sections: list[tuple[str, str]] = []
    for marker in _LABEL.finditer(transcript):
        prefix = re.split(r"[.;\n]", transcript[: marker.start()])[-1]
        if _FETAL.search(prefix):
            continue
        sections.append((_GENDERS[marker["gender"].casefold()], marker[0]))
    return sections[0] if len(sections) == 1 else None
