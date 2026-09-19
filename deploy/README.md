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

## Update all backend services

The local, Git-ignored `deploy/secrets/infrastructure.json` is the single fleet inventory. Do not commit or publish it. It lists both main environments and every inference VM with its exact model ID. Keep its targets current; SSH aliases must exist on the machine running deployment, and direct SSH targets must support non-interactive authentication. Private keys and passwords belong outside this file. Check the inventory with `make check-infrastructure` before rollout.

```bash
make check-infrastructure
make update-infrastructure
```

These commands invoke `bash deploy/update-infrastructure.sh`. Requires local Python 3.10+, authenticated GitHub CLI with workflow-dispatch access, Docker CLI with GHCR access, and non-interactive SSH. VMs need Python 3, Docker Compose, curl, and write access to `/opt/doglyad`; inference also needs Tailscale. `--check` performs read-only readiness and private-route checks without starting a build.

Commit and push the intended code first. The script does not publish local changes. The updated `build.yml` with its `deployment_id` input must exist on GitHub before the first launch. It correlates a fresh build using a unique run title, requires both image jobs to succeed, verifies amd64 manifests, and deploys the resulting digests. A branch change before dispatch aborts deployment. Build wait defaults to one hour (`--build-timeout` in seconds).

```bash
make update-infrastructure INFRASTRUCTURE_INVENTORY=/path/to/infrastructure.json INFRASTRUCTURE_REF=master
```

All targets are preflighted, locked and snapshotted; all images are staged before container replacement. The order is inference backends, development main, production main. Only backend containers are recreated. Caddy, vLLM, weights, secrets, OS packages, and deployed Compose files are preserved. The new machine `TAG` contains `<commit-sha>@sha256:<digest>`, supported by the existing Compose image references.

The single update path is `make update-infrastructure` → `deploy/update-infrastructure.sh` → `deploy/update_infrastructure.py` → `deploy/update_remote.py` over SSH. The local Python module coordinates Actions and rollout; the remote helper owns container changes and rollback for both roles. Use the `update-infrastructure` skill for updates, and `configure-vm` for provisioning/readiness. `sync-secrets.sh` is only for delivering changed secrets or initial startup.

Review API compatibility and required migrations before launch. Shared inference affects production immediately; container recreation can interrupt requests. This is not a zero-downtime or atomic fleet deployment. The script validates new model catalogs against existing mappings and rejects mapped models omitted from the inventory, but it cannot discover unlisted unused VMs. Checks verify actual image IDs, stable containers, unchanged companions, private routes, and expected HTTP 401 responses. They do not prove successful report generation.

### Recovery

On rollout failure, further updates stop and all attempted targets are rolled back in reverse order, including the target whose SSH response was lost. Rollback restores the machine `.env` and recreates the backend from its saved local image ID. Snapshots remain in `/opt/doglyad/.deploy-<release-id>/`; keep them private. Images/volumes are not pruned.

After a rollout failure, persistent locks are retained even if rollback reports success. Inspect every affected VM and verify images against `state.json`, configuration, containers, and routes. Ensure no remote operation is still running. The lock directory is `.infrastructure-update-lock`, with the release ID in `owner`; `.infrastructure-operation-lock` is a separate advisory-lock file and must not be deleted.

The remote helper accepts recovery actions using the original release ID and inventory target, for example (replace placeholders):

```bash
ssh -o BatchMode=yes GPU_SSH_ALIAS 'python3 - '\''{"action":"rollback","release":"RELEASE_ID","target":{"role":"inference","ssh":"GPU_SSH_ALIAS","model":"MODEL_ID"}}'\''' < deploy/update_remote.py
```

After checking recovery, use the same command with `"action":"unlock"` on each prepared target. For main targets use the inventory's development/production role. Ownership and operation locks are checked. Never clear another rollout's lock. A killed process or unreachable VM may require manual recovery; the script cannot guarantee rollback over a broken SSH connection. A restored mutable old tag may have moved: the saved image ID and rollback override in the snapshot identify the actual recovered image.

The entry point currently updates the full inventory. Partial rollouts, explicit historical-SHA releases, incompatible migrations, and platform upgrades require a separate plan; there are no flags for these operations.

Local tests, without GitHub/VM access:

```bash
python3 -m unittest discover -s deploy/test -p 'test_update*.py'
bash -n deploy/update-infrastructure.sh
```

## Cloud-init alternative

When the provider supports user data, attach one of these files while creating the VM:

- `deploy/cloud-init/main.yaml`;
- `deploy/cloud-init/inference.yaml`.

Both call the same `bootstrap.sh`. If the provider does not support user data, use the local `make init-vm-*` command; the resulting machine configuration is the same.
