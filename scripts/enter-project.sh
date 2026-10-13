#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECTS_FILE="$REPO_ROOT/projects.json"
CONTAINER="cyfrocode"

if [ $# -lt 1 ]; then
    echo "Usage: $(basename "$0") <project_name>" >&2
    echo ""
    echo "Registered projects:"
    if [ -f "$PROJECTS_FILE" ]; then
        python3 -c "import json;print('\n'.join('  - '+p['container_name'] for p in json.load(open('$PROJECTS_FILE')).get('projects',[])))"
    else
        echo "  (none)"
    fi
    exit 1
fi

PROJECT_NAME="$1"

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    echo "Container '$CONTAINER' is not running. Start it with: scripts/setup.sh --profile container --up" >&2
    exit 1
fi

CONTAINER_PATH="$(python3 -c "
import json
try:
    data = json.load(open('$PROJECTS_FILE'))
except Exception:
    data = {'projects': []}
for p in data.get('projects', []):
    if p.get('container_name') == '$PROJECT_NAME':
        print(p.get('container_path', '/projects/$PROJECT_NAME'))
        break
")"
[ -z "$CONTAINER_PATH" ] && CONTAINER_PATH="/projects/$PROJECT_NAME"

if ! docker exec "$CONTAINER" test -d "$CONTAINER_PATH"; then
    echo "Project folder not found in container: $CONTAINER_PATH" >&2
    echo "Available: $(docker exec "$CONTAINER" ls -1 /projects 2>/dev/null | tr '\n' ' ')" >&2
    echo "Register it with: scripts/add-project.sh <host_path> $PROJECT_NAME" >&2
    exit 1
fi

docker exec -it "$CONTAINER" /bin/bash -c "cd '$CONTAINER_PATH' && exec opencode"
