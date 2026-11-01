#!/usr/bin/env bash
# Run on an ISOLATED host with a read-only backup credential. Does not start app or worker.
set -euo pipefail
if [[ $# != 2 ]]; then
    echo 'Usage: restore-drill.sh /absolute/pgbackrest-readonly.conf "2026-10-25 12:00:00+03"' >&2
    exit 2
fi
config_path="$1"
restore_target="$2"
[[ "$config_path" = /* && -f "$config_path" ]] || exit 2
volume="doglyad-billing-restore-$(date +%s)"
container="${volume}-postgres"
docker volume create "$volume" >/dev/null
# Volume and container are retained on failure for diagnosis and on success for inspection.
docker run --rm --user root --entrypoint sh -v "$volume:/var/lib/postgresql/data" \
    doglyad-billing-postgres:17 -c 'chown postgres:postgres /var/lib/postgresql/data; chmod 700 /var/lib/postgresql/data'
docker run --rm --user postgres --entrypoint pgbackrest \
    -v "$volume:/var/lib/postgresql/data" -v "$config_path:/etc/pgbackrest/pgbackrest.conf:ro" \
    doglyad-billing-postgres:17 --stanza=billing --type=time --target="$restore_target" --target-action=promote restore
docker run -d --name "$container" --network bridge \
    -v "$volume:/var/lib/postgresql/data" -v "$config_path:/etc/pgbackrest/pgbackrest.conf:ro" \
    doglyad-billing-postgres:17 postgres -c archive_mode=off >/dev/null
for attempt in {1..120}; do
    if docker exec "$container" pg_isready -U doglyad -d billing >/dev/null 2>&1; then
        if [[ "$(docker exec "$container" psql -U doglyad -d billing -Atc 'SELECT pg_is_in_recovery()')" == f ]]; then
            docker exec "$container" psql -v ON_ERROR_STOP=1 -U doglyad -d billing -c \
                'SELECT version_num FROM alembic_version; SELECT count(*) FROM billing_owners; SELECT count(*) FROM billing_subscriptions;'
            echo "Restored to $restore_target. Inspect $container and $volume; delete them explicitly after review."
            exit 0
        fi
    fi
    sleep 1
done
echo "Restore did not finish; inspect docker logs $container" >&2
exit 1
