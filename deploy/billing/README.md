# Billing deployment and database recovery

These files are an **optional, not yet deployed** overlay. They do not modify the
running fleet or create a bucket. Billing integration and launch prerequisites are
in [BILLING.md](../../backend/main/BILLING.md).

This directory contains deployment and database recovery infrastructure. The
subscription service remains part of `backend/main/app/service/billing/`; the
gateway and worker are processes of the same main-backend image, sharing its
repository and database. There is no separate billing microservice or internal
billing HTTP API.

## Layout

On each main VM, billing adds a private PostgreSQL 17 container, a one-shot Alembic
migration, the payment gateway and a reconciliation worker. Main, gateway and worker
use the same image/configuration and PostgreSQL. Caddy routes only `/payments/return`
and the two provider callbacks to the gateway. `/v1` remains protected by App Check.
The database and gateway publish no host ports. Payment gateway access logging is
disabled so Apple token query strings are not written to HTTP logs.

The optional stack needs these files alongside the existing deployment:

```text
/opt/doglyad/
  docker-compose.main.yml
  docker-compose.billing.yml
  billing/                        files from deploy/billing/
  secrets/
    .env                          existing common credentials
    .env.production               existing selected environment credentials
    pgbackrest.conf               actual private configuration
    backup-monitor.env            BILLING_BACKUP_SUCCESS_URL, if used
  .env                            Compose interpolation variables
```

Set secret Compose interpolation variables `BILLING_DATABASE_PASSWORD` and
`BILLING_DATABASE_URL=postgresql+asyncpg://doglyad:URL_ENCODED_PASSWORD@billing_database/billing`
in the VM's `.env`, in addition to existing `TAG`, `ENV_FILE`, `DOMAIN`. Set the
billing provider/Apple variables in the selected environment secret file, using
ResultURL `https://DOMAIN/webhooks/robokassa` and SuccessURL/FailURL `https://DOMAIN/payments/return`. Never commit these files. Use a distinct
password, database volume, bucket/prefix and provider credentials per environment.
The current initial DB role also runs migrations; restrict DB networking to this
VM and separate migration/runtime roles before expanding operational access.

For the initial rollout, the reviewed command is:

```sh
docker compose --env-file .env -f docker-compose.main.yml -f docker-compose.billing.yml up -d --build
```

This is an operator instruction, not an action performed by this change. Existing
fleet automation must be updated to preserve/use this overlay and install the
backup units before activating billing on an existing VM. Do not silently switch
between the overlay and the old stack during routine deployments. Keep one worker
initially. Migrations must finish successfully before application containers start.

## Backup destination and initialization

Create a **private Yandex Object Storage bucket**, separate from the VM, in the
chosen Russian region. The example intentionally contains no invented bucket name.
Use a service account limited to that bucket. Enable versioning for additional
protection, and define a separate noncurrent-version lifecycle after calculating
storage cost; pgBackRest's expiration does not remove noncurrent object versions.
Do not expire active backup/WAL objects with an independent bucket lifecycle rule.

Copy `pgbackrest.conf.example` into the VM's `secrets/pgbackrest.conf` and replace
all placeholders. The PostgreSQL image contains pgBackRest. It uploads compressed,
encrypted backups and WAL via TLS to `storage.yandexcloud.net`. Keep the encryption
key and a recovery credential in a password manager outside this VM: backups are
unusable if the only key disappears with the VM. Make the config readable by the
container's `postgres` OS user and inaccessible to unrelated users (verify the UID
for the built image; do not make the secret world-readable).

After PostgreSQL starts, initialize and verify the archive before accepting payments:

```sh
docker compose --env-file .env -f docker-compose.main.yml -f docker-compose.billing.yml exec -T --user postgres billing_database pgbackrest --stanza=billing stanza-create
docker compose --env-file .env -f docker-compose.main.yml -f docker-compose.billing.yml exec -T --user postgres billing_database pgbackrest --stanza=billing check
bash billing/backup.sh
```

`archive_mode=on`, `archive_timeout=60s` and `archive_command` continuously push WAL.
The archive confirms success only after the remote write succeeds; failures retry
and accumulate locally, so monitor disk space and archive failures. `archive_timeout`
is not a guaranteed RPO when networking or archiving fails.

Install the supplied service/timer on the **main VM** and enable the timer. The
service runs `check`, then `backup --type=full` at 03:00 Europe/Moscow daily. A missed
schedule runs after reboot (`Persistent=true`). Retention is time-based, at least
30 days, preserving the older full backup and WAL needed to cover that window.
The whole PostgreSQL database is backed up; patient reports/images are not stored
in this database by billing.

Configure independent missed-heartbeat alerts using `BILLING_BACKUP_SUCCESS_URL`
in `secrets/backup-monitor.env` (the script pings only after successful checks and
backup). Also monitor pgBackRest backup age, PostgreSQL `pg_stat_archiver`, WAL/disk
usage and worker failures from outside the VM. A daily success heartbeat alone does
not detect a WAL outage promptly. Aim to alert on active-traffic WAL lag above five
minutes and full-backup age above 26 hours. Monitoring credentials and subscriptions
must be configured externally; they are not fabricated by this repository change.

## Restore and monthly drill

Use a separate **isolated host**, a read-only bucket credential and the backed-up
encryption key. Build/load the exact PostgreSQL/pgBackRest image used by the source.
Do not attach production application/worker containers to a restored database.
They could replay subscriptions or send messages. Keep outbound HTTPS access to
Object Storage for WAL recovery, and expose no PostgreSQL host port.

```sh
bash billing/restore-drill.sh /absolute/path/to/readonly-pgbackrest.conf '2026-10-25 12:00:00+03'
```

The script creates a new dedicated volume, restores to the requested timestamp,
starts PostgreSQL with archiving off, waits for recovery to finish and checks the
migration/ledger tables. It retains its named container and volume for inspection;
remove those exact temporary resources explicitly after reviewing the result.
A failed restore exits nonzero and leaves diagnostics. It never replaces a live DB.

Schedule this command monthly on the isolated restore host with a recent target
and independent failure alerts. A scheduler is intentionally not installed on the
main VM, because an automatic production-host restore is not an isolated drill.
Record duration, last recoverable transaction time, selected backup and row counts.
The objectives are **RPO ≤5 minutes and RTO ≤2 hours**; neither is claimed measured.

For an actual incident: stop all application/gateway/worker writes, restore into a
new volume, validate access/ledger consistency, reconcile provider transactions
near the failure window, and only then redirect the services and resume the worker.
Never use `downgrade base`, delete a volume or overwrite the live database as a
routine recovery step. Secure recovered copies and delete them after the drill.

Reference: [pgBackRest configuration](https://pgbackrest.org/configuration.html),
[pgBackRest user guide](https://pgbackrest.org/user-guide.html).
