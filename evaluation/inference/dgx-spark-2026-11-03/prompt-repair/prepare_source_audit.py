"""Test input structure and focused source comparison before report generation."""

from __future__ import annotations

import copy
import json
from pathlib import Path
import re

DIRECTORY = Path(__file__).resolve().parent
AUDIT_RU = """Проверь согласованность исходного описания ультразвукового исследования. Не составляй протокол и не давай медицинских рекомендаций.
Найди только взаимоисключающие утверждения об одной и той же структуре или признаке. Указание отсутствия очаговых изменений несовместимо с наличием очагового образования в той же исследуемой структуре. Не считай отсутствующие сведения ошибкой. Не сравнивай измерения со справочными нормами. Поздняя фраза отменяет раннюю только при явно указанном исправлении.
Если противоречия нет, верни descriptionRemarks: null. Если оно есть, в descriptionRemarks назови две несовместимые фразы и попроси врача уточнить, какая верна. Не обсуждай все остальные находки.
Верни один JSON-объект по схеме:
"""
AUDIT_IDS = """Сравни утверждения в исходном описании УЗИ. Каждое предложение имеет id.
Найди только пары взаимоисключающих утверждений об одном и том же признаке одной структуры. Отсутствие очаговых изменений несовместимо с наличием очагового образования в этой структуре. Отсутствие конкрементов несовместимо с наличием конкремента. Сами размеры структуры не противоречат наличию образования. Не добавляй медицинские выводы и не ищи недостающие сведения. Явное исправление врача заменяет прежнюю фразу и не считается противоречием.
В conflicts верни пары id предложений, которые прямо противоречат друг другу. При отсутствии противоречий верни пустой массив. Не повторяй пары, каждую проблему укажи один раз. Только JSON по схеме:
"""


def sentences(text: str) -> list[dict]:
    return [{"id": i, "text": item.strip()} for i, item in enumerate(re.split(r"(?<=[.!?])\s+", text), 1) if item.strip()]


def main() -> None:
    source = json.loads((DIRECTORY / "concise-ru-cases.json").read_text())
    variants = {name: [] for name in ("structured-input", "audit-text", "audit-ids")}
    for original in source:
        exam = original["body"]["examinationData"]
        fragments = sentences(exam["examinationDescription"])
        structured = copy.deepcopy(original)
        lines = structured["payload"]["messages"][1]["content"].splitlines()
        lexicon = json.loads(next(line for line in lines if line.startswith('{"contextualStrings":')))
        structured["payload"]["messages"][1]["content"] = json.dumps({
            "examinationType": "Щитовидная железа", "patientComplaints": exam["patientComplaints"],
            "sourceStatements": fragments, **lexicon,
        }, ensure_ascii=False)
        variants["structured-input"].append(structured)
        for name, prompt in (("audit-text", AUDIT_RU), ("audit-ids", AUDIT_IDS)):
            changed = copy.deepcopy(original)
            changed["task"] = name
            changed["source_statements"] = fragments
            if name == "audit-text":
                schema = {"type": "object", "additionalProperties": False, "properties": {"descriptionRemarks": {"type": ["string", "null"]}}, "required": ["descriptionRemarks"]}
                data = exam["examinationDescription"]
            else:
                schema = {"type": "object", "additionalProperties": False, "properties": {"conflicts": {"type": "array", "items": {"type": "array", "items": {"type": "integer", "enum": [item["id"] for item in fragments]}, "minItems": 2, "maxItems": 2}}}, "required": ["conflicts"]}
                data = json.dumps({"statements": fragments}, ensure_ascii=False)
            changed["schema"] = schema
            changed["payload"]["response_format"]["json_schema"]["schema"] = copy.deepcopy(schema)
            changed["payload"]["messages"] = [{"role": "system", "content": prompt + json.dumps(schema, ensure_ascii=False)}, {"role": "user", "content": data}]
            variants[name].append(changed)
    for name, cases in variants.items():
        (DIRECTORY / f"{name}-cases.json").write_text(json.dumps(cases, ensure_ascii=False, indent=2) + "\n")
    (DIRECTORY / "audit-manifest.json").write_text(json.dumps(list(variants), indent=2) + "\n")


if __name__ == "__main__":
    main()
