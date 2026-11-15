#!/usr/bin/env bash
# Install this job only on an isolated restore host.
set -euo pipefail
cd /opt/doglyad
: "${DATABASE_RESTORE_CONFIG_PATH:?Set the read-only pgBackRest configuration path}"
: "${DATABASE_RESTORE_DISK_CONFIG_PATH:?Set the read-only Yandex Disk configuration path}"
: "${DATABASE_RESTORE_IMAGE:?Load the exact source PostgreSQL image on this host}"
: "${DATABASE_RESTORE_SUCCESS_URL:?Configure an independent monthly restore heartbeat}"
exec 9>/opt/doglyad/.restore-drill.lock
flock -n 9
IS_RESTORE_DRILL_RETAINED=false bash database/restore-drill.sh "$DATABASE_RESTORE_CONFIG_PATH" "$DATABASE_RESTORE_DISK_CONFIG_PATH" latest
curl --fail --silent --show-error --max-time 15 "$DATABASE_RESTORE_SUCCESS_URL" >/dev/null
