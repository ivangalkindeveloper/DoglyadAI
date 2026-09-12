# backend/inference — GPU inference service

This standalone service is deployed **on a GPU VM** beside the model runtime. It runs a local vLLM instance, accepts ready-to-use prompts, images, and a JSON Schema from the coordinating backend, and returns structured generated content.

## Architecture

```text
                              ┌─────────────────────────────────────────────┐
                              │ GPU VM (one VM per model)                  │
                              │                                            │
iOS ──► backend/main ────────►│ backend/inference ──► vLLM (localhost)     │
        (non-GPU VM)          │ App Check             configured model    │
                              └─────────────────────────────────────────────┘
```

- **backend/main** ([`../main`](../main)) runs on a non-GPU VM. It builds prompts, selects a model, and routes the request. It does not run inference.
- **backend/inference** (this service) runs once per model VM. It validates App Check and calls its local vLLM instance.

Prompts, localization, and templates remain in the main backend. This service receives final text and has no product-domain knowledge.

The main backend selects a VM by model ID through `backend/main/secrets/inference_endpoints.json`. Every model in the published configuration must have a mapping; a missing entry is a configuration error.

## Why App Check is verified again

The token is verified twice: once at the system entry point (`backend/main`) and once here. `backend/main` reads `X-Firebase-AppCheck` from the incoming request and forwards it **unchanged**, so both services validate the same token.

The second check protects the VM that hosts the model. Network access to its port must not be enough to run generation. The first check protects the public system entry point; the second prevents callers from bypassing the main backend and reaching inference directly.

Validation is **unconditional**. There is no bypass flag, and the service cannot start without `secrets/firebase_credentials.json`. Consequently, the service has no unauthenticated endpoints. A fresh VM cannot be tested with an anonymous `curl`; use a valid token from a running app. Observe model readiness in the logs with `make start-backend-inference-logs`.

## API

| Method | Path | App Check | Description |
|---|---|---:|---|
| `POST` | `/v1/generation` | Yes | Generate one response |

This is the service's only endpoint, and it is protected by App Check. Nothing is exposed anonymously: reaching the model VM's port alone must not grant model access.

Request:

```json
{
  "modelId": "example/model",
  "prompt": "..."
}
```

Only `modelId` and `prompt` are required. `systemPrompt`, `structuredOutput`, `images`, `temperature`, and `maxTokens` are optional. Non-null optional values are forwarded to vLLM; `structuredOutput` must contain a JSON Schema object when supplied.

Response:

```json
{ "modelId": "example/model", "response": "..." }
```

`modelId` is compared with `SERVED_MODEL_ID`. A mismatch returns `400` instead of silently generating with a different model.

A rate limiter is unnecessary here because the only client is the main backend, which already limits requests by client address. A limiter at this layer would group every caller under the main backend's single IP address.

## Deployment

1. Install Docker, NVIDIA drivers, and NVIDIA Container Toolkit on the VM.
2. Copy the repository, or at least `backend/inference/`.
3. Create `backend/inference/secrets/`:
   - `.env` with `SERVED_MODEL_ID`, `HF_TOKEN`, `FIREBASE_CREDENTIALS_PATH`, `INFERENCE_BACKEND_*`, and `VLLM_*` values;
   - `firebase_credentials.json` with the Firebase service account.
4. Start the stack:

```bash
make start-backend-inference        # docker compose --env-file backend/inference/secrets/.env -f backend/inference/docker-compose.yml up --build -d
make start-backend-inference-logs
make stop-backend-inference
```

`--env-file` is required. Compose substitutes `${VAR}` references in `docker-compose.yml` only from its own environment file; values from a service's `env_file:` section are not available for Compose-file interpolation.

The first start downloads weights from Hugging Face (about 8 GB for a 4B model) and takes several minutes. The `huggingface` volume persists weights across restarts, so the download happens only once. The vLLM health check uses `start_period: 900s` to avoid marking the container unhealthy while the model is loading.

Follow `make start-backend-inference-logs` to observe readiness: vLLM first reports weight loading, then the backend logs `Inference service started`.

## vLLM configuration

The key values account for model parameters and available GPU memory:

| Variable | Value | Reason |
|---|---|---|
| `VLLM_MAX_MODEL_LEN` | `16384` | Limits both request length and the encoder profiling run at startup. Very large model defaults can exhaust GPU memory during profiling. |
| `VLLM_LIMIT_MM_PER_PROMPT` | `10` | Maximum images per request. Compose converts the value to the JSON accepted by vLLM. The default one-image limit rejects requests containing multiple images. |
| `VLLM_MAX_NUM_SEQS` | `16` | Maximum concurrent sequences. The default 256 is excessive for this workload and increases profiling memory use. |
| `VLLM_GPU_MEMORY_UTILIZATION` | `0.90` | Leaves headroom for activations and fragmentation. Startup OOM errors are addressed with `VLLM_MAX_MODEL_LEN`, not this value alone. |
| `VLLM_TENSOR_PARALLEL_SIZE` | `1` | Must equal the number of GPUs in the VM. |
| `VLLM_IMAGE` | `vllm/vllm-openai:v0.27.1@sha256:c2f3b1b964e47809b722b5e75b61b1e7b39a50f70388cf2bf2418f16a9f31da2` | Tested `linux/amd64` image pinned by digest. The image determines the CUDA build; a GPU newer than that build may fail on its first CUDA operation with `no kernel image is available for execution on the device`. |

## Development

```bash
cd backend/inference
../../.venv311/bin/python -m ruff check app tests
../../.venv311/bin/python -m ruff format app tests
../../.venv311/bin/python -m mypy
../../.venv311/bin/python -m pytest
```

Development dependencies are listed in `requirements-dev.txt`. The service intentionally mirrors the `backend/main/` structure (`app/core`, `app/model`, `app/route`, and `app/service`) and keeps local copies of `logging.py` and `app_check.py`. The deployments are independent, while these files are small and change infrequently.

The two services have almost identical `app_check.py` modules and both enforce validation unconditionally. A shared package would add deployment coupling for very little code.
