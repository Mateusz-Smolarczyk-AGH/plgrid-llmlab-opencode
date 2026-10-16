#!/bin/bash
set -e

export HOME="${HOME:-/home/user}"
export PATH="/home/user/.bun/bin:/home/user/.local/bin:$PATH"
export WIKI_HOME="${WIKI_HOME:-$HOME/wikis}"

if [ "$(id -u)" = "0" ]; then
    chown -R 1000:1000 /home/user 2>/dev/null || true
    exec gosu 1000:1000 "$0" "$@"
fi

echo "CyfroCode container starting..."
echo ""
echo "Environment:"
echo "   Python:   $(python3 --version)"
echo "   Node.js:  $(node --version)"
echo "   Bun:      $(bun --version 2>&1 || echo 'missing')"
echo "   Git:      $(git --version)"
echo "   opencode: $(opencode --version 2>&1 | head -1)"
echo "   GitNexus: $(gitnexus --version 2>&1 | head -1)"
echo "   paper-search: $(uv tool list 2>/dev/null | grep paper-search-mcp | head -1 | awk '{print $2}' || echo 'missing')"
echo "   basic-memory: $(basic-memory --version 2>&1 | head -1 || echo 'missing')"

ENV_SECRET=/run/secrets/cyfrocode_env
PLGRID_KEY=""
if [ -f "$ENV_SECRET" ]; then
    PLGRID_KEY="$(grep -E '^PLGRID_API_KEY=' "$ENV_SECRET" | tail -n1 | cut -d= -f2- | tr -d '\r')"
fi

if [ -n "$PLGRID_KEY" ]; then
    CRED_FILE="$(mktemp)"
    python3 - "$PLGRID_KEY" > "$CRED_FILE" <<'PY'
import json
import sys

print(json.dumps([{
    "id": "plgrid",
    "integrationID": "plgrid",
    "type": "api",
    "label": "PLGrid Forge",
    "active": True,
    "value": {"type": "key", "key": sys.argv[1]},
}]))
PY
    seeded=0
    for _ in 1 2 3 4 5; do
        out="$(opencode auth import --standalone "$CRED_FILE" 2>&1 || true)"
        if printf '%s' "$out" | grep -Eq 'Imported 1 credential|already present'; then
            seeded=1
            break
        fi
        sleep 2
    done
    rm -f "$CRED_FILE"
    echo ""
    if [ "$seeded" = "1" ]; then
        echo "PLGrid auth seeded from $ENV_SECRET (opencode.db)"
    else
        echo "WARN: could not seed PLGrid auth automatically."
        echo "      Run 'opencode auth login plgrid' inside the container once."
    fi
fi
unset PLGRID_KEY

if [ -f /home/user/.config/opencode/package.json ] \
    && [ ! -d /home/user/.config/opencode/node_modules ]; then
    echo ""
    echo "Installing plugin dependencies..."
    bun install --silent --cwd /home/user/.config/opencode 2>/dev/null \
        || echo "Plugin dependency install failed (non-fatal)"
fi

# The key was read from the mounted secret and never exported, so it is not in
# this process's environment; these unsets remove it from any inherited env too.
unset PLGRID_KEY PLGRID_API_KEY CONTEXT7_API_KEY GITHUB_PERSONAL_ACCESS_TOKEN

if [ "$#" -gt 0 ]; then
    exec "$@"
fi

if [ ! -f /home/user/.config/opencode/opencode.json ]; then
    echo ""
    echo "No opencode.json found. Run scripts/setup.sh on the host first."
fi

exec opencode
