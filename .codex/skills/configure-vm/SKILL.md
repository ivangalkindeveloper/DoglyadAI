---
name: configure-vm
description: Configure and audit Doglyad main or inference Ubuntu VMs with bootstrap or cloud-init, Docker, Tailscale, machine configuration, secrets delivery, container startup, private inference routing, and health checks. Use when provisioning a new VM, validating an existing VM, deploying main-development, main-production, or inference, or diagnosing deployment and network readiness.
---

# Configure a Doglyad VM

Set up or audit a VM end to end while keeping the repository, local secrets, and live infrastructure safe. Support the `main` and `inference` roles; distinguish `development` and `production` only for `main`.

## Establish the target

1. Resolve the role: `main` or `inference`.
2. For `main`, resolve the environment: `development` or `production`, the public domain, and the exact SSH target.
3. Resolve an SSH config alias when available. Inspect it with `ssh -G <alias>`; never read or print a private key.
4. Resolve the image tag as the full SHA from a successful `Build backend images` GitHub Actions run. Do not infer success from `git rev-parse HEAD`, and do not use `latest` for a controlled deployment.
5. Ask only for values that cannot be discovered safely. Before any mutation, restate the resolved role, environment, SSH target, domain, and image SHA.

If the user asks only to check or diagnose, perform read-only checks and report the fix without applying it. If the user asks to configure or deploy, execute safe in-scope setup steps and stop only at an interactive or external gate.

## Load the current deployment contract

Read these files before acting because they are the source of truth and may have changed:

- `AGENTS.md`
- `deploy/README.md`
- `deploy/bootstrap.sh`
- `deploy/init-vm.sh`
- `deploy/sync-secrets.sh`
- `deploy/docker-compose.<role>.yml`
- `deploy/cloud-init/<role>.yaml` when cloud-init is involved
- `deploy/update-main.sh` and the matching Make target for an existing main deployment

For `main`, also inspect the selected environment's neural-model config. For `inference`, inspect `backend/inference/README.md`.

## Enforce safety boundaries

- Never print, log, commit, or paste secret values. Show only file names, JSON keys, match/mismatch results, HTTP statuses, and redacted URLs when possible.
- Never modify `backend/main/secrets/` or `backend/inference/secrets/`. If an endpoint or credential must change, tell the user the exact local file and logical field to edit, then resume after the user confirms the change.
- Never put credentials, tokens, Firebase JSON, Hugging Face tokens, or endpoint maps in cloud-init/provider metadata. Cloud-init is not secret storage.
- Never log inference request bodies, patient text, images, prompts, or generated conclusions.
- Never guess a target, environment, public domain, model ID, Tailscale address, or image tag.
- Never expose the inference port publicly. Bind it to the VM's current Tailscale IPv4 address.
- Avoid restarting healthy unrelated containers. In particular, do not recreate `vllm` merely to refresh inference-backend secrets, and do not recreate Caddy for a main-backend image update.
- Treat a production environment mismatch as a hard stop.

## Run local preflight

1. Confirm the repository and working tree without touching unrelated changes.
2. Confirm SSH non-interactively with a short connection timeout. Diagnose an alias with `ssh -G`; prefer the alias over duplicating identity flags.
3. Check that the selected local secrets directory exists and that required files are non-empty, but list names only.
4. Validate JSON syntax without printing its content.
5. For `main`, compare all model IDs marked `available` in the selected config with keys in `backend/main/secrets/inference_endpoints.json`. Report missing or extra keys; do not display endpoint values.
6. Compare the backend Firebase `project_id` with the selected iOS Firebase configuration and report only `match` or `mismatch`.
7. Confirm the chosen image exists for `linux/amd64` in GHCR. Verify both role images when the workflow SHA is meant to deploy both.
8. Validate changed deployment files proportionally: use `bash -n` for shell scripts, parse cloud-init YAML, and run `docker compose config --quiet` with safe placeholder variables when appropriate.

Required local secret files are:

- `main`: `.env`, `.env.<environment>`, `firebase_credentials.json`, `inference_endpoints.json`
- `inference`: follow `backend/inference/README.md` and the current variables model; do not assume the list from memory

## Audit the base VM

Collect and label these read-only facts over SSH:

- login user, hostname, Ubuntu release, and `amd64` architecture
- `cloud-init status --long`, including recoverable errors
- reboot requirement and current boot state
- Docker Engine and Compose versions, Docker daemon access for the login user
- active `docker` and `tailscaled` services
- Tailscale login state and current IPv4 address
- `/opt/doglyad`, its role-specific Compose file, Caddyfile for `main`, machine `.env`, secrets directory, and logs directory
- `docker compose config --quiet`, container states, health, and recent technical logs when configuration exists

When cloud-init or bootstrap failed, inspect `/var/log/cloud-init-output.log` and `/var/log/doglyad-bootstrap.log`. Report the first actionable failure. Do not dump entire logs if they may include infrastructure details.

If bootstrap has not completed and the VM is new, run the repository entry point from the local machine:

```bash
make init-vm-main TARGET=<ssh-target>
make init-vm-inference TARGET=<ssh-target>
```

Use only the command matching the resolved role. The script reboots the machine. Do not run it against an active service without explicit confirmation of the interruption.

## Join and verify Tailscale

If `tailscale ip -4` is empty, run the interactive authorization:

```bash
ssh -t <ssh-target> 'sudo tailscale up'
```

Pause for the user to complete browser authorization, then resume automatically with `tailscale status` and `tailscale ip -4`. Do not store an auth key in metadata or the repository.

For every main-to-inference route:

1. Resolve the endpoint host from the local endpoint map without printing the complete map.
2. Confirm the host is the current Tailscale address of the intended inference peer; never reuse a stale private-cloud `10.x` address by assumption.
3. Run `tailscale ping <inference-ip>` and `ip route get <inference-ip>` on the main VM. Expect the route through `tailscale0`.
4. POST an empty JSON object to `/v1/generation` with `--noproxy '*'`, a 5-second connect timeout, and a 10-second total timeout. Expect `401`; it proves reachability and App Check rejection without exposing patient data.
5. If the peer is reachable at a different address, ask the user to update the matching model entry in the protected local endpoint map, then synchronize secrets to every affected main VM.

## Configure a main VM

1. Confirm provider firewall rules permit SSH plus public TCP 80 and 443. Confirm DNS resolves the intended domain to this VM before allowing Caddy to request a certificate.
2. Write `/opt/doglyad/.env` with exactly the machine-specific non-secret values:

```dotenv
TAG=<successful full git SHA>
ENV_FILE=secrets/.env.<development-or-production>
DOMAIN=<hostname without scheme or path>
```

3. Validate that `ENV_FILE` matches the resolved environment. Refuse to continue on mismatch.
4. Verify all inference routes from this VM before starting the public backend.
5. From the repository root on the local machine, synchronize the existing local secrets and start the stack:

```bash
deploy/sync-secrets.sh main <ssh-target>
```

`sync-secrets.sh` derives its public health-check host from the target string. If the target is an SSH alias rather than the public domain, its final curl may say `unreachable` even though synchronization succeeded. Always repeat health checks against `DOMAIN` from the machine `.env`; do not mistake the alias check for service failure.

6. Verify `backend_main` and `caddy` are running. Check recent logs without request bodies.
7. Verify the public chain:

- `GET https://<domain>/v1/application_config` with no App Check token returns `401`
- `GET https://<domain>/v1/ultrasound/examination_neural_models` with no App Check token returns `401`
- `POST https://<domain>/v1/ultrasound/generate_report` with `{}` and no App Check token returns `401`

For a later image-only update, use `make update-main-development` or `make update-main-production`. Verify the successful SHA first. Do not use `sync-secrets.sh` merely to update code, and do use it when local secrets actually changed.

## Configure an inference VM

1. Confirm the host GPU with `nvidia-smi`.
2. Confirm Docker GPU access with the exact check used by the current deployment docs and confirm CDI lists `nvidia.com/gpu=all`.
3. Confirm the inference port is allowed only on the private interface/network and is not open to the public internet.
4. Write `/opt/doglyad/.env` from the current template in `deploy/README.md`. Use the successful image SHA, exact served model ID, pinned vLLM image, model limits, and the current `tailscale ip -4` value for `INFERENCE_BACKEND_BIND`. Keep Hugging Face and Firebase credentials in `backend/inference/secrets/`, never in this file.
5. From the repository root on the local machine, run:

```bash
deploy/sync-secrets.sh inference <ssh-target>
```

6. Allow the first vLLM start enough time to download weights and load the model. Monitor focused Compose status and technical logs; do not treat model loading during the configured health-check start period as a failure.
7. Verify `vllm` becomes healthy and `backend_inference` starts. Then perform the expected-`401` request from each main VM.
8. Ask the user to update the protected local `inference_endpoints.json` for the served model if necessary, and then synchronize secrets to the affected main VMs.

## Report the result

Return a compact checklist grouped as `Passed`, `Action required`, and `Not checked`. Include:

- role, environment, target, domain, and image SHA with no credentials
- cloud-init/bootstrap, reboot, Docker, Compose, Tailscale, GPU when applicable
- machine configuration and required secret-file presence
- containers and expected HTTP statuses
- main-to-inference route and whether it uses `tailscale0`
- exact next commands, clearly labeled `Local Mac` or `VM`

When the user says they are already connected over SSH, provide VM commands without wrapping every command in another `ssh`. Never claim the VM is ready while any required check is skipped or failing.
