# Virtual machine deployment

`deploy/` prepares a clean Ubuntu `amd64` VM for one of two services:

- `main` — the non-GPU main backend;
- `inference` — the inference backend, local vLLM, and an NVIDIA GPU.

Bootstrap installs system dependencies but deliberately does not start the service. Machine-specific configuration and secrets are transferred separately and never placed in cloud-init or provider metadata.

## Initialize a new VM from a Mac

You need the VM's public address, SSH access, and either `root` or passwordless `sudo`:

```bash
make init-vm-inference TARGET=root@203.0.113.10
make init-vm-main TARGET=ubuntu@203.0.113.20
```

The command:

1. sends the local `deploy/bootstrap.sh` over SSH without an interactive login;
2. installs Docker, Compose, Tailscale, and the service-specific stack;
3. installs the driver, NVIDIA Container Toolkit, and CDI for inference;
4. reboots the VM and waits for it to return;
5. verifies Docker, Tailscale, and GPU access from a container when applicable;
6. starts interactive Tailscale authorization and prints the private IP address.

To use a dedicated SSH key:

```bash
DOGLYAD_SSH_KEY=~/.ssh/gpu_vm \
  make init-vm-inference TARGET=root@203.0.113.10
```

Rerunning bootstrap is safe: healthy components are detected and skipped. Each run is recorded on the VM in `/var/log/doglyad-bootstrap.log`.

## Inference machine configuration

After initialization, create `/opt/doglyad/.env` on the GPU VM. `TAG` is the SHA of a successfully built image, and `INFERENCE_BACKEND_BIND` is the address returned by `tailscale ip -4`:

```dotenv
TAG=<git sha>
SERVED_MODEL_ID=google/medgemma-4b-it
VLLM_IMAGE=vllm/vllm-openai:v0.27.1@sha256:c2f3b1b964e47809b722b5e75b61b1e7b39a50f70388cf2bf2418f16a9f31da2
VLLM_MAX_MODEL_LEN=16384
VLLM_LIMIT_MM_PER_PROMPT=6
VLLM_MAX_NUM_SEQS=16
VLLM_GPU_MEMORY_UTILIZATION=0.90
VLLM_TENSOR_PARALLEL_SIZE=1
VLLM_REQUEST_TIMEOUT_SECONDS=120
INFERENCE_BACKEND_BIND=<tailscale ip>
INFERENCE_BACKEND_PORT=8100
```

Then run the following from the repository root on the Mac:

```bash
make sync-secrets-inference TARGET=USER@GPU_HOST
```

The script transfers `backend/inference/secrets/` and starts vLLM and the inference backend. The first run downloads the image and model weights, so it takes several minutes.

## Connect the main backend to the GPU VM

First, verify the private route from the main VM. A `401` response means the network and service are reachable and App Check correctly rejected a request without a token:

```bash
curl --noproxy '*' -sS -o /dev/null -w '%{http_code}\n' \
  -X POST \
  -H 'Content-Type: application/json' \
  -d '{}' \
  http://<gpu tailscale ip>:8100/v1/generation
```

Only after that check, update the local `backend/main/secrets/inference_endpoints.json`:

```json
{
  "google/medgemma-4b-it": "http://<gpu tailscale ip>:8100"
}
```

The main backend appends the inference route. Existing mappings that still contain
the previous `/v1` endpoint are normalized at startup, so they can be migrated to
the base VM URL independently of deployment.

Apply the change to the development VM:

```bash
make sync-secrets-main-development TARGET=USER@MAIN_DEVELOPMENT_HOST
```

For production, use the environment-specific target:

```bash
make sync-secrets-main-production TARGET=USER@MAIN_PRODUCTION_HOST
```

The endpoint map is loaded when the main backend starts, so `sync-secrets.sh` recreates `backend_main`. A `401` response from both `/v1/application_config` and `/v1/ultrasound/generate_report` without a token confirms that the public stack is reachable and App Check is enforced after the update.

## Update an existing main backend

After the `Build backend images` GitHub Actions workflow has published an image, deploy its full commit SHA from the repository root:

```bash
make update-main-development \
  TARGET=USER@MAIN_DEVELOPMENT_HOST \
  TAG=$(git rev-parse HEAD)
```

Use the same script for production, changing both the command and the target:

```bash
make update-main-production \
  TARGET=USER@MAIN_PRODUCTION_HOST \
  TAG=<successfully-built-git-sha>
```

The update script:

1. reads the public domain from `/opt/doglyad/.env`;
2. refuses to continue if the VM's current environment profile does not match the requested environment;
3. saves that file as `/opt/doglyad/.env.before-main-update`;
4. sets the requested image tag and preserves the matching development or production profile;
5. pulls and recreates only `backend_main`, leaving Caddy and its certificates untouched;
6. expects `401` from `/v1/application_config` and `/v1/ultrasound/generate_report` without an App Check token;
7. restores the previous environment file and container if deployment or health verification fails.

To use a dedicated SSH key, set `DOGLYAD_SSH_KEY` for either Make command.

## Cloud-init alternative

When the provider supports user data, attach one of these files while creating the VM:

- `deploy/cloud-init/main.yaml`;
- `deploy/cloud-init/inference.yaml`.

Both call the same `bootstrap.sh`. If the provider does not support user data, use the local `make init-vm-*` command; the resulting machine configuration is the same.
