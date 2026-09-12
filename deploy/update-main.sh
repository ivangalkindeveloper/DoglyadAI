#!/usr/bin/env bash
#
# Deploys an already published main-backend image to an existing VM.
#
#   deploy/update-main.sh development USER@HOST IMAGE_TAG
#   deploy/update-main.sh production USER@HOST IMAGE_TAG
#
# IMAGE_TAG is normally the full commit SHA shown by the successful
# "Build backend images" GitHub Actions run.
#
# The SSH key comes from the agent or ~/.ssh/config. To point at a file:
#   DOGLYAD_SSH_KEY=~/.ssh/main_vm \
#     deploy/update-main.sh development USER@HOST IMAGE_TAG

set -euo pipefail

usage() {
    awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "${BASH_SOURCE[0]}" >&2
    exit 1
}

log() { echo "==> $*"; }

ENVIRONMENT="${1:-}"
TARGET="${2:-}"
IMAGE_TAG="${3:-}"

case "$ENVIRONMENT" in
development | production)
    ENV_FILE="secrets/.env.$ENVIRONMENT"
    ;;
*)
    usage
    ;;
esac

[ -n "$TARGET" ] && [ -n "$IMAGE_TAG" ] || usage
case "$TARGET" in
-* | *[[:space:]]*)
    echo "Invalid SSH target: expected USER@HOST or an SSH config host alias" >&2
    exit 1
    ;;
esac
case "$IMAGE_TAG" in
*[!A-Za-z0-9._-]*)
    echo "Invalid image tag: use only letters, digits, dots, underscores, and hyphens" >&2
    exit 1
    ;;
esac

REMOTE_DIR="/opt/doglyad"
BACKUP_ENV_FILE=".env.before-main-update"

SSH_COMMAND=(ssh)
if [ -n "${DOGLYAD_SSH_KEY:-}" ]; then
    SSH_COMMAND+=(-i "$DOGLYAD_SSH_KEY")
fi

rollback() {
    log "$ENVIRONMENT: restoring the previous main-backend deployment"

    # All interpolated values have fixed values or are validated above.
    # shellcheck disable=SC2029
    "${SSH_COMMAND[@]}" "$TARGET" "
        set -e
        cd '$REMOTE_DIR'
        test -f '$BACKUP_ENV_FILE'
        cp -- '$BACKUP_ENV_FILE' .env
        docker compose pull backend_main || true
        docker compose up -d --no-deps --force-recreate backend_main
        docker compose ps backend_main
    "
}

log "$ENVIRONMENT: checking $TARGET"
# All interpolated values have fixed values or are validated above.
# shellcheck disable=SC2029
DOMAIN="$("${SSH_COMMAND[@]}" "$TARGET" "
    set -e
    cd '$REMOTE_DIR'
    test -f .env
    test -f docker-compose.yml
    sed -n 's/^DOMAIN=//p' .env | tail -n 1
")"
# All interpolated values have fixed values or are validated above.
# shellcheck disable=SC2029
CURRENT_ENV_FILE="$("${SSH_COMMAND[@]}" "$TARGET" \
    "sed -n 's/^ENV_FILE=//p' '$REMOTE_DIR/.env' | tail -n 1")"

case "$DOMAIN" in
"" | *://* | */* | *[[:space:]]*)
    echo "Invalid or missing DOMAIN in $TARGET:$REMOTE_DIR/.env" >&2
    exit 1
    ;;
esac

if [ "$CURRENT_ENV_FILE" != "$ENV_FILE" ]; then
    echo "Refusing to deploy $ENVIRONMENT to $TARGET." >&2
    echo "Expected ENV_FILE=$ENV_FILE, found ENV_FILE=${CURRENT_ENV_FILE:-<missing>}." >&2
    exit 1
fi

log "$ENVIRONMENT: deploying ghcr.io/ivangalkindeveloper/doglyad-main:$IMAGE_TAG"
# All interpolated values have fixed values or are validated above.
# shellcheck disable=SC2029
if ! "${SSH_COMMAND[@]}" "$TARGET" "
    set -e
    cd '$REMOTE_DIR'

    cp -- .env '$BACKUP_ENV_FILE'

    if grep -q '^TAG=' .env; then
        sed -i 's|^TAG=.*|TAG=$IMAGE_TAG|' .env
    else
        printf '%s\n' 'TAG=$IMAGE_TAG' >> .env
    fi

    if grep -q '^ENV_FILE=' .env; then
        sed -i 's|^ENV_FILE=.*|ENV_FILE=$ENV_FILE|' .env
    else
        printf '%s\n' 'ENV_FILE=$ENV_FILE' >> .env
    fi

    docker compose config --quiet
    docker compose pull backend_main
    docker compose up -d --no-deps --force-recreate backend_main
    docker compose ps backend_main
"; then
    echo "Deployment command failed; attempting rollback." >&2
    rollback || echo "Automatic rollback failed; restore $REMOTE_DIR/$BACKUP_ENV_FILE manually." >&2
    exit 1
fi

log "$ENVIRONMENT: checking https://$DOMAIN"
APPLICATION_STATUS="$(
    curl --silent --show-error \
        --max-time 20 \
        --retry 10 \
        --retry-delay 2 \
        --output /dev/null \
        --write-out '%{http_code}' \
        "https://$DOMAIN/v1/application_config" || true
)"
PROTECTED_STATUS="$(
    curl --silent --show-error \
        --max-time 20 \
        --retry 10 \
        --retry-delay 2 \
        --output /dev/null \
        --write-out '%{http_code}' \
        --request POST \
        --header 'Content-Type: application/json' \
        --data '{}' \
        "https://$DOMAIN/v1/ultrasound/generate_report" || true
)"

echo "    GET  /v1/application_config without App Check token: $APPLICATION_STATUS"
echo "    POST /v1 without App Check token: $PROTECTED_STATUS"

if [ "$APPLICATION_STATUS" != 401 ] || [ "$PROTECTED_STATUS" != 401 ]; then
    echo "Health check failed; attempting rollback." >&2
    rollback || echo "Automatic rollback failed; restore $REMOTE_DIR/$BACKUP_ENV_FILE manually." >&2
    exit 1
fi

log "$ENVIRONMENT: main backend updated successfully"
echo "    Image tag: $IMAGE_TAG"
echo "    Previous environment file: $TARGET:$REMOTE_DIR/$BACKUP_ENV_FILE"
