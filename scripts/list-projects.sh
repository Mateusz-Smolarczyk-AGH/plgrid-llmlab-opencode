#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECTS_FILE="$REPO_ROOT/projects.json"
CONTAINER="cyfrocode"

RUNNING="false"
docker ps --format '{{.Names}}' | grep -qx "$CONTAINER" && RUNNING="true"

python3 - "$PROJECTS_FILE" "$RUNNING" "$CONTAINER" <<'PY'
import json
import subprocess
import sys

projects_file, running, container = sys.argv[1:4]
running = running == "true"

try:
    with open(projects_file) as f:
        projects = json.load(f).get("projects", [])
except (FileNotFoundError, json.JSONDecodeError):
    projects = []

if not projects:
    print("No projects registered. Add one with: scripts/add-project.sh <host_path> <name>")
    raise SystemExit(0)

print(f"{'NAME':<20} {'HOST PATH':<45} {'CONTAINER PATH':<30} STATUS")
print("-" * 110)
for project in projects:
    name = project.get("container_name", "?")
    host_path = project.get("host_path", "?")
    container_path = project.get("container_path", f"/projects/{name}")
    if running:
        result = subprocess.run(
            ["docker", "exec", container, "test", "-d", container_path],
            capture_output=True,
        )
        status = "mounted" if result.returncode == 0 else "not mounted"
    else:
        status = "container offline"
    print(f"{name:<20} {host_path:<45} {container_path:<30} {status}")
PY
