"""Paired uncapped baseline and concise instruction on expanded synthetic cases."""
from __future__ import annotations
import copy
import json
import sys
from pathlib import Path
from prepare_screening import RU, EN, remove_caps
D=Path(__file__).resolve().parent
ROOT=D.parents[3]
sys.path.insert(0,str(ROOT/'backend/main'))
from app.core.configuration.configuration_loader import ConfigurationLoader
from app.core.localization.language_code import LanguageCode
from app.model.ultrasound.us_examination_request import USExaminationRequest
from app.service.report.report_generation_service import ReportGenerationService
from app.service.neural_model.mock_neural_model_service import MockNeuralModelService
config=ConfigurationLoader(ROOT/'backend/main/config/development').load()
service=ReportGenerationService(config,MockNeuralModelService())
originals=json.loads((D.parent/'schema-revision/working-cases.json').read_text())
new=[
 ('bladder-normal','bladder','Мочевой пузырь наполнен, объём 240 мл. Стенка 2 мм, содержимое анэхогенное. Конкременты не определяются.', 'ru', None),
 ('bladder-conflict','bladder','Мочевой пузырь наполнен, объём 240 мл. В мочевом пузыре конкрементов нет. В мочевом пузыре выявлен конкремент 6 мм с акустической тенью.', 'ru',None),
 ('bladder-correction','bladder','Мочевой пузырь наполнен, объём 240 мл. Конкрементов нет. Исправляюсь: в мочевом пузыре есть конкремент 4 мм с акустической тенью.', 'ru',None),
 ('bladder-dictated','bladder','Мочевой пузырь наполнен, объём 230 мл, стенка 2,7 мм. В просвете мелкодисперсная взвесь. Заключение: Эхопризнаки взвеси в мочевом пузыре.', 'ru',None),
 ('bladder-term','bladder','Мочевой пузырь объёмом 250 мл, стенка 2 мм, анофагенное содержимое. Конкременты не определяются.', 'ru',None),
 ('kidneys-normal','kidneysAdrenalGlandsAndRetroperitonealSpace','Правая почка 102×45 мм, паренхима 15 мм. Левая почка 105×48 мм, паренхима 16 мм. Чашечно-лоханочная система с обеих сторон не расширена. Конкременты не выявлены.', 'ru',None),
 ('bladder-template','bladder','Мочевой пузырь объёмом 240 мл. Стенка 2 мм.', 'ru','Описание: [данные исследования]. Заключение: [вывод по данным]. Пример: конкременты не выявлены.'),
 ('bladder-en','bladder','The bladder volume is 240 ml. The wall is 2 mm thick. Contents are anechoic. No bladder stones are seen.', 'en',None),
]
for identifier,exam,description,language,template in new:
 c=copy.deepcopy(originals[0]);c['id']=identifier+'-sample-42';c['kind']='heldout';c['language']=language
 c['payload'].update(temperature=0.3,seed=42)
 c['body']['examinationData'].update(usExaminationTypeId=exam,examinationDescription=description,patientComplaints=None)
 c['body']['template']=template
 originals.append(c)
variants={'expanded-baseline':[],'expanded-concise':[]}
for original in originals:
 c=copy.deepcopy(original)
 lang=LanguageCode(c.get('language','ru'))
 prepared=service.prepare(USExaminationRequest.model_validate(c['body']),language_code=lang)
 c['schema']=json.loads(prepared.structured_output);remove_caps(c['schema'])
 st=json.dumps(c['schema'],ensure_ascii=False,separators=(',',':'))
 c['payload']['response_format']['json_schema']['schema']=copy.deepcopy(c['schema'])
 system=prepared.system_prompt.split('JSON Schema:\n')[0]
 system=system.replace(', не более 512 символов','').replace(', maximum 512 characters','')
 system=system.replace('Ограничения maxLength включают указанное число символов. ','').replace('maxLength limits include the stated number of characters. ','')
 system=system.replace('Пиши кратко, не повторяй уже изложенные сведения и заверши каждую мысль до достижения ограничения; не заполняй поле до предельной длины.','Пиши кратко, не повторяй уже изложенные сведения.')
 system=system.replace('Be concise, do not repeat information, and complete each thought before reaching its limit; do not fill a field up to its maximum length.','Be concise and do not repeat information.')
 c['payload']['messages']=[{'role':'system','content':system+'JSON Schema:\n'+st+'\n'},{'role':'user','content':prepared.prompt}]
 c['payload']['repetition_penalty']=1.0;c['actual_main_request']=False
 variants['expanded-baseline'].append(copy.deepcopy(c))
 c['payload']['messages'][0]['content']=(RU if lang==LanguageCode.RU else EN.replace('in Russian','in English'))+st+'\n'
 variants['expanded-concise'].append(c)
for name,cases in variants.items():
 (D/f'{name}-cases.json').write_text(json.dumps(cases,ensure_ascii=False,indent=2)+'\n')
(D/'expanded-manifest.json').write_text(json.dumps(list(variants),indent=2)+'\n')
print({name:len(cases) for name,cases in variants.items()})
