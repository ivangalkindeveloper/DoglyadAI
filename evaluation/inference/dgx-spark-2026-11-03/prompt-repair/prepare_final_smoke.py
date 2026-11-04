"""Verify the retained application configuration after rejecting the candidate."""
from pathlib import Path
import copy
import hashlib
import json
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
cases=[]
for source in json.loads((D/'actual-4b-cases.json').read_text()):
 if source['id'] not in {'report-greedy-0','conflict-sample-42'}:continue
 c=copy.deepcopy(source)
 prepared=service.prepare(USExaminationRequest.model_validate(c['body']),language_code=LanguageCode.RU)
 c['schema']=json.loads(prepared.structured_output)
 c['payload']['response_format']['json_schema']['schema']=c['schema']
 c['payload']['messages']=[{'role':'system','content':prepared.system_prompt},{'role':'user','content':prepared.prompt}]
 c['payload']['repetition_penalty']=prepared.repetition_penalty
 assert prepared.repetition_penalty==1.05 and 'maxLength' not in prepared.structured_output
 cases.append(c)
(D/'final-smoke-cases.json').write_text(json.dumps(cases,ensure_ascii=False,indent=2)+'\n')
(D/'final-smoke-manifest.json').write_text('["final-smoke"]\n')
paths=['app/prompt/prompt_factory.py','app/schema/us_examination_report_structured_output.py','app/service/report/report_generation_service.py','app/service/report/report_validator.py','config/development/ru/l10n.json','config/development/en/l10n.json','config/development/server.json']
(D/'final-source.json').write_text(json.dumps({p:hashlib.sha256((ROOT/'backend/main'/p).read_bytes()).hexdigest() for p in paths},indent=2)+'\n')
