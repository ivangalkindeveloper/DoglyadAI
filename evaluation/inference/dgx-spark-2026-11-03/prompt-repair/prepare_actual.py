"""Freeze requests composed by the candidate main backend, without prompt overrides."""
from __future__ import annotations
import copy
import hashlib
import json
from pathlib import Path
import sys
D=Path(__file__).resolve().parent
ROOT=D.parents[3]
sys.path.insert(0,str(ROOT/'backend/main'))
from app.core.configuration.configuration_loader import ConfigurationLoader
from app.core.localization.language_code import LanguageCode
from app.model.ultrasound.us_examination_request import USExaminationRequest
from app.service.neural_model.mock_neural_model_service import MockNeuralModelService
from app.service.report.report_generation_service import ReportGenerationService
service=ReportGenerationService(ConfigurationLoader(ROOT/'backend/main/config/development').load(),MockNeuralModelService())
sources=json.loads((D/'expanded-concise-cases.json').read_text())
selected={'report-greedy-0','conflict-sample-42','bladder-conflict-sample-42','bladder-correction-sample-42','bladder-term-sample-42'}
for variant,model in [('actual-4b','google/medgemma-4b-it'),('actual-15-4b','google/medgemma-1.5-4b-it'),('actual-27b','google/medgemma-27b-it')]:
 cases=[]
 for original in sources:
  if variant!='actual-4b' and original['id'] not in selected:continue
  c=copy.deepcopy(original)
  c['model']=model;c['body']['settingsAI']['selectedNeuralModelId']=model
  c['body']['settingsAI']['temperature']=c['payload']['temperature']
  prepared=service.prepare(USExaminationRequest.model_validate(c['body']),language_code=LanguageCode(c.get('language','ru')))
  c['schema']=json.loads(prepared.structured_output)
  c['payload'].update(model=model,temperature=prepared.temperature,max_tokens=prepared.max_tokens,repetition_penalty=prepared.repetition_penalty)
  c['payload']['response_format']['json_schema']['schema']=copy.deepcopy(c['schema'])
  c['payload']['messages']=[{'role':'system','content':prepared.system_prompt},{'role':'user','content':prepared.prompt}]
  c['actual_main_request']=True
  assert prepared.repetition_penalty==1.0 and 'maxLength' not in prepared.structured_output
  cases.append(c)
 (D/f'{variant}-cases.json').write_text(json.dumps(cases,ensure_ascii=False,indent=2)+'\n')
 (D/f'{variant}-manifest.json').write_text(json.dumps([variant])+'\n')
 print(variant,len(cases))
paths=['app/prompt/prompt_factory.py','app/schema/us_examination_report_structured_output.py','app/service/report/report_generation_service.py','config/development/ru/l10n.json','config/development/en/l10n.json','config/development/server.json']
(D/'actual-source.json').write_text(json.dumps({p:hashlib.sha256((ROOT/'backend/main'/p).read_bytes()).hexdigest() for p in paths},indent=2)+'\n')
