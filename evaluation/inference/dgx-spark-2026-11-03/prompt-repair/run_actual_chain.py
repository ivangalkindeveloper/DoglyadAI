"""Wait for the paired experiment, then test actual requests on each engine."""
from pathlib import Path
import subprocess
import time
D=Path(__file__).resolve().parent
start=time.monotonic()
while 'runtime_verified' not in (D/'expanded-controller.log').read_text():
 if 'Traceback' in (D/'expanded-controller.log').read_text():raise RuntimeError('Expanded comparison failed')
 if time.monotonic()-start>1800:raise TimeoutError('Expanded comparison did not complete')
 time.sleep(2)
for variant,engine in [('actual-4b','doglyad-dgx-vllm_medgemma_4b-1'),('actual-15-4b','doglyad-dgx-vllm_medgemma_15_4b-1'),('actual-27b','doglyad-dgx-vllm_medgemma_27b-1')]:
 print('starting',variant,flush=True)
 with (D/f'{variant}-controller.log').open('x') as log:
  subprocess.run(['python3','-u',str(D/'run_experiment.py'),str(D/f'{variant}-manifest.json'),engine],stdout=log,stderr=subprocess.STDOUT,check=True)
 print('verified',variant,flush=True)
