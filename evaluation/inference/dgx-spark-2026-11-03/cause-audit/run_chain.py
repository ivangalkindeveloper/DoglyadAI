from pathlib import Path
import subprocess
import sys
p=Path(__file__).resolve().parent
sys.path.insert(0,str(p.parent/'schema-revision'))
import run_trials as check
import json
before=check.snapshot();counters=check.activity()
for engine in [check.ENGINE,*check.OTHERS[:2]]:check.lifecycle._idle(engine)
(p/'tokens-runtime-before.json').write_text(json.dumps(before,indent=2)+'\n')
try:
 with (p/'token-probe.jsonl').open('x') as out:
  subprocess.run(['docker','exec','-i',check.ENGINE,'python3','-c',(p/'probe_tokens.py').read_text()],input=(p/'token-traces.json').read_text(),stdout=out,text=True,check=True)
finally:
 after=check.snapshot()
 for engine in [check.ENGINE,*check.OTHERS[:2]]:check.lifecycle._health(engine,30);check.lifecycle._idle(engine)
 (p/'tokens-runtime-after.json').write_text(json.dumps(after,indent=2)+'\n')
 assert before==after and check.activity()==counters
print('tokens_verified',flush=True)
subprocess.run(['python3','-u',str(p/'run_experiment.py'),str(p/'causal-manifest.json')],check=True)
