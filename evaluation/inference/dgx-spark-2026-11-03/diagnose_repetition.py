"""Compare synthetic report prompts through the private vLLM stream; no service changes."""

from __future__ import annotations

import argparse
import base64
from collections import Counter
from datetime import UTC, datetime
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "backend/main"))
from app.core.configuration.configuration_loader import ConfigurationLoader
from app.core.localization.language_code import LanguageCode
from app.model.ultrasound.us_examination_request import USExaminationRequest
from app.service.neural_model.mock_neural_model_service import MockNeuralModelService
from app.service.report.report_generation_service import ReportGenerationService

REMOTE = """import json, os, sys, time, urllib.request
payload = json.loads(__import__('base64').b64decode(INPUT))
endpoint = json.loads(os.environ['VLLM_ENDPOINTS'])[payload['model']].rstrip('/')
start = time.monotonic()
request = urllib.request.Request(endpoint+'/v1/chat/completions', data=json.dumps(payload).encode(), headers={'Content-Type':'application/json'})
text, finish, usage, count, done = '', None, None, 0, False
with urllib.request.urlopen(request, timeout=180) as response:
 for line in response:
  if not line.startswith(b'data:'): continue
  data=line[5:].strip()
  if data == b'[DONE]': done=True; break
  item=json.loads(data)
  if item.get('usage'): usage=item['usage']
  for choice in item.get('choices',[]):
   text+=choice.get('delta',{}).get('content') or ''
   finish=choice.get('finish_reason') or finish
   count+=1
print(json.dumps({'text':text,'finish':finish,'usage':usage,'chunks':count,'done':done,'seconds':round(time.monotonic()-start,3)},ensure_ascii=False))
"""


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--variants",
        nargs="+",
        default=["baseline", "schema_prompt", "json_instruction", "schema_prompt_free"],
    )
    parser.add_argument("--seeds", nargs="+", type=int, default=[0, 42])
    parser.add_argument("--output", default="ablation.json")
    parser.add_argument("--old-remarks", action="store_true")
    parser.add_argument("--model", default="google/medgemma-4b-it")
    parser.add_argument("--conflict", action="store_true")
    parser.add_argument("--bounded", action="store_true")
    parser.add_argument("--remarks-first", action="store_true")
    parser.add_argument(
        "--dictionary", choices=["last", "first", "none"], default="last"
    )
    args = parser.parse_args()
    configuration = ConfigurationLoader(ROOT / "backend/main/config/development").load()
    service = ReportGenerationService(configuration, MockNeuralModelService())
    l10n = json.loads(
        (ROOT / "backend/main/config/development/ru/l10n_application.json").read_text()
    )
    body = USExaminationRequest.model_validate(
        {
            "settingsAI": {
                "selectedNeuralModelId": args.model,
                "temperature": 0.3,
                "maxTokens": 2048,
            },
            "examinationData": {
                "usExaminationTypeId": "thyroidGland",
                "examinationNumber": "SYNTHETIC-REPETITION",
                "patientName": "Synthetic Test",
                "patientGender": "male",
                "patientDateOfBirth": "1985-01-15T00:00:00Z",
                "photos": [],
                "patientComplaints": l10n[
                    "scanDevelopmentPatientComplaintsDescription"
                ],
                "examinationDescription": l10n["scanDevelopmentExaminationDescription"],
            },
            "isRecommendationsIncluded": True,
            "isDescriptionRemarks": True,
            "isPhotoRemarks": False,
        }
    )
    if args.conflict:
        body.examinationData.examinationDescription += (
            " В правой доле выявлено очаговое образование."
        )
    prepared = service.prepare(body, language_code=LanguageCode.RU)
    user_prompt = prepared.prompt
    if args.dictionary != "last":
        glossary = (
            json.dumps(
                {
                    "contextualStrings": configuration.resolve_examination_contextual_strings(
                        "thyroidGland", LanguageCode.RU
                    )
                },
                ensure_ascii=False,
            )
            + "\n"
        )
        assert user_prompt.endswith(glossary)
        user_prompt = user_prompt[: -len(glossary)]
        if args.dictionary == "first":
            user_prompt = glossary + "\n" + user_prompt
    schema = json.loads(prepared.structured_output)
    if args.remarks_first:
        properties = schema["properties"]
        schema["properties"] = {
            "descriptionRemarks": properties["descriptionRemarks"],
            **{
                key: value
                for key, value in properties.items()
                if key != "descriptionRemarks"
            },
        }
    system_prompt = prepared.system_prompt
    if args.old_remarks or "old_with_length" in args.variants:
        old = json.loads(
            subprocess.run(
                ["git", "show", "HEAD:backend/main/config/development/ru/l10n.json"],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=True,
            ).stdout
        )
        current = configuration.text(
            LanguageCode.RU, "reportDescriptionRemarksPrompt"
        ).format(
            maxCharacters=configuration.server.report_generation.max_description_remarks_characters
        )
        assert current in system_prompt
        if args.old_remarks:
            system_prompt = system_prompt.replace(
                current, old["reportDescriptionRemarksPrompt"]
            )
            schema["properties"]["descriptionRemarks"]["description"] = old[
                "reportDescriptionRemarksSchemaDescription"
            ]
    # Remove the hard grammar cap in every condition to expose rather than truncate a loop.
    if not args.bounded:
        for branch in schema["properties"]["descriptionRemarks"]["anyOf"]:
            branch.pop("maxLength", None)
    document = {
        "created_at": datetime.now(UTC).isoformat(),
        "model": prepared.model_id,
        "input": "Repository synthetic thyroid fixture; no patient data",
        "conditions": {
            "temperature": 0.3,
            "max_tokens": 2048,
            "repetition_penalty": 1.0,
            "concurrency": 1,
            "remarks_grammar_limit": 512 if args.bounded else None,
            "conflict": args.conflict,
            "dictionary": args.dictionary,
            "remarks_first": args.remarks_first,
        },
        "body": body.model_dump(mode="json"),
        "system_prompt": system_prompt,
        "user_prompt": user_prompt,
        "schema": schema,
        "results": [],
    }
    destination = Path(__file__).parent / args.output
    for seed in args.seeds:
        for variant in args.variants:
            system = system_prompt
            if variant == "grounded_remarks":
                current_remarks = configuration.text(
                    LanguageCode.RU, "reportDescriptionRemarksPrompt"
                ).format(
                    maxCharacters=configuration.server.report_generation.max_description_remarks_characters
                )
                candidate = "Поле descriptionRemarks предназначено для проверки исходного текста врача, а не для медицинских рекомендаций. Ищи только взаимоисключающие утверждения об одном объекте или фразу с несколькими возможными прочтениями. Если найдёшь такую проблему, процитируй соответствующие слова исходного описания и кратко попроси врача уточнить их. Пример противоречия: «Свободной жидкости нет» и «Определяется свободная жидкость»; обе фразы нельзя одновременно принять как результат одного исследования. Отсутствие сведений о характеристике, размере или методе не является противоречием или неоднозначной фразой. Не перечисляй отсутствующие сведения, возможные диагнозы, виды образований или обследования. Если в исходном тексте нет конкретной проблемы, верни null. Одно или два предложения, до 512 символов.\n\n"
                assert current_remarks in system
                system = system.replace(current_remarks, candidate)
            limit_instruction = "Замечания должны занимать одно или два законченных предложения, не более 512 символов. Каждую проблему назови один раз."
            if variant == "current_without_length":
                assert limit_instruction in system
                system = system.replace(limit_instruction, "")
            elif variant == "old_with_length":
                system = system.replace(
                    current,
                    old["reportDescriptionRemarksPrompt"] + limit_instruction + "\n\n",
                )
            if variant.startswith("schema_prompt"):
                system += (
                    "\nВерни только один JSON-объект, соответствующий следующей JSON Schema. Не добавляй текст вне JSON. Описания полей задают их смысл.\n"
                    + json.dumps(schema, ensure_ascii=False, separators=(",", ":"))
                )
            elif variant == "json_instruction":
                system += "\nВерни только один JSON-объект без обёртки Markdown. Поля: description, conclusion, recommendations, descriptionRemarks. Поле descriptionRemarks должно иметь значение null, если замечаний нет. После последнего поля закрой JSON-объект и закончи ответ."
            payload = {
                "model": prepared.model_id,
                "messages": [
                    {"role": "system", "content": [{"type": "text", "text": system}]},
                    {
                        "role": "user",
                        "content": [{"type": "text", "text": user_prompt}],
                    },
                ],
                "temperature": 0.3,
                "max_tokens": 2048,
                "repetition_penalty": 1.0,
                "seed": seed,
                "stream": True,
                "stream_options": {"include_usage": True},
            }
            if variant != "schema_prompt_free":
                payload["response_format"] = {
                    "type": "json_schema",
                    "json_schema": {"name": "report", "schema": schema},
                }
            code = (
                "INPUT="
                + repr(base64.b64encode(json.dumps(payload).encode()).decode())
                + "\n"
                + REMOTE
            )
            response = subprocess.run(
                [
                    "ssh",
                    "-i",
                    str(Path.home() / ".ssh/doglyad-inference"),
                    "-o",
                    "BatchMode=yes",
                    "-o",
                    "ConnectTimeout=5",
                    "ivangalkindeveloper@192.168.0.29",
                    "docker",
                    "exec",
                    "-i",
                    "doglyad-dgx-backend_inference-1",
                    "python",
                    "-",
                ],
                input=code,
                text=True,
                capture_output=True,
                timeout=200,
            )
            if response.returncode:
                result = {
                    "variant": variant,
                    "seed": seed,
                    "transport_error": response.returncode,
                }
            else:
                result = json.loads(response.stdout)
                result.update(variant=variant, seed=seed)
                result["system_prompt"] = system
                try:
                    value = json.loads(result["text"])
                    result["fields"] = {
                        key: len(val) if isinstance(val, str) else None
                        for key, val in value.items()
                    }
                    result["valid_json"] = True
                    result["has_remarks"] = bool(value.get("descriptionRemarks"))
                except (ValueError, AttributeError):
                    result["valid_json"] = False
                try:
                    service.complete(
                        result["text"],
                        body,
                        model_id=prepared.model_id,
                        language_code=LanguageCode.RU,
                    )
                    result["validation"] = "passed"
                except Exception as error:
                    result["validation"] = getattr(error, "code", type(error).__name__)
                sentences = [
                    s.strip()
                    for s in re.split(r"(?<=[.!?])\s+", result["text"])
                    if len(s.strip()) > 40
                ]
                result["max_sentence_copies"] = max(
                    Counter(sentences).values(), default=0
                )
            document["results"].append(result)
            destination.write_text(
                json.dumps(document, ensure_ascii=False, indent=2) + "\n"
            )
            print(
                json.dumps(
                    {
                        k: v
                        for k, v in result.items()
                        if k not in ("text", "system_prompt")
                    },
                    ensure_ascii=False,
                ),
                flush=True,
            )


if __name__ == "__main__":
    main()
