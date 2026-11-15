# Main database, migrations and Yandex Disk backups

The main VM runs PostgreSQL 17, the API, the report worker, the payment gateway
and the subscription worker. `main-compose.sh` combines both Compose files and
loads the machine file, common credentials and selected environment profile.
`docker-compose.main.yml` owns the four application processes and Caddy;
`docker-compose.database.yml` owns PostgreSQL and the shared `database_migrate` job.
PostgreSQL publishes no host port. Application updates preserve its pinned image.

## Backup storage and policy

The backup destination is the owner's private Yandex Disk folder `DoglyadAIDB`:

```text
DoglyadAIDB/
  development/
    doglyad_database-development-2026-11-15T00-00-00.123456Z-<unique ID>/
      doglyad_database-development-2026-11-15T00-00-00.123456Z-<unique ID>.tar.gz.part00000
      manifest.json
      checkpoint-<timestamp>-<unique ID>.json
      archive/...
  production/
    doglyad_database-production-2026-11-15T00-00-00.123456Z-<unique ID>/
      ...
```

The date/time in each generation and archive part is **UTC** (`Z`), with microseconds.
It identifies packaging time; the manifest also records the actual full-backup
completion time and pgBackRest label. The unique ID prevents collisions.

- Daily at 03:00 Europe/Moscow (up to five minutes randomized delay), pgBackRest
  makes a full physical backup into the private local repository.
- PostgreSQL continuously archives WAL locally (`archive_timeout=60s`). Every five
  minutes, the status job forces/verifies archiving and uploads missing WAL to Disk.
- pgBackRest compresses data with zstd and encrypts database files and WAL with
  AES-256-CBC **before upload**. The outer tar contains encrypted repository files;
  filenames and backup manifests remain visible to the storage account.
- Archive parts are at most 512 MiB, to avoid relying on a paid plan's larger
  per-file limit. All parts and the accompanying WAL are needed for recovery.
- Uploads use TLS. Each remote file must match its local SHA-256 and size.
  A completed WAL checkpoint marks a usable generation. Interrupted generations
  are ignored by recovery. OAuth never accompanies signed transfer URLs.
- After the new generation and WAL checkpoint are verified, the previous managed
  generation is permanently deleted, without moving it to Trash. Other user files
  and the other environment are not deleted. Two copies temporarily coexist during
  replacement; a cleanup failure retains extra copies and reports failure.
- Only one latest completed generation per environment is retained. WAL grows
  alongside it until the next successful daily replacement. This is one recovery
  set, not one standalone file. Failed uploads leave the old remote copy intact.
- Full backups also run before migrations with all four application writers stopped.
  Full-backup and WAL publication jobs share a host lock.

The host needs space for the local repository, a temporary full archive and its
current part, in addition to PostgreSQL data/WAL. Monitor both VM disk space and
Disk quota/upload limits. The free 1 TB account capacity does not imply unlimited
monthly uploads. One main VM must own each environment folder; do not run competing
writers for the same environment.

The intended remote loss window is approximately 5–10 minutes while networking,
archiving and upload jobs work. This is an objective, not a measured guarantee.
A transfer outage can exceed it. An isolated recovery should establish actual RPO/RTO.

## Values the owner must provide

For each environment, create these **private local files** from the public templates:

| Local file under `backend/main/secrets/` | Template | Required values |
|---|---|---|
| `pgbackrest.production.conf` | `deploy/database/pgbackrest.conf.example` | Separate random backup encryption password |
| `pgbackrest.development.conf` | Same | Another independent encryption password |
| `yandex-disk.production.conf` | `deploy/database/yandex-disk.conf.example` | Production environment/folder and OAuth token |
| `yandex-disk.development.conf` | Same | Development environment and `/DoglyadAIDB/development`; token |
| `backup-monitor.production.env` | `deploy/database/backup-monitor.example` | Daily and five-minute external heartbeat URLs |
| `backup-monitor.development.env` | Same | Independent development heartbeat URLs |

A single Disk account/token can access both environment folders. Separate OAuth
apps/tokens make revocation independent, but full-Disk scopes do not restrict a
token to just one folder. Keep these credentials out of application `.env` files.

To obtain the token, create a dedicated OAuth application at
[OAuth Yandex ID](https://oauth.yandex.ru/), select
`cloud_api:disk.read` and `cloud_api:disk.write`, and follow the
[official Disk authorization instructions](https://yandex.ru/dev/disk-api/doc/ru/concepts/quickstart).
The `app_folder` scope alone cannot access the existing `DoglyadAIDB` folder.
Store the token directly in the private configuration file; never paste it in chat.
Disk folders are private; these scripts never publish them or create public links.

Generate each backup encryption password independently:

```sh
python3 -c 'import secrets; print(secrets.token_urlsafe(48))'
```

Keep these passwords, `REPORT_GENERATION_ENCRYPTION_KEY`, application credentials,
OAuth recovery access and the pinned `DATABASE_IMAGE` **outside the VM**. Backups
contain the database, including encrypted report jobs; they do not contain secrets
or encryption keys. Do not change an existing repository key through normal setup.

Configure external alerts: daily backup absent for 26 hours; five-minute backup/WAL
check absent for ten minutes. The alert receiver must be outside the main VM.
Backup-only configuration is delivered outside the application secrets mount.
The scripts do not create monitoring accounts or any paid resources.

## Initial setup

Publish a successful `build.yml` run first. It publishes main, inference and the
PostgreSQL/pgBackRest image after checks, including isolated backup/WAL recovery.
Use a clean checkout matching the published SHA when delivering public assets.
The machine `/opt/doglyad/.env` starts with:

```dotenv
TAG=<successful full commit SHA>
ENV_FILE=secrets/.env.production
DOMAIN=<hostname without scheme or path>
```

`DATABASE_URL` and `DATABASE_PASSWORD` stay in the selected application profile.
From the Mac, run `make sync-secrets-main-production TARGET=<SSH target>` (or the
development target). Setup requires root or noninteractive sudo. It:

1. Resolves/pins the published database image by digest and prepares private storage.
2. Starts PostgreSQL and initializes/checks its local encrypted repository.
3. Stops all four writers, uploads a full backup and WAL to Disk, then runs Alembic.
4. Starts all four processes and Caddy with the provider webhook routes.
5. Enables daily backup and five-minute WAL/status timers, then verifies remote health.

A backup/migration failure leaves writers stopped for inspection. Setup never erases
a live volume or changes an existing PostgreSQL image automatically.
`python3 configure_main.py --check-config` validates configuration without starting
containers or calling Disk. Real upload/recovery is still required before production.

```text
/opt/doglyad/
  .env                         TAG, ENV_FILE, DOMAIN, DATABASE_IMAGE
  main-compose.sh
  docker-compose.yml
  docker-compose.database.yml
  configure_main.py            complete main-stack initialization
  Caddyfile                    API and payment webhook routing
  database/                    database scripts/templates/systemd units
  secrets/                     common + selected application files
  backup-source/               selected backup-only source files; never app-mounted
  database-secrets/             root-only directory
    pgbackrest.conf             root:PostgreSQL group, mode 0640
    yandex-disk.conf             root only, mode 0600; never mounted into PostgreSQL
    backup-monitor.env          root only, mode 0600
  database-backups/              root-only parent
    repository/                PostgreSQL user/group, mode 0700; encrypted files
    current.json               last published full generation, root only
  logs/
```

Inspect technical status without printing credentials:

```sh
systemctl list-timers 'doglyad-database-*'
systemctl status doglyad-database-backup.service doglyad-database-status.service
bash database/backup-status.sh
bash main-compose.sh exec -T --user postgres doglyad_database pgbackrest --stanza=doglyad_database info
```

Normal `backup-status.sh` is a read-only local/remote preflight. Its scheduled
`--check-archive` mode also archives and uploads WAL. Both require a remote full
backup no older than 26 hours and a checkpoint no older than ten minutes. No success
heartbeat is sent after a failed upload, checksum check, stale backup or cleanup.

## Migrations and updates

`make update-infrastructure` checks PostgreSQL, all four main processes, timers and
local/remote backup freshness. Each main update stops API, report worker, gateway
and subscription worker; creates and uploads a verified full backup; runs the new
image's `database_migrate` (`alembic upgrade head`); records the resulting revision;
and starts/verifies the four new application images. Caddy/PostgreSQL are preserved.

Future schema changes add migration files under `backend/main/migrations/versions/`.
Do not rewrite already applied production migrations. Rollback restores old images
only when migration outcome is known and the database revision did not change.
An applied/uncertain migration keeps writers stopped, retains the recovery lock and
`.deploy-<release>/database-maintenance.json`, and requires an explicit repair plan.
Never automatically downgrade or replace live data with a backup. Reconcile payments
near an incident before restarting subscription reconciliation after recovery.

## Recovery and monthly drill

Use a separate amd64 Docker host **without any main application stack**. Copy the
public `database/` scripts and provide these root-protected files:

- `database-secrets/pgbackrest-readonly.conf`: same POSIX repository path and source
  encryption password as above. The source profile's full contents are not required.
- `database-secrets/yandex-disk-readonly.conf`: same environment/folder and a separate
  OAuth token with only `cloud_api:disk.read`.
- `database-secrets/restore-monitor.env`: from `database/restore-monitor.example`,
  with the source image digest and an independent monthly heartbeat URL.

Give the PostgreSQL user group read access to its pgBackRest config (0640). OAuth
and monitor files stay root-only (0600). From `/opt/doglyad` on this isolated host:

```sh
DATABASE_RESTORE_IMAGE=<source DATABASE_IMAGE digest> bash database/restore-drill.sh /opt/doglyad/database-secrets/pgbackrest-readonly.conf /opt/doglyad/database-secrets/yandex-disk-readonly.conf latest
```

The script selects the newest completed generation, downloads/verifies every archive
part and checkpoint WAL, safely reconstructs the encrypted local repository, then
restores to a unique volume with the source PostgreSQL image. It waits for recovery
and reads schema/ledger/report tables. It publishes no ports and starts no workers.
Manual successes and failures retain their isolated resources for inspection. A UTC
or offset timestamp can replace `latest` within the retained full/WAL recovery window.

After a successful first real Disk recovery, install the two restore systemd units
on the isolated host. Run `sudo systemctl daemon-reload` and
`sudo systemctl enable --now doglyad-database-restore.timer`. It runs on the first day
of each month at 04:00 Europe/Moscow, with up to 30 minutes randomized delay. Automatic
success removes only its temporary repository/container/volume, then pings the monthly
check. Failures retain diagnostics. Main setup never enables this monthly timer.

Reference: [Disk file upload](https://yandex.com/dev/disk-api/doc/en/reference/upload),
[pgBackRest configuration](https://pgbackrest.org/configuration.html).
