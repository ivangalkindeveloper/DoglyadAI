from __future__ import annotations

import argparse
import asyncio
import json
import math
import re
import time
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

import httpx

from evaluation.voice.datasets.generate import file_sha256
from evaluation.voice.runners.inference_failure_metadata import inference_failure_metadata
from evaluation.voice.runners.refresh_matrix_app_check import refresh_matrix_app_check

REQUEST_INTERVAL_SECONDS = 2.1


async def run_server_matrix_parse(
    *,
    inputs: list[Path],
    output: Path,
    token_file: Path,
    device_id: str,
    base_url: str = "http://127.0.0.1:18000",
    model_id: str = "google/medgemma-4b-it",
    limit: int | None = None,
    concurrency: int = 4,
    reuse_results: list[Path] | None = None,
    inference_ssh_target: str | None = None,
    inference_ssh_control_path: str | None = None,
    generation_profile: Path | None = None,
) -> None:
    if urlparse(base_url).hostname not in ("127.0.0.1", "localhost", "::1"):
        raise ValueError("This experiment is restricted to a locally running main backend")
    if concurrency < 1:
        raise ValueError("Concurrency must be positive")
    profile = None
    if generation_profile:
        profile = json.loads(generation_profile.read_text(encoding="utf-8"))
        if (
            not isinstance(profile, dict)
            or set(profile) != {"modelRevision", "promptSha256", "generationParameters", "serverBuildId"}
            or any(
                not isinstance(profile.get(key), str) or not profile[key].strip()
                for key in ("modelRevision", "promptSha256", "serverBuildId")
            )
            or not isinstance(profile.get("generationParameters"), dict)
            or not {"temperature", "maxTokens"}.issubset(profile["generationParameters"])
        ):
            raise ValueError(
                "Incomplete generation profile: record deployed weights, prompt, parameters and server build"
            )
        temperature = profile["generationParameters"]["temperature"]
        max_tokens = profile["generationParameters"]["maxTokens"]
        if (
            not re.fullmatch(r"[0-9a-f]{64}", profile["promptSha256"])
            or isinstance(temperature, bool)
            or not isinstance(temperature, (int, float))
            or not math.isfinite(temperature)
            or temperature < 0
            or type(max_tokens) is not int
            or max_tokens < 1
        ):
            raise ValueError("Invalid prompt hash or generation parameters")
    if reuse_results and profile is None:
        raise ValueError("Cross-run reuse requires a recorded generation profile")
    cases: list[dict[str, Any]] = []
    for path in inputs:
        for line in path.read_text(encoding="utf-8").splitlines():
            row = json.loads(line)
            cases.append(
                {
                    key: value
                    for key, value in row.items()
                    if key not in ("methods", "rawGeneration", "isGenerationReused")
                }
            )
    if len({row["id"] for row in cases}) != len(cases):
        raise ValueError("Duplicate extraction input")
    if limit is not None:
        cases = [cases[round(i * (len(cases) - 1) / max(limit - 1, 1))] for i in range(min(limit, len(cases)))]
    output.parent.mkdir(parents=True, exist_ok=True)
    settings_path = output.with_suffix(".settings.json")
    if output.exists() and not settings_path.exists():
        raise ValueError("Saved server results have no original settings; start a new run")
    settings = {
        "modelId": model_id,
        "generationProfile": profile,
        "generationProfileSha256": file_sha256(generation_profile) if generation_profile else None,
        "generationProfileOrigin": "operatorProvided" if profile else "unrecorded",
        "baseURL": base_url,
        "sourceHashes": {str(path): file_sha256(path) for path in inputs},
        "caseIds": [row["id"] for row in cases],
        "runnerSha256": file_sha256(Path(__file__)),
        "concurrency": concurrency,
        "requestIntervalSeconds": REQUEST_INTERVAL_SECONDS,
        "reuseResults": {str(path): file_sha256(path) for path in reuse_results or []},
        "inferenceDiagnostics": {
            "sshTarget": inference_ssh_target,
            "controlPath": inference_ssh_control_path,
            "sourceSha256": file_sha256(Path(__file__).with_name("inference_failure_metadata.py")),
        },
    }
    if settings_path.exists() and json.loads(settings_path.read_text(encoding="utf-8")) != settings:
        raise ValueError("Server matrix resume settings differ")
    settings_path.write_text(json.dumps(settings, indent=2) + "\n", encoding="utf-8")
    previous = [json.loads(line) for line in output.read_text(encoding="utf-8").splitlines()] if output.exists() else []
    completed = {row["id"] for row in previous}
    if len(completed) != len(previous):
        raise ValueError("Duplicate saved server result")
    by_id = {case["id"]: case for case in cases}
    if any(
        row["id"] not in by_id
        or any(row.get(key) != by_id[row["id"]].get(key) for key in ("locale", "examinationTypeId", "text"))
        for row in previous
    ):
        raise ValueError("Saved server results differ from frozen inputs")
    if previous and len(completed) < len(cases) and profile is None:
        raise ValueError("Cannot resume an incomplete run without its generation profile; start a new measured run")
    cache: dict[tuple[str, str, str], dict[str, Any]] = {}
    for path in reuse_results or []:
        prior_settings = json.loads(path.with_suffix(".settings.json").read_text(encoding="utf-8"))
        if any(
            prior_settings.get(key) != settings[key]
            for key in ("modelId", "baseURL", "runnerSha256", "generationProfileSha256")
        ):
            raise ValueError("Reused generation came from a different model or runner")
        for line in path.read_text(encoding="utf-8").splitlines():
            row = json.loads(line)
            if row["status"] not in ("ok", "failed"):
                raise ValueError("Unexpected reused generation status")
            cache[row["locale"], row["examinationTypeId"], row["text"]] = {
                **row,
                "generationOrigin": {"path": str(path), "sha256": settings["reuseResults"][str(path)], "id": row["id"]},
            }
    for row in previous:
        if row["status"] in ("ok", "failed"):
            cache[row["locale"], row["examinationTypeId"], row["text"]] = row
    groups: dict[tuple[str, str, str], list[dict[str, Any]]] = {}
    for case in cases:
        if case["id"] not in completed:
            groups.setdefault((case["locale"], case["examinationTypeId"], case["text"]), []).append(case)
    if not groups:
        print("All server matrix cases already completed", flush=True)
        return

    semaphore = asyncio.Semaphore(concurrency)
    rate_lock = asyncio.Lock()
    token_lock = asyncio.Lock()
    output_lock = asyncio.Lock()
    last_request = 0.0
    refreshed = 0.0
    unique_requests = 0
    saved = len(previous)

    async def token(is_force_refresh: bool = False) -> str:
        nonlocal refreshed
        async with token_lock:
            if is_force_refresh or not token_file.exists() or time.monotonic() - refreshed > 1800:
                await asyncio.to_thread(
                    refresh_matrix_app_check,
                    device_id=device_id,
                    token_file=token_file,
                    log_directory=output.parent / "app-check",
                )
                refreshed = time.monotonic()
            return token_file.read_text(encoding="utf-8").strip()

    async def request_slot() -> None:
        nonlocal last_request
        # The public route's 30/minute limiter stays active with overlapping GPU
        # generations. Retries consume slots from this same global schedule.
        async with rate_lock:
            await asyncio.sleep(max(0.0, last_request + REQUEST_INTERVAL_SECONDS - time.monotonic()))
            last_request = time.monotonic()

    with output.open("a", encoding="utf-8") as destination:
        async with httpx.AsyncClient(timeout=145.0) as client:

            async def process_group(key: tuple[str, str, str], members: list[dict[str, Any]]) -> None:
                nonlocal unique_requests, saved
                async with semaphore:
                    response_row = cache.get(key)
                    attempts: list[dict[str, Any]] = []
                    if response_row is None:
                        case = members[0]
                        for attempt in range(3):
                            value = await token()
                            await request_slot()
                            started = time.monotonic()
                            try:
                                response = await client.post(
                                    base_url.rstrip("/") + "/v1/ultrasound/parse_dictation",
                                    headers={"X-Firebase-AppCheck": value, "Accept-Language": case["locale"]},
                                    json={
                                        "selectedNeuralModelId": model_id,
                                        "usExaminationTypeId": case["examinationTypeId"],
                                        "transcript": case["text"],
                                    },
                                )
                                unique_requests += 1
                                attempts.append(
                                    {
                                        "statusCode": response.status_code,
                                        "seconds": time.monotonic() - started,
                                        "requestId": response.headers.get("X-Request-ID"),
                                    }
                                )
                                if response.status_code == 401:
                                    await token(is_force_refresh=True)
                                    continue
                                if response.status_code == 429:
                                    await asyncio.sleep(30)
                                    continue
                                if (
                                    response.status_code == 500
                                    and not response.headers.get("X-Request-ID")
                                    and response.text.strip() == "Internal Server Error"
                                ):
                                    # FastAPI's uncaught application error is an
                                    # observed failure of the current full path.
                                    # Known transport failures are mapped to 502.
                                    response_row = {
                                        "id": case["id"],
                                        "status": "failed",
                                        "failureKind": "backendInternalError",
                                        "reason": "Unhandled backend error while processing this input",
                                        "serverSeconds": time.monotonic() - started,
                                        "attempts": attempts,
                                    }
                                    cache[key] = response_row
                                    break
                                diagnostic = None
                                request_id = response.headers.get("X-Request-ID")
                                if (
                                    response.status_code == 502
                                    and request_id
                                    and inference_ssh_target
                                    and inference_ssh_control_path
                                ):
                                    diagnostic = await inference_failure_metadata(
                                        request_id=request_id,
                                        ssh_target=inference_ssh_target,
                                        control_path=inference_ssh_control_path,
                                    )
                                    attempts[-1]["inferenceDiagnostic"] = diagnostic
                                if diagnostic and diagnostic.get("isModelGenerationFailure"):
                                    response_row = {
                                        "id": case["id"],
                                        "status": "failed",
                                        "failureKind": "invalidGeneration",
                                        "reason": "Model engine returned invalid JSON; finishReason="
                                        + str(diagnostic.get("finishReason")),
                                        "serverSeconds": time.monotonic() - started,
                                        "attempts": attempts,
                                    }
                                    cache[key] = response_row
                                    break
                                if (
                                    response.status_code == 502
                                    and response.json().get("detail") == "Invalid voice parse response"
                                ):
                                    # The route received a model answer and
                                    # rejected its schema. This is an observed
                                    # generation failure, not an outage to retry
                                    # until the model happens to succeed.
                                    response_row = {
                                        "id": case["id"],
                                        "status": "failed",
                                        "failureKind": "invalidGeneration",
                                        "reason": "Invalid voice parse response",
                                        "serverSeconds": time.monotonic() - started,
                                        "attempts": attempts,
                                    }
                                    cache[key] = response_row
                                    break
                                response.raise_for_status()
                                body = response.json()
                                if not isinstance(body.get("proposals"), list):
                                    raise ValueError("Backend returned no proposal array")
                                response_row = {
                                    "id": case["id"],
                                    "status": "ok",
                                    "serverResponse": body,
                                    "serverSeconds": time.monotonic() - started,
                                    "attempts": attempts,
                                }
                                cache[key] = response_row
                                break
                            except (httpx.HTTPError, ValueError) as error:
                                attempts.append(
                                    {
                                        "errorType": type(error).__name__,
                                        "reason": str(error)[:500],
                                        "seconds": time.monotonic() - started,
                                    }
                                )
                        if response_row is None:
                            failure = {
                                "id": case["id"],
                                "recognizer": case["recognizer"],
                                "locale": case["locale"],
                                "attempts": attempts,
                            }
                            async with output_lock:
                                with output.with_suffix(".technical-failures.jsonl").open(
                                    "a", encoding="utf-8"
                                ) as failures:
                                    failures.write(json.dumps(failure, ensure_ascii=False) + "\n")
                            raise RuntimeError(
                                f"Server matrix stopped after technical failures at {case['id']}; restore connectivity and resume"
                            )
                    async with output_lock:
                        for case in members:
                            is_reused = (
                                case["id"] != response_row["id"] or response_row.get("generationOrigin") is not None
                            )
                            row = {
                                **case,
                                "caseId": case["matrixCaseId"],
                                "generationModelId": model_id,
                                "status": response_row["status"],
                                "serverResponse": response_row.get("serverResponse"),
                                "failureKind": response_row.get("failureKind"),
                                "reason": response_row.get("reason"),
                                "isGenerationReused": is_reused,
                                "generationReusedFrom": response_row["id"] if is_reused else None,
                                "generationOrigin": response_row.get("generationOrigin"),
                                "serverSeconds": 0.0 if is_reused else response_row["serverSeconds"],
                                "attempts": [] if is_reused else response_row["attempts"],
                            }
                            destination.write(json.dumps(row, ensure_ascii=False) + "\n")
                            saved += 1
                        destination.flush()
                        print(
                            f"MedGemma {saved}/{len(cases)}; unique HTTP requests this run {unique_requests}",
                            flush=True,
                        )

            tasks = [asyncio.create_task(process_group(key, members)) for key, members in groups.items()]
            try:
                await asyncio.gather(*tasks)
            except BaseException:
                for task in tasks:
                    task.cancel()
                await asyncio.gather(*tasks, return_exceptions=True)
                raise
    print(f"Completed {len(cases)} server paths", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description="Run every ASR transcript through the protected LOCAL main backend")
    parser.add_argument("--inputs", nargs="+", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--token-file", type=Path, required=True)
    parser.add_argument("--device-id", required=True)
    parser.add_argument("--base-url", default="http://127.0.0.1:18000")
    parser.add_argument("--limit", type=int)
    parser.add_argument("--concurrency", type=int, default=4)
    parser.add_argument("--model-id", default="google/medgemma-4b-it")
    parser.add_argument("--inference-ssh-target")
    parser.add_argument("--inference-ssh-control-path")
    parser.add_argument("--reuse-results", nargs="+", type=Path)
    parser.add_argument("--generation-profile", type=Path)
    args = parser.parse_args()
    asyncio.run(
        run_server_matrix_parse(
            inputs=args.inputs,
            generation_profile=args.generation_profile,
            output=args.output,
            token_file=args.token_file,
            device_id=args.device_id,
            base_url=args.base_url,
            limit=args.limit,
            concurrency=args.concurrency,
            model_id=args.model_id,
            inference_ssh_target=args.inference_ssh_target,
            inference_ssh_control_path=args.inference_ssh_control_path,
            reuse_results=args.reuse_results,
        )
    )


if __name__ == "__main__":
    main()
