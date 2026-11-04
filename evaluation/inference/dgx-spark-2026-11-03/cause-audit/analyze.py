"""Validate raw responses; fence removal is diagnostic and never changes results."""
from __future__ import annotations

from collections import Counter
import importlib.util
import json
from pathlib import Path
import re
import sys

from jsonschema.validators import validator_for

D = Path(__file__).resolve().parent
ROOT = D.parents[3]
sys.path.insert(0, str(ROOT / 'backend/main'))
from app.core.configuration.configuration_loader import ConfigurationLoader
from app.core.localization.language_code import LanguageCode
from app.model.ultrasound.us_examination_request import USExaminationRequest
from app.service.neural_model.mock_neural_model_service import MockNeuralModelService
from app.service.report.report_generation_service import ReportGenerationService

spec = importlib.util.spec_from_file_location('previous_analysis', D.parent / 'schema-revision/analyze_results.py')
assert spec and spec.loader
helpers = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helpers)
service = ReportGenerationService(ConfigurationLoader(ROOT / 'backend/main/config/development').load(), MockNeuralModelService())
summary = {}
for path in sorted(D.glob('*-results.jsonl')):
    name = path.name.removesuffix('-results.jsonl')
    cases = {c['id']: c for c in json.loads((D / f'{name}-cases.json').read_text())}
    checked = []
    for line in path.read_text().splitlines():
        row = json.loads(line)
        if row.get('phase') != 'quality':
            continue
        case = cases[row['id']]
        raw = row['text']
        fenced = raw.startswith('```json\n') and raw.rstrip().endswith('```')
        diagnostic = raw.removeprefix('```json\n').rstrip().removesuffix('```').rstrip() if fenced else raw
        fields = helpers.sections(diagnostic, case['schema'])
        sentences = Counter(s.strip().lower() for s in re.findall(r'[^.!?]+[.!?]', raw) if len(s.strip()) >= 64)
        record = {k: row.get(k) for k in ('id', 'finish', 'seconds', 'usage', 'error', 'done')}
        record.update(
            fenced=fenced, sections=fields,
            raw_maximum_long_sentence_copies=max(sentences.values(), default=0),
            repetition=any(v['maximum_sentence_copies'] >= 3 or v['production_repetition_rejected'] for v in fields.values()),
            raw_schema_valid=False, schema_valid_after_fence_removal=False, main_valid=False,
        )
        try:
            value = json.loads(diagnostic)
            validator_for(case['schema'])(case['schema']).validate(value)
            record['schema_valid_after_fence_removal'] = True
            record['raw_schema_valid'] = not fenced
            record['remarks_present'] = bool(value.get('descriptionRemarks'))
            record['remarks'] = value.get('descriptionRemarks')
            if not fenced:
                service.complete(raw, USExaminationRequest.model_validate(case['body']), model_id=case['model'], language_code=LanguageCode(case.get('language', 'ru')))
                record['main_valid'] = True
        except Exception as error:
            record['validation_error'] = getattr(error, 'code', type(error).__name__)
        checked.append(record)
    assert len({r['id'] for r in checked}) == len(checked)
    summary[name] = {
        'received': len(checked), 'expected': len(cases),
        'complete': {r['id'] for r in checked} == set(cases),
        'finish': dict(Counter(r['finish'] for r in checked)),
        **{k: sum(bool(r.get(k)) for r in checked) for k in ['repetition', 'raw_schema_valid', 'main_valid', 'remarks_present', 'fenced']},
    }
    (D / f'{name}-validation.json').write_text(json.dumps(checked, ensure_ascii=False, indent=2) + '\n')
(D / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary, indent=2))
