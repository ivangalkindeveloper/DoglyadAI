#!/usr/bin/env bash
# Run from the installed main stack directory. Never source credential files.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
IFS=$'\t' read -r PROFILE MAIN_TAG MAIN_DOMAIN MAIN_DATABASE_IMAGE < <(python3 - <<'PY'
from pathlib import Path
import shlex
values = {}
for line in Path('.env').read_text().splitlines():
    if not line.strip() or line.lstrip().startswith('#'):
        continue
    key, separator, value = line.partition('=')
    if not separator or key.strip() in values:
        raise SystemExit('Invalid machine environment file')
    parts = shlex.split(value, comments=False)
    if len(parts) != 1:
        raise SystemExit('Invalid machine environment value')
    values[key.strip()] = parts[0]
profile = values.get('ENV_FILE')
if profile not in ('secrets/.env.development', 'secrets/.env.production'):
    raise SystemExit('ENV_FILE must select an explicit main environment')
keys = ('TAG', 'DOMAIN', 'DATABASE_IMAGE')
if any(not values.get(key) for key in keys):
    raise SystemExit('Run main setup to pin the main and database images first')
print('\t'.join([profile, *[values[key] for key in keys]]))
PY
)
# These settings come from the machine file and selected profile.
unset TAG ENV_FILE DOMAIN ENVIRONMENT DATABASE_URL DATABASE_PASSWORD
export ENV_FILE="$PROFILE" TAG="$MAIN_TAG" DOMAIN="$MAIN_DOMAIN" DATABASE_IMAGE="$MAIN_DATABASE_IMAGE"
exec docker compose --env-file .env --env-file secrets/.env --env-file "$PROFILE" \
    -f docker-compose.yml -f docker-compose.database.yml "$@"
