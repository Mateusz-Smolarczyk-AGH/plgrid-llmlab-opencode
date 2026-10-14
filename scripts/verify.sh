#!/usr/bin/env bash
set -uo pipefail

PASS=0
FAIL=0

check() {
    if eval "$2" >/dev/null 2>&1; then
        echo "ok   - $1"
        PASS=$((PASS + 1))
    else
        echo "FAIL - $1"
        FAIL=$((FAIL + 1))
    fi
}

echo "CyfroCode verification"
echo ""

check "python3"            "python3 --version"
check "node"               "node --version"
check "bun"                "bun --version"
check "git"                "git --version"
check "opencode"           "opencode --version"
check "gitnexus"           "gitnexus --version"
check "crawl4ai (crwl)"     "crwl --help"
check "playwright"         "python3 -c 'import playwright'"
check "opencode.json"      "test -f /home/user/.config/opencode/opencode.json"
check "AGENTS.md"          "test -f /home/user/.config/opencode/AGENTS.md"
check "plgrid plugin"      "test -f /home/user/.config/opencode/plugins/plgrid.js"
check "plgrid auth"        "test -f /home/user/.local/share/opencode/auth.json"

if [ -f /home/user/.config/opencode/opencode.json ]; then
    if python3 -c "import json;d=json.load(open('/home/user/.config/opencode/opencode.json'));assert 'gitnexus' in d.get('mcp',{})" 2>/dev/null; then
        echo "ok   - gitnexus mcp enabled (container profile)"
        PASS=$((PASS + 1))
    else
        echo "warn - gitnexus mcp not present"
    fi
fi

echo ""
echo "Passed: $PASS  Failed: $FAIL"
[ "$FAIL" -eq 0 ]
