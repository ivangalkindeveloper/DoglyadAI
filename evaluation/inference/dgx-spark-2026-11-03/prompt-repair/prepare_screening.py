"""Isolate prompt effects without character truncation or repetition penalties."""

from __future__ import annotations

import copy
import json
from pathlib import Path

from jsonschema import Draft202012Validator

DIRECTORY = Path(__file__).resolve().parent
ROOT = DIRECTORY.parents[3]
SELECTED = {"report-greedy-0", "report-sample-42", "conflict-greedy-0", "conflict-sample-42"}

RU = """Составь протокол УЗИ на русском языке только по данным пациента.
description: изложи находки исследования. Сохрани каждое исходное измерение, единицу, сторону и отрицание. Не добавляй признаки, которых нет в источнике. Жалобы и заключение врача не копируй в описание находок.
conclusion: краткое заключение по находкам; не пересказывай описание. Если врач продиктовал заключение отдельно, сохрани его смысл. Не назначай диагноз без основания.
recommendations: только действия, обоснованные исходными данными; иначе null.
descriptionRemarks: только противоречия или неоднозначности исходного описания. Если для одной структуры одновременно указаны наличие и отсутствие признака, назови оба утверждения и попроси уточнить. Поздняя фраза заменяет раннюю только при явном исправлении врача. Не перечисляй недостающие признаки и не пересказывай описание. Если такой проблемы нет, null.
contextualStrings — словарь для однозначного исправления ошибок распознавания медицинских терминов, а не данные пациента. Не переноси его термины в находки без источника. Сохраняй правильные слова, числа, единицы и отрицания. Шаблон определяет стиль, но не содержит фактов пациента.
Верни один JSON-объект по схеме ниже. Значения строк — обычный текст. Заполни каждое обязательное поле. Закончив содержимое поля, перейди к следующему. После последнего поля закрой объект и заверши ответ.
JSON Schema:
"""

EN = """Write an ultrasound report in Russian using only the patient's supplied findings.
description: state the examination findings. Preserve every supplied measurement, unit, side, and negation. Do not invent missing findings. Do not copy complaints or the clinician's separate conclusion into this field.
conclusion: give a concise conclusion supported by the findings, without restating the description. Preserve any separately dictated conclusion. Do not introduce an unsupported diagnosis.
recommendations: include only actions supported by the supplied data; otherwise use null.
descriptionRemarks: identify only contradictions or ambiguities in the clinician's source description. If the same structure is described as both having and not having a finding, cite both statements and request clarification. A later statement overrides an earlier one only when the clinician explicitly corrects it. Do not list missing details or restate the findings. Use null when there is no source problem.
contextualStrings is a spelling vocabulary, not patient evidence. Use it only to correct an unambiguous speech-recognition error in a medical term. Preserve already correct words, numbers, units, and negations. A template supplies style, not patient facts.
Return one JSON object matching the schema below. Write all string values in Russian plain text. Include every required field. After completing each field, proceed to the next field. After the last field, close the object and end the answer.
JSON Schema:
"""


def remove_caps(value: object) -> None:
    if isinstance(value, dict):
        value.pop("maxLength", None)
        for child in value.values():
            remove_caps(child)
    elif isinstance(value, list):
        for child in value:
            remove_caps(child)


def main() -> None:
    catalog = json.loads((ROOT / "backend/main/config/development/ru/l10n.json").read_text())
    cases = json.loads((DIRECTORY.parent / "schema-revision/working-cases.json").read_text())
    variants = {name: [] for name in ("uncapped", "no-dictionary", "concise-ru", "concise-en")}
    for original in cases:
        if original["id"] not in SELECTED:
            continue
        base = copy.deepcopy(original)
        base["actual_main_request"] = False
        remove_caps(base["schema"])
        schema_text = json.dumps(base["schema"], ensure_ascii=False, separators=(",", ":"))
        base["payload"]["response_format"]["json_schema"]["schema"] = copy.deepcopy(base["schema"])
        base["payload"]["repetition_penalty"] = 1.0
        system = base["payload"]["messages"][0]["content"].split("JSON Schema:\n")[0]
        system = system.replace(", не более 512 символов", "")
        system = system.replace("Ограничения maxLength включают указанное число символов. ", "")
        system = system.replace(
            "Пиши кратко, не повторяй уже изложенные сведения и заверши каждую мысль до достижения ограничения; не заполняй поле до предельной длины.",
            "Пиши кратко, не повторяй уже изложенные сведения.",
        )
        assert "512" not in system and "maxLength" not in system
        base["payload"]["messages"][0]["content"] = system + "JSON Schema:\n" + schema_text + "\n"
        Draft202012Validator.check_schema(base["schema"])
        variants["uncapped"].append(copy.deepcopy(base))
        without = copy.deepcopy(base)
        assert catalog["medicalTermCorrectionPrompt"] in without["payload"]["messages"][0]["content"]
        without["payload"]["messages"][0]["content"] = without["payload"]["messages"][0]["content"].replace(catalog["medicalTermCorrectionPrompt"], "")
        without["payload"]["messages"][1]["content"] = "\n".join(
            line for line in without["payload"]["messages"][1]["content"].splitlines()
            if not line.startswith('{"contextualStrings":')
        ) + "\n"
        variants["no-dictionary"].append(without)
        for name, prompt in (("concise-ru", RU), ("concise-en", EN)):
            changed = copy.deepcopy(base)
            changed["payload"]["messages"][0]["content"] = prompt + schema_text + "\n"
            variants[name].append(changed)
    for name, values in variants.items():
        (DIRECTORY / f"{name}-cases.json").write_text(json.dumps(values, ensure_ascii=False, indent=2) + "\n")
        print(name, len(values))
    (DIRECTORY / "screening-manifest.json").write_text(json.dumps(list(variants), indent=2) + "\n")


if __name__ == "__main__":
    main()
