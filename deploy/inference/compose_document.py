"""Build a Compose document from a validated host profile."""

from __future__ import annotations

import json
from typing import Any

from host_profile import HostProfile


def _logging() -> dict[str, Any]:
    return {"driver": "json-file", "options": {"max-size": "20m", "max-file": "5"}}


def _engine(profile: HostProfile, model: dict[str, Any]) -> dict[str, Any]:
    command = [
        "/model" if "weightsDirectory" in model else model["modelId"],
        "--served-model-name",
        model["modelId"],
        "--host",
        "0.0.0.0",
        "--port",
        "8000",
        "--dtype",
        model["dtype"],
    ]
    for key, flag in {
        "maxModelLen": "--max-model-len",
        "maxNumSeqs": "--max-num-seqs",
        "maxNumBatchedTokens": "--max-num-batched-tokens",
        "gpuMemoryUtilization": "--gpu-memory-utilization",
        "tensorParallelSize": "--tensor-parallel-size",
        "kvCacheMemoryBytes": "--kv-cache-memory-bytes",
        "revision": "--revision",
    }.items():
        if key in model:
            command.extend([flag, str(model[key])])
    if "maxImages" in model:
        command.extend(
            ["--limit-mm-per-prompt", json.dumps({"image": model["maxImages"]})]
        )
    if "speculativeConfig" in model:
        config = model["speculativeConfig"]
        command.extend(
            [
                "--speculative-config",
                json.dumps(
                    {
                        "method": config["method"],
                        "num_speculative_tokens": config["numSpeculativeTokens"],
                        "prompt_lookup_min": config["promptLookupMin"],
                        "prompt_lookup_max": config["promptLookupMax"],
                    },
                    separators=(",", ":"),
                ),
            ]
        )
    if model["isEager"]:
        command.append("--enforce-eager")
    if model.get("isRemoteCodeTrusted", False):
        command.append("--trust-remote-code")
    if "chatTemplateKwargs" in model:
        command.extend(
            [
                "--default-chat-template-kwargs",
                json.dumps(model["chatTemplateKwargs"], separators=(",", ":")),
            ]
        )
    command.append(
        "--enable-prefix-caching"
        if model["isPrefixCachingEnabled"]
        else "--no-enable-prefix-caching"
    )
    command.extend(
        [
            "--no-enable-log-requests",
            "--no-enable-log-outputs",
            "--structured-outputs-config",
            '{"backend":"xgrammar","disable_any_whitespace":true}',
        ]
    )
    volumes: list[Any] = ["huggingface:/root/.cache/huggingface"]
    if "weightsDirectory" in model:
        volumes.append(
            {
                "type": "bind",
                "source": model["weightsDirectory"],
                "target": "/model",
                "read_only": True,
                "bind": {"create_host_path": False},
            }
        )
    return {
        "image": model.get("image", profile.data["vllmImage"]),
        "platform": f"linux/{profile.architecture}",
        "command": command,
        "env_file": ["secrets/.env"],
        "volumes": volumes,
        "shm_size": "4gb",
        "deploy": {
            "resources": {
                "reservations": {
                    "devices": [
                        {
                            "driver": "nvidia",
                            "device_ids": model["gpuDeviceIds"],
                            "capabilities": ["gpu"],
                        }
                    ]
                }
            }
        },
        "healthcheck": {
            "test": [
                "CMD",
                "python3",
                "-c",
                "import urllib.request; urllib.request.urlopen('http://localhost:8000/health', timeout=4)",
            ],
            "interval": "15s",
            "timeout": "5s",
            "retries": 5,
            "start_period": "1800s",
        },
        "restart": "unless-stopped",
        "logging": _logging(),
    }


def compose_document(profile: HostProfile) -> dict[str, Any]:
    services = {
        model["service"]: _engine(profile, model) for model in profile.data["models"]
    }
    services["backend_inference"] = {
        "image": "${INFERENCE_BACKEND_IMAGE:?Set a pinned backend image}",
        "platform": f"linux/{profile.architecture}",
        "ports": [
            "${INFERENCE_BACKEND_BIND:?Set the host Tailscale IPv4 address}:${INFERENCE_BACKEND_PORT:-8100}:8000"
        ],
        "volumes": [
            "./secrets/firebase_credentials.json:/app/secrets/firebase_credentials.json:ro",
            "./logs:/app/logs",
            "./config:/app/host-config:ro",
        ],
        "environment": {
            "SERVED_MODEL_ID": "",
            "VLLM_ENDPOINTS": json.dumps(profile.endpoints, separators=(",", ":")),
            "FIREBASE_CREDENTIALS_PATH": "/app/secrets/firebase_credentials.json",
            "CONFIG_DIR": "/app/host-config",
            "LOG_DIR": "/app/logs",
            "LOG_RETENTION_DAYS": "365",
        },
        "restart": "unless-stopped",
        "logging": _logging(),
    }
    services["model_download"] = {
        "profiles": ["download"],
        "image": profile.data["vllmImage"],
        "platform": f"linux/{profile.architecture}",
        "entrypoint": ["hf", "download"],
        "command": [
            "${DOWNLOAD_MODEL_ID:-" + profile.data["models"][0]["modelId"] + "}",
            "--max-workers",
            "1",
        ],
        "env_file": ["secrets/.env"],
        "environment": {
            "HF_XET_HIGH_PERFORMANCE": "0",
            "HF_HUB_DISABLE_PROGRESS_BARS": "1",
        },
        "volumes": ["huggingface:/root/.cache/huggingface"],
        "mem_limit": "8g",
        "memswap_limit": "8g",
        "cpus": 4,
        "restart": "no",
        "logging": _logging(),
    }
    volume = profile.data["weightsVolume"]
    return {
        "name": profile.data["projectName"],
        "x-doglyad-profile": profile.fingerprint,
        "services": services,
        "volumes": {
            "huggingface": {"name": volume["name"], "external": volume["isExternal"]}
        },
    }
