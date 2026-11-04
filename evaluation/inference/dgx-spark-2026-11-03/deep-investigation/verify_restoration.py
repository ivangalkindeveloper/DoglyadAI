"""Verify the original DGX services and record only non-secret runtime fields."""

import json
from pathlib import Path
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "runtime-comparison"))
import run_remote_comparison as lifecycle


def main() -> None:
    directory = Path(__file__).resolve().parent
    before = json.loads((directory / "solutions/runtime-before.json").read_text())
    result = {}
    for name, original in before.items():
        current = lifecycle._inspect(name)
        assert current["Id"] == original["id"]
        assert current["Image"] == original["image"]
        assert current["Config"]["Cmd"] == original["cmd"]
        assert current["State"]["Running"]
        if "vllm_medgemma_4b" not in name:
            assert current["State"]["StartedAt"] == original["started_at"]
        entry = {
            "id": current["Id"],
            "image": current["Image"],
            "started_at": current["State"]["StartedAt"],
            "running": True,
        }
        if "vllm" in name:
            lifecycle._health(name, 30)
            lifecycle._idle(name)
            entry.update(health_http=200, running_requests=0, waiting_requests=0)
            cmd = current["Config"]["Cmd"]
            entry["max_num_seqs"] = int(cmd[cmd.index("--max-num-seqs") + 1])
            entry["versions"] = json.loads(
                subprocess.check_output(
                    [
                        "docker",
                        "exec",
                        name,
                        "python3",
                        "-c",
                        "import json,importlib.metadata as m;print(json.dumps({n:m.version(n) for n in ['vllm','xgrammar']}))",
                    ],
                    text=True,
                )
            )
        else:
            code = """import json,urllib.request,urllib.error
request=urllib.request.Request('http://127.0.0.1:8000/v1/generation',data=b'{}',headers={'Content-Type':'application/json'})
try:
    response=urllib.request.urlopen(request,timeout=10)
    status=response.status
except urllib.error.HTTPError as error:
    status=error.code
assert status==401,status
print(json.dumps({'without_app_check':status}))
"""
            entry.update(
                json.loads(
                    subprocess.check_output(
                        ["docker", "exec", name, "python3", "-c", code], text=True
                    )
                )
            )
        result[name] = entry
    for name in ("doglyad-deep-evaluation", "doglyad-qwen-evaluation-download"):
        assert (
            subprocess.run(["docker", "inspect", name], capture_output=True).returncode
            != 0
        )
    (directory / "restoration-verified.json").write_text(
        json.dumps(result, indent=2) + "\n"
    )
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
