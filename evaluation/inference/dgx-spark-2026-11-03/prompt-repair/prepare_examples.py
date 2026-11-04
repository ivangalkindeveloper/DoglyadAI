"""Compare demonstrations and field order without limiting generated strings."""

from __future__ import annotations

import copy
import json
from pathlib import Path

from prepare_screening import RU

DIRECTORY = Path(__file__).resolve().parent
EXAMPLES = [
    {
        "input": "Описание исследования: Мочевой пузырь: объём 240 мл. Содержимое анэхогенное. В просвете визуализируется конкремент 6 мм. Заключение врача: Конкремент мочевого пузыря.",
        "output": {
            "description": "Мочевой пузырь: объём 240 мл. Содержимое анэхогенное. В просвете визуализируется конкремент 6 мм.",
            "conclusion": "Конкремент мочевого пузыря.",
            "recommendations": None,
            "descriptionRemarks": None,
        },
    },
    {
        "input": "Описание исследования: Желчный пузырь: стенка 2 мм. Конкременты не выявлены. В просвете выявлен конкремент 7 мм.",
        "output": {
            "description": "Желчный пузырь: стенка 2 мм. В исходном описании указано отсутствие конкрементов и наличие конкремента 7 мм.",
            "conclusion": "Данные о наличии конкремента противоречивы; требуется уточнение.",
            "recommendations": None,
            "descriptionRemarks": 'В исходном описании одновременно указаны «Конкременты не выявлены» и «В просвете выявлен конкремент 7 мм». Уточните, есть ли конкремент.',
        },
    },
]


def main() -> None:
    original = json.loads((DIRECTORY / "concise-ru-cases.json").read_text())
    variants = ("ru-examples", "ru-remarks-first", "ru-examples-first", "ru-examples-no-dictionary")
    for variant in variants:
        cases = copy.deepcopy(original)
        for case in cases:
            schema = case["schema"]
            if variant.endswith("first"):
                schema["properties"] = {key: schema["properties"][key] for key in ("descriptionRemarks", "description", "conclusion", "recommendations")}
                schema["required"] = list(schema["properties"])
            prompt = RU.split("JSON Schema:\n")[0]
            if "examples" in variant:
                examples = copy.deepcopy(EXAMPLES)
                for example in examples:
                    example["output"] = {key: example["output"][key] for key in schema["properties"]}
                prompt += "Следующие примеры показывают формат и работу с источником. Они не относятся к текущему пациенту; не переноси их числа или находки в ответ.\n"
                for example in examples:
                    prompt += "Пример входа: " + example["input"] + "\nПример ответа: " + json.dumps(example["output"], ensure_ascii=False) + "\n"
            if variant.endswith("no-dictionary"):
                prompt = "\n".join(line for line in prompt.splitlines() if not line.startswith("contextualStrings")) + "\n"
                case["payload"]["messages"][1]["content"] = "\n".join(line for line in case["payload"]["messages"][1]["content"].splitlines() if not line.startswith('{"contextualStrings":')) + "\n"
            prompt += "JSON Schema:\n" + json.dumps(schema, ensure_ascii=False, separators=(",", ":")) + "\n"
            case["payload"]["messages"][0]["content"] = prompt
            case["payload"]["response_format"]["json_schema"]["schema"] = copy.deepcopy(schema)
        (DIRECTORY / f"{variant}-cases.json").write_text(json.dumps(cases, ensure_ascii=False, indent=2) + "\n")
    (DIRECTORY / "examples-manifest.json").write_text(json.dumps(variants, indent=2) + "\n")


if __name__ == "__main__":
    main()
