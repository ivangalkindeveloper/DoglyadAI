"""Compare JSON formatting on synthetic cases, sequentially on the shared GPU."""

from __future__ import annotations

import argparse
import base64
import json
from pathlib import Path
import subprocess
import sys

from jsonschema.validators import validator_for

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "backend/main"))
from app.core.configuration.configuration_loader import ConfigurationLoader
from app.core.localization.language_code import LanguageCode
from app.model.ultrasound.us_examination_request import USExaminationRequest
from app.model.ultrasound.us_examination_report import USExaminationReport
from app.model.ultrasound.us_voice_form_generation import USVoiceFormGeneration
from app.prompt.prompt_factory import PromptFactory
from app.service.dictation.voice_form_validator import VoiceFormValidator
from app.service.neural_model.mock_neural_model_service import MockNeuralModelService
from app.service.report.report_generation_service import ReportGenerationService
from app.service.report.report_validator import ReportValidator

ROOT = Path(__file__).resolve().parents[3]
DIRECTORY = Path(__file__).parent
MODELS = {
    "4b": "google/medgemma-4b-it",
    "15-4b": "google/medgemma-1.5-4b-it",
    "27b": "google/medgemma-27b-it",
}
REMOTE = r"""
import base64, json, time, urllib.request, importlib.metadata
import xgrammar as xgr
cases=json.loads(base64.b64decode(DATA))
endpoints={
 "google/medgemma-4b-it":"http://vllm_medgemma_4b:8000",
 "google/medgemma-1.5-4b-it":"http://vllm_medgemma_15_4b:8000",
 "google/medgemma-27b-it":"http://vllm_medgemma_27b:8000",
}
opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
grammars={}
for case in cases:
 options={"any_whitespace":case["variant"] not in ("compact","indent2")}
 if case["variant"].startswith("bounded"):options["max_whitespace_cnt"]=int(case["variant"][7:])
 if case["variant"]=="indent2":options["indent"]=2
 key=json.dumps([case["schema"],options],sort_keys=True)
 if key not in grammars:grammars[key]=str(xgr.Grammar.from_json_schema(case["schema"],**options))
 payload={**case["payload"],"structured_outputs":{"grammar":grammars[key]}}
 if payload["stream"]:payload["stream_options"]={"include_usage":True}
 endpoint=endpoints[payload["model"]]
 result={**case,"xgrammar":importlib.metadata.version("xgrammar"),"vllm":importlib.metadata.version("vllm"),"grammar_bytes":len(grammars[key].encode())}
 def active():
  with opener.open(endpoint+"/metrics",timeout=5) as response:metrics=response.read().decode()
  counters=[float(line.split()[-1]) for line in metrics.splitlines() if line.startswith(("vllm:num_requests_running{","vllm:num_requests_waiting{"))]
  assert len(counters)>=2
  return sum(counters)
 result["active_before"]=active()
 started=time.monotonic()
 text,finish,usage,done,first='',None,None,False,None
 try:
  req=urllib.request.Request(endpoint+'/v1/chat/completions',data=json.dumps(payload).encode(),headers={'Content-Type':'application/json'})
  with opener.open(req,timeout=180) as response:
   if payload['stream']:
    for line in response:
     if time.monotonic()-started>180:raise TimeoutError('absolute deadline')
     if not line.startswith(b'data:'):continue
     raw=line[5:].strip()
     if raw==b'[DONE]':done=True;break
     item=json.loads(raw)
     if item.get('usage'):usage=item['usage']
     for choice in item.get('choices',[]):
      part=choice.get('delta',{}).get('content') or ''
      if part and first is None:first=time.monotonic()-started
      text+=part
      finish=choice.get('finish_reason') or finish
   else:
    item=json.load(response)
    text=item['choices'][0]['message']['content'] or ''
    finish=item['choices'][0]['finish_reason']
    usage=item.get('usage')
    done=True
 except Exception as error:result['error']=type(error).__name__
 result.update(text=text,finish=finish,usage=usage,done=done,seconds=round(time.monotonic()-started,3),first_delta_seconds=first)
 for _ in range(20):
  remaining=active()
  if remaining==0:break
  time.sleep(.1)
 result['active_after']=remaining
 print(json.dumps(result,ensure_ascii=False),flush=True)
"""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--cases",
        nargs="+",
        choices=["historical", "report", "conflict", "dictation"],
        default=["historical", "report", "dictation"],
    )
    parser.add_argument("--models", nargs="+", choices=list(MODELS), default=["4b"])
    parser.add_argument(
        "--variants",
        nargs="+",
        choices=["compact", "unbounded", "bounded8", "bounded16", "indent2"],
        default=["bounded8", "bounded16", "indent2"],
    )
    parser.add_argument("--seeds", nargs="+", type=int, default=[0])
    parser.add_argument(
        "--modes", nargs="+", choices=["stream", "buffered"], default=["stream"]
    )
    parser.add_argument("--output", required=True)
    parser.add_argument(
        "--prompt-style",
        choices=["original", "schema", "grounded_remarks"],
        default="original",
    )
    args = parser.parse_args()
    configuration = ConfigurationLoader(ROOT / "backend/main/config/development").load()
    factory = PromptFactory(LanguageCode.RU, configuration)
    reports = ReportGenerationService(configuration, MockNeuralModelService())
    voice = VoiceFormValidator(configuration.voice_source_localization(LanguageCode.RU))
    old = json.loads((DIRECTORY / "old-remarks-ablation.json").read_text())
    base = json.loads((DIRECTORY / "ablation.json").read_text())["body"]
    cases = []
    for model_alias in args.models:
        model = MODELS[model_alias]
        for kind in args.cases:
            body = json.loads(json.dumps(base))
            body["settingsAI"]["selectedNeuralModelId"] = model
            if kind == "conflict":
                body = json.loads(
                    (DIRECTORY / "regression-4b-conflict.json").read_text()
                )["body"]
                body["settingsAI"]["selectedNeuralModelId"] = model
            prepared = reports.prepare(
                USExaminationRequest.model_validate(body), language_code=LanguageCode.RU
            )
            metadata = {"kind": kind, "model": model, "body": body}
            system, prompt, schema = (
                prepared.system_prompt,
                prepared.prompt,
                json.loads(prepared.structured_output),
            )
            temperature, maximum = prepared.temperature, prepared.max_tokens
            if kind == "historical":
                system, prompt, schema = (
                    old["system_prompt"],
                    old["user_prompt"],
                    old["schema"],
                )
                metadata["body"] = old["body"]
            elif kind == "dictation":
                transcript = "Пациент Иванов Иван Иванович. Рост 180 сантиметров. Вес 80 килограммов. Жалобы на дискомфорт в области шеи."
                metadata["transcript"] = transcript
                system = factory.voice_system_prompt()
                prompt = factory.voice_prompt(
                    configuration.resolve_examination_title(
                        "thyroidGland", LanguageCode.RU
                    ),
                    transcript,
                    configuration.resolve_examination_contextual_strings(
                        "thyroidGland", LanguageCode.RU
                    ),
                )
                schema = json.loads(USVoiceFormGeneration.structured_output())
                temperature, maximum = (
                    0,
                    configuration.server.voice_form_parsing.maxTokens,
                )
            if args.prompt_style == "schema":
                system += (
                    "\nВерни один JSON-ответ по следующей схеме. Описания полей задают их назначение. Текст вне JSON не нужен.\n"
                    + json.dumps(schema, ensure_ascii=False)
                )
            if kind != "dictation" and args.prompt_style == "grounded_remarks":
                previous = configuration.text(
                    LanguageCode.RU, "reportDescriptionRemarksPrompt"
                ).format(
                    maxCharacters=configuration.server.report_generation.max_description_remarks_characters
                )
                replacement = "В descriptionRemarks проверяй только блок «Описание ультразвукового исследования». Найди в этом блоке явно несовместимые или неоднозначные утверждения об одной и той же структуре. Для замечания приведи короткие цитаты этих утверждений и укажи, что врачу нужно уточнить. Жалобы пациента и твои медицинские предположения не являются утверждениями из этого блока. Не оценивай полноту обследования: отсутствие размера, объёма или иных сведений само по себе не является противоречием. Не давай здесь рекомендаций по обследованию и лечению. Если в блоке нет несовместимых или неоднозначных утверждений, верни null. Каждую проблему опиши один раз. Более позднее утверждение заменяет раннее только при явно обозначенном исправлении врача. "
                replacement += f"Замечания должны занимать одно или два законченных предложения, не более {configuration.server.report_generation.max_description_remarks_characters} символов.\n"
                assert previous in system
                system = system.replace(previous, replacement)
            metadata["prompt_style"] = args.prompt_style
            for seed in args.seeds:
                for variant in args.variants:
                    for mode in args.modes:
                        cases.append(
                            {
                                **metadata,
                                "variant": variant,
                                "seed": seed,
                                "mode": mode,
                                "schema": schema,
                                "payload": {
                                    "model": model,
                                    "messages": [
                                        {"role": "system", "content": system},
                                        {"role": "user", "content": prompt},
                                    ],
                                    "temperature": temperature,
                                    "max_tokens": maximum,
                                    "repetition_penalty": 1.0,
                                    "seed": seed,
                                    "stream": mode == "stream",
                                },
                            }
                        )
    target = DIRECTORY / args.output
    if target.exists():
        raise FileExistsError(
            "Keep previous evaluation results; choose a new output name"
        )
    code = (
        "DATA="
        + repr(base64.b64encode(json.dumps(cases).encode()).decode())
        + "\n"
        + REMOTE
    )
    process = subprocess.Popen(
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
            "doglyad-dgx-vllm_medgemma_4b-1",
            "python3",
            "-",
        ],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        text=True,
    )
    assert process.stdin is not None and process.stdout is not None
    process.stdin.write(code)
    process.stdin.close()
    with target.open("w") as output:
        for line in process.stdout:
            result = json.loads(line)
            try:
                value = json.loads(result["text"])
                validator_for(result["schema"])(result["schema"]).validate(value)
                result["schema_valid"] = True
            except Exception as error:
                result.update(schema_valid=False, schema_error=type(error).__name__)
            if result["schema_valid"]:
                if result["kind"] != "dictation":
                    try:
                        ReportValidator.validate_repetition(
                            USExaminationReport.model_validate(value)
                        )
                        result["repetition_valid"] = True
                    except Exception:
                        result["repetition_valid"] = False
                try:
                    if result["kind"] == "dictation":
                        parsed = voice.validate(
                            USVoiceFormGeneration.model_validate(value),
                            result["transcript"],
                        )
                        result["validated_value"] = parsed.model_dump(mode="json")
                    else:
                        reports.complete(
                            result["text"],
                            USExaminationRequest.model_validate(result["body"]),
                            model_id=result["model"],
                            language_code=LanguageCode.RU,
                        )
                    result["main_valid"] = True
                except Exception as error:
                    result.update(
                        main_valid=False,
                        main_error=getattr(error, "code", type(error).__name__),
                    )
                if result["kind"] == "dictation" and "validated_value" in result:
                    fields = {
                        p["fieldId"] for p in result["validated_value"]["proposals"]
                    }
                    expected = {
                        "patient_name",
                        "patient_complaints",
                        "patient_height_cm",
                        "patient_weight_kg",
                    }
                    result["missing_expected_fields"] = sorted(expected - fields)
                    result["unexpected_fields"] = sorted(fields - expected)
                if result["kind"] == "conflict":
                    result["has_conflict_remark"] = bool(
                        value.get("descriptionRemarks")
                    )
            output.write(json.dumps(result, ensure_ascii=False) + "\n")
            output.flush()
            print(
                json.dumps(
                    {
                        k: v
                        for k, v in result.items()
                        if k
                        not in (
                            "text",
                            "body",
                            "schema",
                            "payload",
                            "transcript",
                            "validated_value",
                        )
                    },
                    ensure_ascii=False,
                ),
                flush=True,
            )
    if process.wait():
        raise RuntimeError("Remote experiment failed")


if __name__ == "__main__":
    main()
