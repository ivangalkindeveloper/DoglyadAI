#!/usr/bin/env bash
# Run on an ISOLATED host with a read-only backup credential. Does not start app or worker.
set -euo pipefail
if [[ $# != 3 ]]; then
    echo 'Usage: restore-drill.sh /absolute/pgbackrest-readonly.conf /absolute/yandex-disk-readonly.conf latest|"2026-10-25 12:00:00+03"' >&2
    exit 2
fi
config_path="$1"
disk_config="$2"
restore_target="$3"
restore_arguments=(--type=default)
if [[ "$restore_target" != latest ]]; then
    restore_arguments=(--type=time --target="$restore_target" --target-action=promote)
fi
[[ "$config_path" = /* && -f "$config_path" && "$disk_config" = /* && -f "$disk_config" ]] || exit 2
if [[ -n "$(docker ps -aq --filter label=com.docker.compose.service=backend_main)" ]]; then
    echo 'Restore drills require a separate host without the main application stack' >&2
    exit 2
fi
image="${DATABASE_RESTORE_IMAGE:?Set the source DATABASE_IMAGE digest}"
docker pull "$image" >/dev/null
umask 077
mkdir -p /opt/doglyad/database-backups
repository_parent=$(mktemp -d /opt/doglyad/database-backups/restore-XXXXXXXX)
repository_path="$repository_parent/repository"
python3 /opt/doglyad/database/disk_backup.py fetch --config "$disk_config" --destination "$repository_path"
docker run --rm --network none --user root --entrypoint sh -v "$repository_path:/var/lib/pgbackrest/repository" \
    "$image" -c 'chown -R postgres:postgres /var/lib/pgbackrest/repository'

volume="doglyad-database-restore-$(date +%s)-${RANDOM}"
container="${volume}-postgres"
docker volume create "$volume" >/dev/null
# Volume and container are retained on failure for diagnosis and on success for inspection.
docker run --rm --user root --entrypoint sh -v "$volume:/var/lib/postgresql/data" \
    "$image" -c 'chown postgres:postgres /var/lib/postgresql/data; chmod 700 /var/lib/postgresql/data'
docker run --rm --network none --user postgres --entrypoint pgbackrest \
    -v "$volume:/var/lib/postgresql/data" -v "$config_path:/etc/pgbackrest/pgbackrest.conf:ro" \
    -v "$repository_path:/var/lib/pgbackrest/repository:ro" \
    "$image" --stanza=doglyad_database "${restore_arguments[@]}" restore
docker run -d --name "$container" --network none \
    -v "$volume:/var/lib/postgresql/data" -v "$config_path:/etc/pgbackrest/pgbackrest.conf:ro" \
    -v "$repository_path:/var/lib/pgbackrest/repository:ro" \
    "$image" postgres -c archive_mode=off >/dev/null
for _ in {1..120}; do
    if docker exec "$container" pg_isready -U doglyad -d doglyad_database >/dev/null 2>&1; then
        if [[ "$(docker exec "$container" psql -U doglyad -d doglyad_database -Atc 'SELECT pg_is_in_recovery()')" == f ]]; then
            docker exec "$container" psql -v ON_ERROR_STOP=1 -U doglyad -d doglyad_database -c \
                'SELECT version_num FROM alembic_version; SELECT count(*) FROM billing_owners; SELECT count(*) FROM billing_subscriptions; SELECT count(*) FROM report_generations;'
            if [[ "${IS_RESTORE_DRILL_RETAINED:-true}" == false ]]; then
                docker rm -f "$container" >/dev/null
                docker volume rm "$volume" >/dev/null
                rm -rf -- "$repository_parent"
                echo "Restored to $restore_target, verified tables and removed the isolated test resources."
            else
                echo "Restored to $restore_target. Inspect $container, $volume and $repository_parent; delete them explicitly after review."
            fi
            exit 0
        fi
    fi
    sleep 1
done
echo "Restore did not finish; inspect docker logs $container" >&2
exit 1
