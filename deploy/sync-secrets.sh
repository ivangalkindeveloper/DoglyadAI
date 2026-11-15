#!/usr/bin/env bash
#
# Ships a service's secrets to its VM and applies them.
#
# Secrets are in neither git nor the image: they live on this machine and reach a
# VM only through this script.
#
#   deploy/sync-secrets.sh main USER@HOST
#   deploy/sync-secrets.sh inference USER@HOST [DIRECTORY]
#
# No host defaults on purpose: sending secrets to a guessed machine is not a
# mistake worth making convenient, and this file carries no addresses of its own.
#
# The ssh key comes from the agent or ~/.ssh/config. To point at a file:
#   DOGLYAD_SSH_KEY=~/.ssh/<key> deploy/sync-secrets.sh main USER@HOST

set -euo pipefail

usage() {
    # Prints the header block above, so the two cannot drift apart.
    awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "${BASH_SOURCE[0]}" >&2
    exit 1
}

ROLE="${1:-}"
TARGET="${2:-}"
[ -n "$ROLE" ] && [ -n "$TARGET" ] || usage
case "$TARGET" in
-* | *[[:space:]]*)
    echo "Invalid SSH target: expected USER@HOST or an SSH config host alias" >&2
    exit 1
    ;;
esac

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REMOTE_DIR="${3:-/opt/doglyad}"
if [[ ! "$REMOTE_DIR" =~ ^/opt/doglyad(/[A-Za-z0-9_-]+)*$ ]]; then
    echo "Invalid deployment directory: expected /opt/doglyad or a child directory" >&2
    exit 1
fi
if [ "$ROLE" != inference ] && [ "$REMOTE_DIR" != /opt/doglyad ]; then
    echo "Only inference supports a custom deployment directory" >&2
    exit 1
fi

# Everything that differs between the two deployments. The service names are
# symmetrical on purpose, so only the checks really diverge.
case "$ROLE" in
main)
    # The one container to recreate. Caddy holds the certificates and has no
    # reason to be disturbed.
    SERVICE="backend_main"
    # Reachable over HTTPS, so the result can be checked end to end.
    HAS_PUBLIC_ENDPOINT=yes
    ;;
inference)
    # Deliberately not `vllm`: recreating it reloads the model, which costs
    # minutes even with the weights already on disk.
    SERVICE="backend_inference"
    # No Caddy, no domain, port reachable only over the private network — there
    # is nothing to check from here.
    HAS_PUBLIC_ENDPOINT=no
    ;;
*)
    echo "Unknown role: $ROLE (expected main or inference)" >&2
    echo >&2
    usage
    ;;
esac

LOCAL_SECRETS="$REPO_ROOT/backend/$ROLE/secrets"
if [ ! -d "$LOCAL_SECRETS" ]; then
    echo "No secrets directory at $LOCAL_SECRETS" >&2
    exit 1
fi

SSH_COMMAND=(ssh)
if [ -n "${DOGLYAD_SSH_KEY:-}" ]; then
    SSH_COMMAND+=(-i "$DOGLYAD_SSH_KEY")
fi

if [ "$ROLE" = main ]; then
    echo "==> installing the public main deployment files"
    "${SSH_COMMAND[@]}" "$TARGET" "test ! -d '$REMOTE_DIR/.infrastructure-update-lock'" || { echo 'Inspect the existing deployment lock before synchronizing main secrets' >&2; exit 1; }
    python3 "$REPO_ROOT/deploy/package_main.py" |
        "${SSH_COMMAND[@]}" "$TARGET" "set -e; umask 077; mkdir -p '$REMOTE_DIR'; tar --no-same-owner --no-same-permissions -C '$REMOTE_DIR' -xzf -"
    SELECTED_PROFILE="$("${SSH_COMMAND[@]}" "$TARGET" "cd '$REMOTE_DIR' && python3 -c 'from pathlib import Path; from shlex import split; print(next(split(line.partition(\"=\")[2])[0] for line in Path(\".env\").read_text().splitlines() if line.startswith(\"ENV_FILE=\")))'")"
    case "$SELECTED_PROFILE" in
    secrets/.env.development) MAIN_ENVIRONMENT=development ;;
    secrets/.env.production) MAIN_ENVIRONMENT=production ;;
    *) echo "Select the main VM environment before synchronizing secrets" >&2; exit 1 ;;
    esac
fi

echo "==> $ROLE: $LOCAL_SECRETS  ->  $TARGET:$REMOTE_DIR/secrets"
for secret_file in "$LOCAL_SECRETS"/.[!.]* "$LOCAL_SECRETS"/*; do
    [[ -e "$secret_file" ]] && printf '      %s\n' "${secret_file##*/}"
done

# tar over ssh rather than `scp -r`: scp switched to the SFTP protocol in OpenSSH 9
# and now nests the directory when the target already exists, so repeat runs would
# quietly produce /opt/doglyad/secrets/secrets. tar also carries dotfiles, which is
# most of what is being copied here.
package_secrets() {
    if [ "$ROLE" = main ]; then
        python3 "$REPO_ROOT/deploy/package_main_secrets.py" "$LOCAL_SECRETS" "$MAIN_ENVIRONMENT"
    else
        tar -C "$(dirname "$LOCAL_SECRETS")" --exclude=secrets/.env.running -czf - "$(basename "$LOCAL_SECRETS")"
    fi
}
package_secrets |
    "${SSH_COMMAND[@]}" "$TARGET" "
        set -e
        umask 077
        mkdir -p '$REMOTE_DIR/secrets'
        chmod 700 '$REMOTE_DIR/secrets'
        if [ '$ROLE' = main ]; then mkdir -p '$REMOTE_DIR/backup-source'; chmod 700 '$REMOTE_DIR/backup-source'; fi
        tar --no-same-permissions -C '$REMOTE_DIR' -xzf -
        chmod -R go-rwx '$REMOTE_DIR/secrets'
    "

echo "==> applying on the VM"
COMPOSE="docker compose"
if [ "$ROLE" = main ]; then
    COMPOSE="bash main-compose.sh"
    "${SSH_COMMAND[@]}" "$TARGET" "cd '$REMOTE_DIR' && python3 configure_main.py --check-config"
fi
# The application runs as UID/GID 10001. A short-lived root helper adjusts the
# mounted directories; the backend itself never starts with root privileges.
if [ "$ROLE" = inference ]; then
"${SSH_COMMAND[@]}" "$TARGET" "
    set -e
    cd '$REMOTE_DIR'
    mkdir -p logs
    $COMPOSE run --rm --no-deps --user 0:0 \\
        --volume '$REMOTE_DIR/secrets:/storage/secrets:rw' \\
        --volume '$REMOTE_DIR/logs:/storage/logs:rw' \\
        --entrypoint python '$SERVICE' -
" < "$REPO_ROOT/deploy/prepare_backend_storage.py"
fi

if [ "$ROLE" = main ]; then
    "${SSH_COMMAND[@]}" "$TARGET" "cd '$REMOTE_DIR' && if [ \"\$(id -u)\" -eq 0 ]; then python3 configure_main.py; else sudo -n python3 configure_main.py; fi"
else
"${SSH_COMMAND[@]}" "$TARGET" "
    set -e
    cd '$REMOTE_DIR'

    # Brings up whatever is not running — this is also the first start on a fresh
    # machine.
    docker compose up -d

    # env_file is read when a container is created, not on restart, so new secrets
    # need a recreate.
    docker compose up -d --force-recreate '$SERVICE'

    docker compose ps
"
fi

if [ "$HAS_PUBLIC_ENDPOINT" = yes ]; then
    echo "==> checking"
    HOST="$("${SSH_COMMAND[@]}" "$TARGET" "cd '$REMOTE_DIR' && python3 -c 'from pathlib import Path; from shlex import split; print(next(split(line.partition(\"=\")[2])[0] for line in Path(\".env\").read_text().splitlines() if line.startswith(\"DOMAIN=\")))'")"
    for _ in {1..12}; do
        CONFIG_STATUS="$(curl --silent --output /dev/null --write-out '%{http_code}' --connect-timeout 5 --max-time 10 "https://$HOST/v1/application_config" || true)"
        REPORT_STATUS="$(curl --silent --output /dev/null --write-out '%{http_code}' --connect-timeout 5 --max-time 10 -X POST "https://$HOST/v1/ultrasound/report_generations" -d '{}' || true)"
        if [[ "$CONFIG_STATUS" == 401 && "$REPORT_STATUS" == 401 ]]; then
            break
        fi
        sleep 2
    done
    printf '      Protected configuration/report routes -> %s/%s\n' "$CONFIG_STATUS" "$REPORT_STATUS"
    [[ "$CONFIG_STATUS" == 401 && "$REPORT_STATUS" == 401 ]] || { echo 'Main HTTPS verification failed' >&2; exit 1; }
    echo "      (401 responses mean the chain is healthy and App Check is enforced)"
else
    echo "==> $ROLE has no public endpoint; check the logs:"
    echo "      ssh $TARGET 'cd $REMOTE_DIR && docker compose logs --tail=40'"
fi
