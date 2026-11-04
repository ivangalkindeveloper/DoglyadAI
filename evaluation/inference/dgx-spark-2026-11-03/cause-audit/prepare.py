"""Freeze one-factor prompt and grammar interventions on two observed failures."""
from pathlib import Path
import copy
import json
D=Path(__file__).resolve().parent
sources=json.loads((D.parent/'prompt-repair/expanded-baseline-cases.json').read_text())
selected={'report-greedy-0','conflict-sample-42','bladder-dictated-sample-42'}
correction=json.loads(Path('backend/main/config/development/ru/l10n.json').read_text())['medicalTermCorrectionPrompt']
variants={k:[] for k in ['control','no-vocabulary-data','no-vocabulary-instruction','no-vocabulary-both','no-grammar']}
for source in sources:
 if source['id'] not in selected:continue
 for name,rows in variants.items():
  c=copy.deepcopy(source)
  if name in ['no-vocabulary-data','no-vocabulary-both']:
   lines=c['payload']['messages'][1]['content'].splitlines(keepends=True)
   assert sum(line.startswith('{"contextualStrings":') for line in lines)==1
   c['payload']['messages'][1]['content']=''.join(line for line in lines if not line.startswith('{"contextualStrings":'))
  if name in ['no-vocabulary-instruction','no-vocabulary-both']:
   text=c['payload']['messages'][0]['content'];assert correction in text
   c['payload']['messages'][0]['content']=text.replace(correction,'')
  if name=='no-grammar':c['payload'].pop('response_format')
  rows.append(c)
for name,rows in variants.items():
 (D/f'{name}-cases.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
(D/'causal-manifest.json').write_text(json.dumps(list(variants),indent=2)+'\n')
# Freeze exact token traces. Never re-encode decoded model output for logit analysis.
rows=[]
for line in (D.parent/'prompt-repair/expanded-baseline-results.jsonl').read_text().splitlines():
 row=json.loads(line)
 if row.get('phase')=='quality' and row['id'] in selected:
  case=next(c for c in variants['control'] if c['id']==row['id'])
  rows.append({'case':case,'trace':row})
(D/'token-traces.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
print({k:len(v) for k,v in variants.items()})
