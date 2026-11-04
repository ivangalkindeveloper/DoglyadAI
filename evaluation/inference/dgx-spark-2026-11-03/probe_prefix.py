"""Inspect unmasked next-token probabilities and grammar masks on synthetic prefixes."""

from __future__ import annotations

import argparse
import base64
import json
from pathlib import Path
import re
import subprocess

DIRECTORY = Path(__file__).parent

REMOTE = r"""
import json, math, urllib.request
from pathlib import Path
import torch
import xgrammar as xgr
from transformers import AutoTokenizer

data=json.loads(__import__('base64').b64decode(INPUT))
snapshot=next(Path('/root/.cache/huggingface/hub/models--google--medgemma-4b-it/snapshots').iterdir())
tokenizer=AutoTokenizer.from_pretrained(str(snapshot), local_files_only=True)
config=json.loads((snapshot/'config.json').read_text())
vocab_size=config.get('text_config',config)['vocab_size']
info=xgr.TokenizerInfo.from_huggingface(tokenizer, vocab_size=vocab_size)
compiler=xgr.GrammarCompiler(info)

def post(route,payload):
 req=urllib.request.Request('http://127.0.0.1:8000'+route,data=json.dumps(payload).encode(),headers={'Content-Type':'application/json'})
 with urllib.request.urlopen(req,timeout=90) as r: return json.load(r)

for case in data:
 compiled=compiler.compile_json_schema(case['schema'],any_whitespace=False)
 matcher=xgr.GrammarMatcher(compiled,override_stop_tokens=[1,106])
 compact_prefix_accepted=matcher.accept_string(case['prefix'])
 bitmask=xgr.allocate_token_bitmask(1,vocab_size)
 matcher.fill_next_token_bitmask(bitmask)
 relaxed=xgr.GrammarMatcher(compiler.compile_json_schema(case['schema'],any_whitespace=True),override_stop_tokens=[1,106])
 assert relaxed.accept_string(case['prefix'])
 relaxed_mask=xgr.allocate_token_bitmask(1,vocab_size)
 relaxed.fill_next_token_bitmask(relaxed_mask)
 messages=[{'role':'system','content':case['system']},{'role':'user','content':case['user']}]
 # Ask the running server to apply its actual chat template.
 prompt=post('/tokenize',{'model':'google/medgemma-4b-it','messages':messages,'add_generation_prompt':True})['tokens']
 prompt+=tokenizer.encode(case['prefix'],add_special_tokens=False)
 response=post('/v1/completions',{
  'model':'google/medgemma-4b-it','prompt':prompt,'add_special_tokens':False,
  'max_tokens':1,'temperature':0,'repetition_penalty':1.0,'ignore_eos':True,
  'skip_special_tokens':False,'logprobs':20,'return_tokens_as_token_ids':True,'return_token_ids':True})
 choice=response['choices'][0]
 probabilities=choice['logprobs']['top_logprobs'][0]
 tops=[]
 for key,lp in probabilities.items():
  tid=int(key.split(':')[-1])
  allowed=bool((int(bitmask[0,tid//32])>>(tid%32))&1) if compact_prefix_accepted else None
  relaxed_allowed=bool((int(relaxed_mask[0,tid//32])>>(tid%32))&1)
  tops.append({'id':tid,'text':tokenizer.decode([tid],skip_special_tokens=False),'probability':math.exp(lp),'allowed':allowed,'relaxed_allowed':relaxed_allowed})
 result={**{k:case[k] for k in ('case','position','prefix')},'compact_prefix_accepted':compact_prefix_accepted,'top':tops,'choice':choice,'usage':response['usage']}
 print(json.dumps(result,ensure_ascii=False),flush=True)
"""


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--before-punctuation", action="store_true")
    parser.add_argument("--pretty", action="store_true")
    parser.add_argument("--output", default="prefix-probabilities.jsonl")
    args = parser.parse_args()
    document = json.loads((DIRECTORY / "old-remarks-ablation.json").read_text())
    cases = []
    for result in document["results"]:
        if result["finish"] != "length":
            continue
        text = result["text"]
        system = document["system_prompt"]
        if result["variant"] == "schema_prompt":
            system += (
                "\nВерни только один JSON-объект, соответствующий следующей JSON Schema. Не добавляй текст вне JSON. Описания полей задают их смысл.\n"
                + json.dumps(
                    document["schema"], ensure_ascii=False, separators=(",", ":")
                )
            )
        start = text.index('"descriptionRemarks":')
        boundaries = [m.end() for m in re.finditer(r"[.!?](?=\s)", text[start:])]
        for index in (0, 1, 2, 3, 4, 6, 10):
            if index >= len(boundaries):
                continue
            prefix = text[: start + boundaries[index] - int(args.before_punctuation)]
            if args.pretty:
                output_prefix = []
                in_string = False
                escaped = False
                for char in prefix:
                    if in_string:
                        output_prefix.append(char)
                        if escaped:
                            escaped = False
                        elif char == "\\":
                            escaped = True
                        elif char == '"':
                            in_string = False
                    elif char == '"':
                        in_string = True
                        output_prefix.append(char)
                    elif char in "{,":
                        output_prefix.append(char + "\n  ")
                    elif char == ":":
                        output_prefix.append(": ")
                    elif not char.isspace():
                        output_prefix.append(char)
                prefix = "".join(output_prefix)
            cases.append(
                {
                    "case": f"{result['variant']}-{result['seed']}",
                    "position": index,
                    "system": result.get("system_prompt", system),
                    "user": document["user_prompt"],
                    "schema": document["schema"],
                    "prefix": prefix,
                }
            )
    code = (
        "INPUT="
        + repr(base64.b64encode(json.dumps(cases).encode()).decode())
        + "\n"
        + REMOTE
    )
    path = DIRECTORY / args.output
    with path.open("w") as output:
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
        for line in process.stdout:
            output.write(line)
            output.flush()
            if not line.startswith('{"case":'):
                print(line.rstrip(), flush=True)
                continue
            result = json.loads(line)
            print(
                json.dumps(
                    {
                        "case": result["case"],
                        "position": result["position"],
                        "top": result["top"][:5],
                    },
                    ensure_ascii=False,
                ),
                flush=True,
            )
        if process.wait() != 0:
            raise RuntimeError("Remote prefix probe failed")


if __name__ == "__main__":
    main()
