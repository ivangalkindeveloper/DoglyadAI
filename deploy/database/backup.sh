#!/usr/bin/env bash
set -euo pipefail
cd /opt/doglyad
exec 9>database-backups/operation.lock
flock 9
umask 077
compose=(bash main-compose.sh)
"${compose[@]}" exec -T --user postgres doglyad_database pgbackrest --stanza=doglyad_database check
"${compose[@]}" exec -T --user postgres doglyad_database pgbackrest --stanza=doglyad_database --type=full backup
"${compose[@]}" exec -T --user postgres doglyad_database pgbackrest --stanza=doglyad_database --output=json info | python3 database/disk_backup.py publish
# Monitoring is independent from this VM; its missed-run alert must be configured.
if [[ -n "${DATABASE_BACKUP_SUCCESS_URL:-}" ]]; then
    curl --fail --silent --show-error --max-time 15 "$DATABASE_BACKUP_SUCCESS_URL" >/dev/null
fi
