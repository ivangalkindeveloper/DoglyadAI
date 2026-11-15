#!/usr/bin/env bash
set -euo pipefail
cd /opt/doglyad
exec 9>database-backups/operation.lock
flock 9
umask 077
if [[ "${1:-}" == --check-archive ]]; then
    bash main-compose.sh exec -T --user postgres doglyad_database \
        pgbackrest --stanza=doglyad_database check
    bash main-compose.sh exec -T --user postgres doglyad_database \
        pgbackrest --stanza=doglyad_database --output=json info | python3 database/disk_backup.py sync
elif [[ $# != 0 ]]; then
    echo 'Expected no arguments or --check-archive' >&2
    exit 2
fi
bash main-compose.sh exec -T --user postgres doglyad_database \
    pgbackrest --stanza=doglyad_database --output=json info | python3 database/backup-status.py
python3 database/disk_backup.py check
if [[ -n "${DATABASE_BACKUP_STATUS_URL:-}" ]]; then
    curl --fail --silent --show-error --max-time 15 "$DATABASE_BACKUP_STATUS_URL" >/dev/null
fi
