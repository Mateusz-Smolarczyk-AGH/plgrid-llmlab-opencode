#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECTS_FILE="$REPO_ROOT/projects.json"
OVERRIDE_FILE="$REPO_ROOT/docker-compose.override.yml"
CONTAINER="cyfrocode"

usage() {
    cat <<EOF
Usage: $(basename "$0") <host_path> <container_name>

Registers a project in projects.json and regenerates docker-compose.override.yml.
The host path is mounted at /projects/<container_name> in the container.
EOF
}

if [ $# -lt 2 ]; then
    usage
    exit 1
fi

HOST_PATH="$(realpath "$1")"
CONTAINER_NAME="$2"
CONTAINER_PATH="/projects/$CONTAINER_NAME"

if [ ! -d "$HOST_PATH" ]; then
    echo "Host path does not exist: $HOST_PATH" >&2
    exit 1
fi

python3 - "$PROJECTS_FILE" "$OVERRIDE_FILE" "$HOST_PATH" "$CONTAINER_NAME" "$CONTAINER_PATH" <<'PY'
import json
import sys

projects_file, override_file, host_path, name, container_path = sys.argv[1:6]

try:
    with open(projects_file) as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = {"projects": []}

data.setdefault("projects", [])
updated = False
for project in data["projects"]:
    if project.get("container_name") == name:
        project["host_path"] = host_path
        project["container_path"] = container_path
        updated = True
        break
if not updated:
    data["projects"].append({
        "host_path": host_path,
        "container_name": name,
        "container_path": container_path,
    })

with open(projects_file, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

lines = ["services:", "  cyfrocode:", "    volumes:"]
for project in data["projects"]:
    lines.append(f"      - {project['host_path']}:{project['container_path']}:z")
with open(override_file, "w") as f:
    f.write("\n".join(lines) + "\n")

print(f"{'Updated' if updated else 'Added'} project '{name}' -> {container_path}")
PY

if docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    echo "Restarting container to apply mounts..."
    docker compose -f "$REPO_ROOT/docker-compose.yml" \
        -f "$OVERRIDE_FILE" up -d
fi

echo "Done. Enter with: scripts/enter-project.sh $CONTAINER_NAME"
