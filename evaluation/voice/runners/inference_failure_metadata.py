from __future__ import annotations

import asyncio
import json
import re
import shlex
import subprocess
from typing import Any


def parse_failure_metadata(log: str, request_id: str) -> dict[str, Any]:
    lines = [line for line in log.splitlines() if f"request_id={request_id}:" in line]
    scoped = "\n".join(lines)
    value = re.search(r"finish_reason=(\w+), prompt_tokens=(\d+), completion_tokens=(\d+)", scoped)
    is_invalid_json = "Failed to parse vLLM response: JSONDecodeError" in scoped
    return {
        "requestId": request_id,
        "isModelGenerationFailure": bool(value and is_invalid_json and "vLLM response: status=200" in scoped),
        "finishReason": value.group(1) if value else None,
        "promptTokens": int(value.group(2)) if value else None,
        "completionTokens": int(value.group(3)) if value else None,
        "parseError": "JSONDecodeError" if is_invalid_json else None,
    }


async def inference_failure_metadata(*, request_id: str, ssh_target: str, control_path: str) -> dict[str, Any]:
    if re.fullmatch(r"[a-f0-9]{32}", request_id) is None:
        return {"isModelGenerationFailure": False, "reason": "Unrecognized request ID"}
    # Filter on the VM: neither prompts nor generated text leave through logs.
    program = """import json,re,subprocess,sys
request_id=sys.argv[1]
r=subprocess.run(['docker','logs','--since','5m','doglyad-voice-eval-backend_inference-1'],capture_output=True,text=True)
lines=[line for line in (r.stdout+r.stderr).splitlines() if 'request_id='+request_id+':' in line]
safe=[]
for line in lines:
 for pattern in [r'vLLM response: status=\\d+',r'finish_reason=\\w+, prompt_tokens=\\d+, completion_tokens=\\d+',r'Failed to parse vLLM response: JSONDecodeError']:
  match=re.search(pattern,line)
  if match:safe.append('request_id='+request_id+': '+match.group())
print(json.dumps({'metadataLog':'\\n'.join(safe),'isLogReadSuccessful':r.returncode==0}))
"""
    command = [
        "ssh",
        "-S",
        control_path,
        "-o",
        "BatchMode=yes",
        ssh_target,
        "python3 -c " + shlex.quote(program) + " " + shlex.quote(request_id),
    ]
    try:
        result = await asyncio.to_thread(subprocess.run, command, capture_output=True, text=True, timeout=15)
        body = json.loads(result.stdout) if result.returncode == 0 else {}
        return parse_failure_metadata(body.get("metadataLog", ""), request_id)
    except (OSError, subprocess.TimeoutExpired, ValueError):
        return {"requestId": request_id, "isModelGenerationFailure": False, "reason": "Diagnostic metadata unavailable"}
