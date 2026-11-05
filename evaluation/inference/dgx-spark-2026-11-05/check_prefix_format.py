"""Compare the actual cached-prefix request token IDs with canonical text blocks."""

import argparse
import json
import subprocess

from run import NAMES, ROOT, TEMP, inspect, save

PROBE = r"""
import json,sys,copy,urllib.request,hashlib
data=json.load(sys.stdin)
case=data['case']
messages=copy.deepcopy(case['payload']['messages'])
messages[-1]['content'][-1]['text']+='\nНомер синтетического запроса: 10-0.'
request=urllib.request.Request('http://127.0.0.1:8000/tokenize',data=json.dumps({'model':case['payload']['model'],'messages':messages,'add_generation_prompt':True}).encode(),headers={'Content-Type':'application/json'})
with urllib.request.urlopen(request,timeout=15) as response:
    value=json.load(response)
original=data['request']['prompt_token_ids']
canonical=value['tokens']
tails={}
for name,tokens in [('recorded',original),('canonical',canonical)]:
    request=urllib.request.Request('http://127.0.0.1:8000/detokenize',data=json.dumps({'model':case['payload']['model'],'tokens':tokens}).encode(),headers={'Content-Type':'application/json'})
    with urllib.request.urlopen(request,timeout=15) as response:
        tails[name]=json.load(response)['prompt'][-180:]
print(json.dumps({'equal_token_ids':original==canonical,'recorded_count':len(original),'canonical_count':len(canonical),'recorded_sha256':hashlib.sha256(json.dumps(original).encode()).hexdigest(),'canonical_sha256':hashlib.sha256(json.dumps(canonical).encode()).hexdigest(),'first_differences':[(i,a,b) for i,(a,b) in enumerate(zip(original,canonical)) if a!=b][:8],'tails':tails},ensure_ascii=False,indent=2))
"""


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--corrected", action="store_true")
    corrected = parser.parse_args().corrected
    profile = "prefix-controls" if corrected else "baseline"
    group = "application-corrected-cold-0" if corrected else "application-cold"
    result = {}
    for index, model in enumerate(["4b", "15-4b", "27b"]):
        case = json.loads((ROOT / f"cases-{model}.json").read_text())[0]
        rows = [
            json.loads(line)
            for line in (ROOT / f"03-prefix-cache/{model}/{profile}/results.jsonl")
            .read_text()
            .splitlines()
        ]
        request = next(
            r
            for r in rows
            if r["event"] == "request" and r["group"] == group and r["wave"] == 0
        )
        container = NAMES[index]
        if not inspect(container)["State"]["Running"]:
            temporary = inspect(TEMP)
            args = temporary["Config"]["Cmd"]
            assert (
                args[args.index("--served-model-name") + 1] == case["payload"]["model"]
            )
            container = TEMP
        process = subprocess.run(
            ["docker", "exec", "-i", container, "python3", "-c", PROBE],
            input=json.dumps({"case": case, "request": request}),
            text=True,
            capture_output=True,
            timeout=30,
        )
        if process.returncode:
            raise RuntimeError(process.stderr)
        result[model] = json.loads(process.stdout)
    name = (
        "corrected-content-format-parity.json"
        if corrected
        else "content-format-parity.json"
    )
    save(ROOT / "03-prefix-cache" / name, result)
    if corrected:
        assert all(r["equal_token_ids"] for r in result.values())
    print(json.dumps(result))


if __name__ == "__main__":
    main()
