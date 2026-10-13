#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECTS_FILE="$REPO_ROOT/projects.json"
OVERRIDE_FILE="$REPO_ROOT/docker-compose.override.yml"
CONTAINER="cyfrocode"

if [ ! -f "$PROJECTS_FILE" ]; then
    echo "No projects.json found; nothing to mount." >&2
    exit 1
fi

python3 "$SCRIPT_DIR/render-override.py" \
    --projects "$PROJECTS_FILE" \
    --out "$OVERRIDE_FILE"

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    echo "Container '$CONTAINER' is not running. Start it with: scripts/setup.sh --profile container --up" >&2
    exit 1
fi

COMPOSE=(docker compose -f "$REPO_ROOT/docker-compose.yml")
if [ -f "$OVERRIDE_FILE" ]; then
    COMPOSE+=(-f "$OVERRIDE_FILE")
fi

echo "Recreating container to apply project mounts..."
"${COMPOSE[@]}" up -d

echo "Done. Registered projects:"
"$SCRIPT_DIR/list-projects.sh"
