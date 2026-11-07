"""Run synthetic pairs on existing private DGX engines without changing them.

Run on DGX, after copying this directory and the historical probe.py beside it.
The first patient warms a unique group salt; the second tests shared-prefix reuse.
Full responses are retained for subsequent application validation on the Mac.
"""

from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
import subprocess
import time
import urllib.request
from uuid import uuid4

from probe import request

ROOT = Path(__file__).resolve().parent
SERVICES = {
    "4b": "vllm_medgemma_4b",
    "15-4b": "vllm_medgemma_15_4b",
    "27b": "vllm_medgemma_27b",
}


def inspect(model: str) -> dict:
    data = json.loads(
        subprocess.check_output(
            ["docker", "inspect", "doglyad-dgx-" + SERVICES[model] + "-1"],
            text=True,
            timeout=15,
        )
    )[0]
    addresses = [
        network["IPAddress"]
        for network in data["NetworkSettings"]["Networks"].values()
        if network["IPAddress"]
    ]
    assert len(addresses) == 1
    assert (
        data["State"]["Running"]
        and data["State"].get("Health", {}).get("Status") == "healthy"
    )
    return {
        "id": data["Id"],
        "image": data["Image"],
        "command": data["Config"]["Cmd"],
        "url": "http://" + addresses[0] + ":8000",
    }


def metrics(url: str) -> dict:
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with opener.open(url + "/metrics", timeout=10) as response:
        raw = response.read().decode()
    totals = {}
    for line in raw.splitlines():
        if line.startswith("vllm:"):
            name = line.split("{", 1)[0].split()[0]
            if name in {
                "vllm:num_requests_running",
                "vllm:num_requests_waiting",
                "vllm:prefix_cache_hits_total",
                "vllm:prefix_cache_queries_total",
                "vllm:request_success_total",
                "vllm:num_preemptions_total",
            }:
                totals[name] = totals.get(name, 0) + float(line.split()[-1])
    return totals


def idle(values: dict) -> bool:
    return (
        values.get("vllm:num_requests_running") == 0
        and values.get("vllm:num_requests_waiting") == 0
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--models", nargs="+", choices=SERVICES, default=list(SERVICES))
    parser.add_argument("--scenarios", nargs="+", default=["ru-photo1-template1"])
    parser.add_argument(
        "--variants",
        nargs="+",
        choices=["baseline", "template_first", "stable_schema", "combined"],
        default=["baseline", "template_first", "stable_schema", "combined"],
    )
    parser.add_argument("--repetitions", type=int, default=2)
    parser.add_argument(
        "--output-tokens",
        type=int,
        help="Technical fixed-token probe; does not produce a complete report",
    )
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    assert args.repetitions > 0
    cases = {case["id"]: case for case in json.loads((ROOT / "cases.json").read_text())}
    runtime = {model: inspect(model) for model in args.models}
    for info in runtime.values():
        assert idle(metrics(info["url"])), "Engine is busy"
    namespace = "prefix-study-" + uuid4().hex
    with args.output.open("x") as output:
        output.write(
            json.dumps(
                {
                    "event": "start",
                    "namespace": namespace,
                    "runtime": runtime,
                    "unix": time.time(),
                    "fixed_output_tokens": args.output_tokens,
                }
            )
            + "\n"
        )
        output.flush()
        for model in args.models:
            for patient in (0, 1):
                case = cases[f"{model}:{args.scenarios[0]}:baseline:{patient}"]
                payload = copy.deepcopy(case["payload"])
                payload.update(
                    max_tokens=16, cache_salt=f"{namespace}:warmup:{model}:{patient}"
                )
                result = request(payload, runtime[model]["url"])
                output.write(
                    json.dumps(
                        {
                            "event": "warmup",
                            "model": model,
                            "patient": patient,
                            **result,
                        },
                        ensure_ascii=False,
                    )
                    + "\n"
                )
                output.flush()
                assert result["done"] and not result.get("error"), "Warmup failed"
        for repetition in range(args.repetitions):
            variants = (
                args.variants if repetition % 2 == 0 else list(reversed(args.variants))
            )
            for scenario in args.scenarios:
                for variant in variants:
                    for model in args.models:
                        url = runtime[model]["url"]
                        for patient in (0, 1):
                            case_id = f"{model}:{scenario}:{variant}:{patient}"
                            case = cases[case_id]
                            payload = copy.deepcopy(case["payload"])
                            if args.output_tokens is not None:
                                payload.update(
                                    max_tokens=args.output_tokens, ignore_eos=True
                                )
                            payload["cache_salt"] = (
                                f"{namespace}:{repetition}:{scenario}:{variant}:{model}"
                            )
                            before = metrics(url)
                            assert idle(before), "Engine is busy"
                            started = time.time()
                            result = request(payload, url)
                            # vLLM can publish completion counters shortly after SSE closes.
                            deadline = time.monotonic() + 10
                            while True:
                                after = metrics(url)
                                delta = after.get(
                                    "vllm:request_success_total", 0
                                ) - before.get("vllm:request_success_total", 0)
                                if (
                                    delta >= 1 and idle(after)
                                ) or time.monotonic() >= deadline:
                                    break
                                time.sleep(0.1)
                            row = {
                                "event": "request",
                                "is_fixed_token_probe": args.output_tokens is not None,
                                "case_id": case_id,
                                "repetition": repetition,
                                "phase": "cold" if patient == 0 else "shared_prefix",
                                "unix": started,
                                "metrics_before": before,
                                "metrics_after": after,
                                **result,
                            }
                            output.write(json.dumps(row, ensure_ascii=False) + "\n")
                            output.flush()
                            print(
                                json.dumps(
                                    {
                                        "case": case_id,
                                        "repetition": repetition,
                                        "phase": row["phase"],
                                        "seconds": result["seconds"],
                                        "ttft": result["ttft"],
                                        "finish": result["finish"],
                                        "completion_delta": delta,
                                    }
                                ),
                                flush=True,
                            )
                            assert delta == 1, (
                                "Another request contaminated this measurement, or completion failed"
                            )
                            assert result["done"] and not result.get("error"), (
                                "Transport failed; evidence retained"
                            )
        final = {model: inspect(model) for model in args.models}
        assert final == runtime
        output.write(
            json.dumps(
                {"event": "complete", "runtime_unchanged": True, "unix": time.time()}
            )
            + "\n"
        )


if __name__ == "__main__":
    main()
