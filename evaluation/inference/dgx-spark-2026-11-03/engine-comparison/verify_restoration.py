"""Check original DGX containers, engine limits, and unauthenticated API rejection."""

import json
from pathlib import Path
import subprocess
import sys

DIRECTORY = Path(__file__).resolve().parent
sys.path.insert(0, str(DIRECTORY.parent / "runtime-comparison"))
import run_remote_comparison as lifecycle  # noqa: E402


def main() -> None:
    before = json.loads((DIRECTORY / "vllm-maxseq-1/runtime-before.json").read_text())
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
            "health": current["State"].get("Health", {}).get("Status"),
        }
        if "vllm" in name:
            lifecycle._health(name, 30)
            lifecycle._idle(name)
            cmd = current["Config"]["Cmd"]
            entry.update(
                health_http=200,
                running_requests=0,
                waiting_requests=0,
                max_num_seqs=int(cmd[cmd.index("--max-num-seqs") + 1]),
            )
            assert entry["max_num_seqs"] == 4
        else:
            code = """import json,urllib.request,urllib.error
result={}
for route in ('generation', 'generation/stream'):
    request=urllib.request.Request('http://127.0.0.1:8000/v1/'+route,data=b'{}',headers={'Content-Type':'application/json'})
    try:
        status=urllib.request.urlopen(request,timeout=10).status
    except urllib.error.HTTPError as error:
        status=error.code
    assert status==401,(route,status)
    result[route]=status
print(json.dumps(result))
"""
            entry["without_app_check"] = json.loads(
                subprocess.check_output(
                    ["docker", "exec", name, "python3", "-c", code], text=True
                )
            )
        result[name] = entry
    assert (
        subprocess.run(
            ["docker", "inspect", "doglyad-engine-evaluation"], capture_output=True
        ).returncode
        != 0
    )
    (DIRECTORY / "restoration-verified.json").write_text(
        json.dumps(result, indent=2) + "\n"
    )
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
