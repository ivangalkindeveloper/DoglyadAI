"""A/B decoder formatting on the exact historical synthetic request."""

from __future__ import annotations

import argparse
import base64
import json
from pathlib import Path
import re
import subprocess

DIRECTORY = Path(__file__).parent
REMOTE = r"""
import json, re, time, urllib.request
from collections import Counter
import xgrammar as xgr
data=json.loads(__import__('base64').b64decode(INPUT))
for case in data:
 payload=case['payload']
 if case['variant']=='whitespace':
  grammar=xgr.Grammar.from_json_schema(case['schema'],any_whitespace=True)
  payload['structured_outputs']={'grammar':str(grammar)}
 elif case['variant']=='compact_grammar':
  grammar=xgr.Grammar.from_json_schema(case['schema'],any_whitespace=False)
  payload['structured_outputs']={'grammar':str(grammar)}
 start=time.monotonic()
 req=urllib.request.Request('http://127.0.0.1:8000/v1/chat/completions',data=json.dumps(payload).encode(),headers={'Content-Type':'application/json'})
 text,finish,usage,done='',None,None,False
 with urllib.request.urlopen(req,timeout=180) as response:
  for line in response:
   if not line.startswith(b'data:'):continue
   raw=line[5:].strip()
   if raw==b'[DONE]':done=True;break
   item=json.loads(raw)
   if item.get('usage'):usage=item['usage']
   for choice in item.get('choices',[]):
    text+=choice.get('delta',{}).get('content') or ''
    finish=choice.get('finish_reason') or finish
 sentences=[s.strip() for s in re.split(r'(?<=[.!?])\s+',text) if len(s.strip())>40]
 result={**case,'text':text,'finish':finish,'usage':usage,'done':done,'seconds':round(time.monotonic()-start,3),'copies':max(Counter(sentences).values(),default=0)}
 try:
  json.loads(text);result['valid_json']=True
 except ValueError:result['valid_json']=False
 print(json.dumps(result,ensure_ascii=False),flush=True)
"""


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--variants",
        nargs="+",
        default=[
            "whitespace",
            "compact_grammar",
            "fenced_prefix",
            "unconstrained_prefix",
        ],
    )
    parser.add_argument("--seeds", nargs="+", type=int, default=[0, 42])
    parser.add_argument("--output", default="grammar-comparison.jsonl")
    parser.add_argument("--source", default="old-remarks-ablation.json")
    parser.add_argument("--prefix-sentence", type=int, default=1)
    parser.add_argument("--prefix-before-punctuation", action="store_true")
    parser.add_argument("--temperature", type=float, default=0.3)
    parser.add_argument("--max-tokens", type=int, default=2048)
    args = parser.parse_args()
    source = json.loads((DIRECTORY / args.source).read_text())
    cases = []
    for seed in args.seeds:
        for variant in args.variants:
            messages = [
                {"role": "system", "content": source["system_prompt"]},
                {"role": "user", "content": source["user_prompt"]},
            ]
            payload = {
                "model": source["model"],
                "messages": messages,
                "max_tokens": args.max_tokens,
                "temperature": args.temperature,
                "repetition_penalty": 1.0,
                "seed": seed,
                "stream": True,
                "stream_options": {"include_usage": True},
            }
            if variant == "fenced_prefix":
                messages.append({"role": "assistant", "content": "```json\n"})
                payload.update(continue_final_message=True, add_generation_prompt=False)
                payload["response_format"] = {
                    "type": "json_schema",
                    "json_schema": {"name": "report", "schema": source["schema"]},
                }
            if variant in ("unconstrained_prefix", "pretty_prefix"):
                old = next(
                    r
                    for r in source["results"]
                    if r["seed"] == seed and r["variant"] == "baseline"
                )["text"]
                start = old.index('"descriptionRemarks":')
                boundaries = [m.end() for m in re.finditer(r"[.!?](?=\s)", old[start:])]
                end = (
                    start
                    + boundaries[args.prefix_sentence - 1]
                    - int(args.prefix_before_punctuation)
                )
                prefix = old[:end]
                if variant == "pretty_prefix":
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
                messages.append({"role": "assistant", "content": prefix})
                payload.update(
                    continue_final_message=True,
                    add_generation_prompt=False,
                    max_tokens=min(1024, args.max_tokens),
                )
            cases.append(
                {
                    "seed": seed,
                    "variant": variant,
                    "schema": source["schema"],
                    "payload": payload,
                }
            )
    code = (
        "INPUT="
        + repr(base64.b64encode(json.dumps(cases).encode()).decode())
        + "\n"
        + REMOTE
    )
    container = {
        "google/medgemma-4b-it": "doglyad-dgx-vllm_medgemma_4b-1",
        "google/medgemma-1.5-4b-it": "doglyad-dgx-vllm_medgemma_15_4b-1",
        "google/medgemma-27b-it": "doglyad-dgx-vllm_medgemma_27b-1",
    }[source["model"]]
    with (DIRECTORY / args.output).open("w") as output:
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
                container,
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
            try:
                result = json.loads(line)
                print(
                    json.dumps(
                        {
                            k: v
                            for k, v in result.items()
                            if k not in ("text", "schema", "payload")
                        },
                        ensure_ascii=False,
                    ),
                    flush=True,
                )
            except ValueError:
                print(line.rstrip(), flush=True)
        if process.wait() != 0:
            raise RuntimeError("Remote grammar comparison failed")


if __name__ == "__main__":
    main()
