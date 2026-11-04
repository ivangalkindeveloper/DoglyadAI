"""Freeze report requests using the changed main and inference request builders."""
from __future__ import annotations

import asyncio
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys

import httpx

D = Path(__file__).resolve().parent
ROOT = D.parents[3]
sys.path.insert(0, str(ROOT / 'backend/main'))
from app.core.configuration.configuration_loader import ConfigurationLoader
from app.core.localization.language_code import LanguageCode
from app.model.ultrasound.us_examination_request import USExaminationRequest
from app.service.neural_model.inference_service import InferenceService
from app.service.neural_model.mock_neural_model_service import MockNeuralModelService
from app.service.report.report_generation_service import ReportGenerationService


async def main() -> None:
    configurations = {env: ConfigurationLoader(ROOT / f'backend/main/config/{env}').load() for env in ('development', 'production')}
    services = {env: ReportGenerationService(config, MockNeuralModelService()) for env, config in configurations.items()}
    sources = json.loads((D.parent / 'prompt-repair/expanded-baseline-cases.json').read_text())
    failed = {'conflict-sample-0', 'conflict-sample-42', 'bladder-dictated-sample-42', 'bladder-template-sample-42'}
    async with httpx.AsyncClient() as client:
        transport = InferenceService(client, {}, configurations['development'].server.inference)
        for label, model in [('4b', 'google/medgemma-4b-it'), ('15-4b', 'google/medgemma-1.5-4b-it'), ('27b', 'google/medgemma-27b-it')]:
            cases = []
            for source in sources:
                c = copy.deepcopy(source)
                c['model'] = model
                c['body']['settingsAI']['selectedNeuralModelId'] = model
                c['body']['settingsAI']['temperature'] = c['payload']['temperature']
                body = USExaminationRequest.model_validate(c['body'])
                prepared = {env: service.prepare(body, language_code=LanguageCode(c.get('language', 'ru'))) for env, service in services.items()}
                dev, prod = prepared['development'], prepared['production']
                assert dev.system_prompt == prod.system_prompt
                assert dev.prompt == prod.prompt
                assert dev.structured_output == prod.structured_output
                assert dev.repetition_penalty == prod.repetition_penalty == 1.05
                assert 'contextualStrings' not in dev.prompt + dev.system_prompt
                assert 'maxLength' not in dev.structured_output
                _, request = transport._prepare(dev)
                c['transport_request'] = request.model_dump(exclude_none=True)
                c['schema'] = json.loads(dev.structured_output)
                c['seed'] = c['payload']['seed']
                c.pop('payload')
                c['actual_main_request'] = True
                c['environment_prompts_identical'] = True
                cases.append(c)
            converted = subprocess.run(
                [sys.executable, str(D / 'prepare_engine.py')], input=json.dumps(cases), text=True,
                capture_output=True, check=True, cwd=ROOT / 'backend/inference',
            )
            cases = json.loads(converted.stdout)
            diagnostic = []
            for c in cases:
                if c['id'] in failed:
                    neutral = copy.deepcopy(c)
                    neutral['payload']['repetition_penalty'] = 1.0
                    neutral['actual_main_request'] = False
                    neutral['diagnostic_override'] = {'repetition_penalty': 1.0}
                    diagnostic.append(neutral)
            for name, rows in [(f'{label}-working', cases), (f'{label}-neutral', diagnostic)]:
                (D / f'{name}-cases.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2) + '\n')
            (D / f'{label}-manifest.json').write_text(json.dumps([f'{label}-working', f'{label}-neutral']) + '\n')
            print({'model': model, 'working': len(cases), 'neutral': len(diagnostic)})
    paths = ['backend/main/app/prompt/prompt_factory.py', 'backend/main/app/service/report/report_generation_service.py',
             'backend/main/app/schema/us_examination_report_structured_output.py', 'backend/main/app/service/neural_model/inference_service.py',
             'backend/inference/app/service/vllm_service.py', 'backend/main/config/development/server.json',
             'backend/main/config/production/server.json']
    paths += [f'backend/main/config/{env}/{lang}/l10n.json' for env in ('development', 'production') for lang in ('ru', 'en')]
    (D / 'source.json').write_text(json.dumps({p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}, indent=2) + '\n')


if __name__ == '__main__':
    asyncio.run(main())
