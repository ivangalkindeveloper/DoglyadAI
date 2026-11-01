#!/usr/bin/env bash
set -euo pipefail
cd /opt/doglyad
compose=(docker compose --env-file .env -f docker-compose.main.yml -f docker-compose.billing.yml)
"${compose[@]}" exec -T --user postgres billing_database pgbackrest --stanza=billing check
"${compose[@]}" exec -T --user postgres billing_database pgbackrest --stanza=billing --type=full backup
# Monitoring is independent from this VM; its missed-run alert must be configured.
if [[ -n "${BILLING_BACKUP_SUCCESS_URL:-}" ]]; then
    curl --fail --silent --show-error --max-time 15 "$BILLING_BACKUP_SUCCESS_URL" >/dev/null
fi
