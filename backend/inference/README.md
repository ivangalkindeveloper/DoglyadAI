# backend/inference — GPU inference service

This standalone service is deployed **once per GPU host** beside its model runtimes. It routes ready-to-use prompts, images, and a JSON Schema to the configured local vLLM engine and returns generated content.

## Architecture

```text
                              ┌─────────────────────────────────────────────┐
                              │ GPU host (one or more models)              │
                              │                                            │
iOS ──► backend/main ────────►│ backend/inference ──► vLLM (localhost)     │
        (non-GPU VM)          │ App Check             configured model    │
                              └─────────────────────────────────────────────┘
```

- **backend/main** ([`../main`](../main)) runs on a non-GPU VM. It builds prompts, selects a model, and routes the request. It does not run inference.
- **backend/inference** (this service) runs once per GPU host. It validates App Check and selects a private vLLM engine by `modelId`.

Prompts, localization, and templates remain in the main backend. This service receives final text and has no product-domain knowledge.

The main backend selects an inference service by model ID through `backend/main/secrets/inference_endpoints.json`. Every published model must have a mapping; models on the same host share a service URL.

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

`modelId` selects an entry in the configured engine map. An unknown ID returns `400` without an upstream request. Caller-supplied model IDs can never supply a destination URL.

Single-model deployments retain `SERVED_MODEL_ID` and `VLLM_BASE_URL`.
For multiple models, clear `SERVED_MODEL_ID` and supply `VLLM_ENDPOINTS` as JSON:

```json
{"example/model-a":"http://engine-a:8000","example/model-b":"http://engine-b:8000"}
```

These are trusted host settings. Startup rejects an empty map, ambiguous single/multi-model settings, blank IDs, non-HTTP URLs, URL credentials, query strings and fragments. Engines remain private inside Docker. A shared HTTP client serves all routes; each model has its own bounded queue.

Client-IP rate limits live in main. This service applies separate body, image and generation-capacity limits from `config/server.json`; requests from both main environments share the same model capacity.

## Deployment on managed VMs

For a DGX Spark, use [the ARM64 deployment guide](../../deploy/dgx-spark/README.md).
One Compose project contains a shared inference service and three private vLLM
engines. App Check remains mandatory.
New host deployments can use [host profiles and the Compose generator](../../deploy/inference/README.md).
Each profile generates its own engine definitions and `VLLM_ENDPOINTS`; profiles
can contain one or several models. Generation does not start or update containers.

Use [deploy/README.md](../../deploy/README.md) for provisioning and the central `make check-infrastructure` / `make update-infrastructure` commands for existing servers. Those commands use published GHCR images and preserve the running vLLM container during backend updates.

## Running from source on a development GPU VM

The commands below build from the repository using `backend/inference/docker-compose.yml`. They are for a separate development GPU environment, not updates to managed `/opt/doglyad` deployments.

1. Install Docker, NVIDIA drivers, and NVIDIA Container Toolkit on the VM.
2. Copy the repository, or at least `backend/inference/`.
3. Create `backend/inference/secrets/`:
   - `.env` with `SERVED_MODEL_ID`, `HF_TOKEN`, `FIREBASE_CREDENTIALS_PATH`, `INFERENCE_BACKEND_*`, and `VLLM_*` values;
   - `firebase_credentials.json` with the Firebase service account.
4. Start the stack:

```bash
make start-backend-inference        # builds, prepares storage permissions, starts Compose
make start-backend-inference-logs
make stop-backend-inference
```

`--env-file` is required. Compose substitutes `${VAR}` references in `docker-compose.yml` only from its own environment file; values from a service's `env_file:` section are not available for Compose-file interpolation.

The inference backend image runs as UID/GID `10001:10001`. The startup command uses a temporary root helper to prepare credentials and log-directory permissions before starting this non-root process. Credentials remain read-only inside the backend. The third-party vLLM container retains its existing runtime configuration.

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
../../.venv311/bin/python ../../tools/format_python.py .
../../.venv311/bin/python ../../tools/format_python.py --check .
../../.venv311/bin/python -m mypy
../../.venv311/bin/python -m pytest
```

Development dependencies are listed in `requirements-dev.txt`. The service intentionally mirrors the `backend/main/` structure (`app/core`, `app/model`, `app/route`, and `app/service`) and keeps local copies of `setup_logging.py`, `init_app_check.py`, and `verify_app_check.py`. The deployments are independent, while these files are small and change infrequently.

The formatter combines LibCST with Ruff to put every parameter and call argument on a separate line, including single arguments. From the repository root, use `make format-backend` and `make lint-backend` for both services; see [tools/README.md](../../tools/README.md).

The two services have almost identical `init_app_check.py` and `verify_app_check.py` modules and both enforce validation unconditionally. A shared package would add deployment coupling for very little code.


## Dependency lifecycle and server settings

`create_app()` reads server settings and installs the body-size middleware. `InferenceLifespan` initializes App Check and creates a shared HTTPX client and `VLLMService`. The handler receives this service with `Depends(get_vllm_service)`; there is no module-global service registry. The HTTP client closes on shutdown and on any startup failure.

`config/server.json` ships in the image (`CONFIG_DIR` can select a different directory). It is independent of main's environment configuration and is not exposed through an API. It contains:

- `vllm`: connect, read, write and pool timeouts plus an overall 120-second operation deadline. This deadline includes queue waiting and HTTP generation; expiry returns `504`.
- `generation`: maximum body size (48 MiB, allowing transport/prompt overhead above main's 40 MiB input), image count (six), decoded image size (4 MiB), concurrent operations (16), waiting requests (16), queue wait (2 seconds), and `Retry-After` (5 seconds).
- `default_max_body_bytes`: body limit for unrecognized paths.

Capacity checks are per model and per service process. Run one worker per GPU host, as the supplied Uvicorn command does. The default 16 concurrent slots apply separately to each model; DGX overrides this to four running and one waiting request per model (up to 12 running requests across its three models). Each DGX engine also sets `maxNumSeqs: 4`; its profile enables compilation and CUDA Graphs with `isEager: false`. Actual throughput depends on the model and GPU. A full queue or an expired queue wait returns `503`. Queue slots are released after completion, errors and cancellation. These limits are separate from client subscription quotas. An HTTP deadline bounds this service's wait; engine-side cancellation of a generation is controlled by vLLM.

`VLLM_REQUEST_TIMEOUT_SECONDS` no longer controls the Python service; edit `vllm` in `server.json`. Engine routes and Firebase credentials still come from environment settings.


## API errors

Inference follows the shared [API error contract](../main/ERRORS.md): `code`, `detail`, `requestId`, and optional validation `fields`. Error definitions live in its own `app/error/`; each definition owns its public description and status. The same `ApiErrorHandler` formats route, validation and body-limit failures. An outer `ApiErrorMiddleware` sanitizes unexpected errors before they reach the server logger. Public errors omit provider response bodies, prompts, images, App Check tokens and raw exception text. Cancellation continues to propagate and release capacity slots. Shared schema and error metadata are checked against main by contract tests.
