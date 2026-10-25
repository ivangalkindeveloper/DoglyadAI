#!/usr/bin/env bash
# Local/source-based startup; fleet updates use update-infrastructure instead.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROLE="${1:?Expected main or inference}"
COMPOSE=(docker compose)
case "$ROLE" in
main) ;;
inference) COMPOSE+=(--env-file "$REPO_ROOT/backend/inference/secrets/.env") ;;
*) echo "Expected main or inference" >&2; exit 1 ;;
esac
COMPOSE+=(-f "$REPO_ROOT/backend/$ROLE/docker-compose.yml")
SERVICE="backend_$ROLE"

mkdir -p "$REPO_ROOT/backend/$ROLE/logs"
"${COMPOSE[@]}" build "$SERVICE"
"${COMPOSE[@]}" run --rm --no-deps --user 0:0 \
    --volume "$REPO_ROOT/backend/$ROLE/secrets:/storage/secrets:rw" \
    --volume "$REPO_ROOT/backend/$ROLE/logs:/storage/logs:rw" \
    --entrypoint python "$SERVICE" - < "$REPO_ROOT/deploy/prepare_backend_storage.py"
"${COMPOSE[@]}" up -d
