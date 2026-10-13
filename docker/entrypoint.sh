#!/bin/bash
set -e

export HOME="${HOME:-/home/user}"
export PATH="/home/user/.bun/bin:/home/user/.local/bin:$PATH"

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

if [ -n "$PLGRID_API_KEY" ] && [ ! -f /home/user/.local/share/opencode/auth.json ]; then
    mkdir -p /home/user/.local/share/opencode
    printf '{"plgrid":{"type":"api","key":"%s"}}' "$PLGRID_API_KEY" \
        > /home/user/.local/share/opencode/auth.json
    chmod 600 /home/user/.local/share/opencode/auth.json
    echo ""
    echo "PLGrid auth seeded from PLGRID_API_KEY"
fi

if [ -f /home/user/.config/opencode/package.json ] \
    && [ ! -d /home/user/.config/opencode/node_modules ]; then
    echo ""
    echo "Installing plugin dependencies..."
    bun install --silent --cwd /home/user/.config/opencode 2>/dev/null \
        || echo "Plugin dependency install failed (non-fatal)"
fi

MACRODATA_ENTRY=/home/user/.config/opencode/node_modules/@macrodata/opencode/opencode/index.ts
if [ -f "$MACRODATA_ENTRY" ]; then
    mkdir -p /home/user/.config/opencode/plugins
    printf 'export { default } from "%s"\n' "$MACRODATA_ENTRY" \
        > /home/user/.config/opencode/plugins/macrodata.js
fi

if [ "$#" -gt 0 ]; then
    exec "$@"
fi

if [ ! -f /home/user/.config/opencode/opencode.json ]; then
    echo ""
    echo "No opencode.json found. Run scripts/setup.sh on the host first."
fi

exec opencode
