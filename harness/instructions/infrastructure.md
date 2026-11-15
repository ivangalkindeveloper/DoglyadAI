# Doglyad infrastructure rules

### Environments

`ENVIRONMENT` (`development` or `production`) selects a directory under `backend/main/config/` and the matching Robokassa test/live mode. The application reads the same documents from this backend instead of the repository. Otherwise, pushing a new model to `master` could expose it to the app before the backend deployment knows about it, causing a physician to receive `400`. With the default `MODEL_SERVICE_TYPE=inference`, both environments use the same inference route and token validation. A development-staging check is meaningful because it exercises the same code and path; the configuration documents and Robokassa payment mode differ.

`MODEL_SERVICE_TYPE` selects the main backend's generation implementation independently of `ENVIRONMENT`: `inference` calls GPU VMs, while `mock` returns local RU/EN fixtures. VS Code's `Backend: Local Mock` profile selects `mock` with development configuration. App Check, configuration, localization, request validation, and SMTP remain real. Mock generation does not require an inference endpoint map; see [`backend/main/README.md`](../../backend/main/README.md).

### Timeouts

Timeouts are strictly nested from outside to inside, with each wrapper wider than the operation it contains:

```text
iOS client                    300  application.json -> network.timeoutIntervalForRequest
main server.json operation    130  main backend waits for the GPU VM
inference server.json         120  queue waiting and local engine request
```

An inner timeout must be shorter than its outer timeout; otherwise the caller can terminate the connection while the wrapped generation is still running.

With `MODEL_SERVICE_TYPE=inference`, every published model must have an entry in `backend/main/secrets/inference_endpoints.json` containing the URL of its GPU VM. A missing mapping is a configuration error.

### Fleet inventory

Name SSH aliases by service role, such as `doglyad-inference`,
`doglyad-development` and `doglyad-production`, rather than by hardware or device
name. When the machine changes, update its SSH connection settings and preserve
the role alias. Use that alias in the inventory and connection examples.

`deploy/secrets/infrastructure.json` is the private, Git-ignored list of deployment
targets used by the infrastructure checker/updater. It contains topology and
host/profile assignments, not application credentials. Keep passwords, tokens and
private keys out of it. The public `deploy/infrastructure.example.json` is a template
for that final path, not evidence of the live fleet. A syntactically valid inventory
can be stale: compare it with the main endpoint map and configured host profiles.
Do not replace actual SSH targets, architecture or deployment directories by guessed
values, and do not publish the private inventory merely because it has no passwords.

### Main database operations

Main initialization uses `deploy/main-compose.sh` with the main and database Compose files. `sync-secrets.sh` installs the public assets from a clean checkout matching the published image SHA and initializes Alembic and pgBackRest through `configure_main.py`. Full encrypted backups and WAL are uploaded to the private Yandex Disk folders `DoglyadAIDB/development` and `DoglyadAIDB/production`. Keep one verified remote generation per environment and delete the old one only after its replacement is verified. OAuth, backup configuration and heartbeat URLs are separate per environment; PostgreSQL private configuration lives outside application storage permissions. The database image is published and pinned by digest. Main updates stop all four application processes, take a full backup, migrate and start the new images. An applied or uncertain migration blocks automatic old-image rollback; preserve writers stopped and the recovery lock. Never automatically downgrade or restore production data. Daily full backups, five-minute archive/freshness checks and an isolated monthly recovery job are described in `deploy/database/README.md`.
