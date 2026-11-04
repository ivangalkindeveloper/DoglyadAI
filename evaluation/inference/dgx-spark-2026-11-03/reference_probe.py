"""Compare vLLM with Transformers, temporarily freeing only the 4B engine's RAM."""

from __future__ import annotations

import base64
import json
from pathlib import Path
import subprocess

DIRECTORY = Path(__file__).parent

REFERENCE = r"""
import json, time
from pathlib import Path
import torch
from transformers import AutoModelForImageTextToText, AutoTokenizer
data=json.loads(__import__('base64').b64decode(INPUT))
snapshot=next(Path('/root/.cache/huggingface/hub/models--google--medgemma-4b-it/snapshots').iterdir())
tokenizer=AutoTokenizer.from_pretrained(str(snapshot),local_files_only=True)
started=time.monotonic()
model=AutoModelForImageTextToText.from_pretrained(str(snapshot),local_files_only=True,dtype=torch.bfloat16,device_map={'':'cuda:0'},attn_implementation='sdpa').eval()
print(json.dumps({'event':'loaded','seconds':time.monotonic()-started,'class':type(model).__name__,'dtype':str(model.dtype),'attention':model.config._attn_implementation}),flush=True)
with torch.inference_mode():
 for case in data:
  ids=torch.tensor([case['tokens']],device='cuda')
  logits=model(input_ids=ids,attention_mask=torch.ones_like(ids),logits_to_keep=1,use_cache=False).logits[0,-1].float()
  probabilities=logits.softmax(-1)
  p, tokens=probabilities.topk(20)
  top=[{'id':tid,'text':tokenizer.decode([tid],skip_special_tokens=False),'probability':prob} for tid,prob in zip(tokens.tolist(),p.tolist())]
  print(json.dumps({'event':'probabilities','case':case['case'],'position':case['position'],'top':top,'vllm_top':case['vllm_top']},ensure_ascii=False),flush=True)
  if case['position']==6:
   response=model.generate(input_ids=ids,attention_mask=torch.ones_like(ids),do_sample=False,max_new_tokens=128,repetition_penalty=1.0)
   text=tokenizer.decode(response[0,ids.shape[1]:],skip_special_tokens=False)
   print(json.dumps({'event':'unconstrained_continuation','position':6,'max_new_tokens':128,'text':text},ensure_ascii=False),flush=True)
  del ids,logits,probabilities
print(json.dumps({'event':'finished','seconds':time.monotonic()-started,'max_gpu_allocated_bytes':torch.cuda.max_memory_allocated()}),flush=True)
"""

CONTROLLER = r"""
import json, signal, subprocess, time, urllib.request
payload=json.loads(__import__('base64').b64decode(INPUT))
engine='doglyad-dgx-vllm_medgemma_4b-1'
name='doglyad-repetition-reference-'+str(int(time.time()))
image=subprocess.check_output(['docker','inspect','--format','{{.Image}}',engine],text=True).strip()
assert subprocess.check_output(['docker','inspect','--format','{{.State.Running}}',engine],text=True).strip()=='true'
# Do not interrupt another request. Metrics contain only technical counters.
metrics_code="import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/metrics',timeout=5).read().decode())"
metrics=subprocess.check_output(['docker','exec',engine,'python3','-c',metrics_code],text=True)
for line in metrics.splitlines():
 if line.startswith(('vllm:num_requests_running{','vllm:num_requests_waiting{')):
  assert float(line.split()[-1])==0, 'Engine has active requests'
def interrupted(signum,frame):raise RuntimeError('Reference probe interrupted')
for sig in (signal.SIGTERM,signal.SIGHUP,signal.SIGINT):signal.signal(sig,interrupted)
try:
 subprocess.run(['docker','stop','-t','30',engine],check=True,timeout=60,stdout=subprocess.DEVNULL)
 print(json.dumps({'event':'engine_stopped','engine':engine}),flush=True)
 memory=dict((line.split(':')[0],int(line.split()[1])) for line in open('/proc/meminfo'))
 assert memory['MemAvailable']>22*1024*1024, 'Insufficient free RAM for independent reference'
 result=subprocess.run(['docker','run','--rm','-i','--name',name,'--gpus','all','--network','none','--volumes-from',engine+':ro','-e','HF_HUB_OFFLINE=1','-e','TRANSFORMERS_OFFLINE=1','-e','HF_HUB_DISABLE_PROGRESS_BARS=1','--entrypoint','python3',image,'-'],input=payload['reference'],text=True,timeout=600)
 if result.returncode:raise RuntimeError('Transformers reference failed')
finally:
 subprocess.run(['docker','rm','-f',name],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=30)
 subprocess.run(['docker','start',engine],check=True,timeout=60,stdout=subprocess.DEVNULL)
 print(json.dumps({'event':'engine_restarted','engine':engine}),flush=True)
 for _ in range(120):
  health=subprocess.check_output(['docker','inspect','--format','{{.State.Health.Status}}',engine],text=True).strip()
  if health=='healthy':
   print(json.dumps({'event':'engine_healthy','engine':engine}),flush=True)
   break
  time.sleep(5)
 else:raise RuntimeError('Engine did not become healthy after reference probe')
"""


def main() -> None:
    records = [
        json.loads(line)
        for line in (DIRECTORY / "prefix-probabilities.jsonl").read_text().splitlines()
        if line.startswith('{"case":')
    ]
    cases = [
        {
            "case": r["case"],
            "position": r["position"],
            "tokens": r["choice"]["prompt_token_ids"],
            "vllm_top": r["top"],
        }
        for r in records
        if r["case"] == "baseline-0" and r["position"] in (0, 6, 10)
    ]
    reference = (
        "INPUT="
        + repr(base64.b64encode(json.dumps(cases).encode()).decode())
        + "\n"
        + REFERENCE
    )
    control = (
        "INPUT="
        + repr(base64.b64encode(json.dumps({"reference": reference}).encode()).decode())
        + "\n"
        + CONTROLLER
    )
    with (DIRECTORY / "transformers-reference.jsonl").open("w") as output:
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
                "python3",
                "-",
            ],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            text=True,
        )
        assert process.stdin is not None and process.stdout is not None
        process.stdin.write(control)
        process.stdin.close()
        for line in process.stdout:
            output.write(line)
            output.flush()
            try:
                result = json.loads(line)
                if result.get("event") == "probabilities":
                    result = {
                        **result,
                        "top": result["top"][:3],
                        "vllm_top": result["vllm_top"][:3],
                    }
                print(json.dumps(result, ensure_ascii=False), flush=True)
            except ValueError:
                print(line.rstrip(), flush=True)
        if process.wait():
            raise RuntimeError("Reference probe failed; inspect restoration events")


if __name__ == "__main__":
    main()
