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
check "opencode 2.x"       "opencode --version | grep -q 'v2'"
check "gitnexus"           "gitnexus --version"
check "crawl4ai (crwl)"     "crwl --help"
check "playwright"         "python3 -c 'import playwright'"
check "playwright-cli"     "playwright-cli --version"
check "playwright-cli chromium" "(cd /tmp && playwright-cli open about:blank && playwright-cli close)"
check "basic-memory"       "basic-memory --version"
check "opencode.json"      "test -f /home/user/.config/opencode/opencode.json"
check "AGENTS.md"          "test -f /home/user/.config/opencode/AGENTS.md"
check "plgrid plugin"      "test -f /home/user/.config/opencode/plugins/plgrid.js"
check "plgrid auth"        "opencode auth list --standalone 2>/dev/null | grep -qi plgrid"

if [ -f /home/user/.config/opencode/opencode.json ]; then
    for server in gitnexus basic-memory; do
        if python3 -c "import json,sys;d=json.load(open('/home/user/.config/opencode/opencode.json'));assert sys.argv[1] in d.get('mcp',{})" "$server" 2>/dev/null; then
            echo "ok   - $server mcp enabled (container profile)"
            PASS=$((PASS + 1))
        else
            echo "warn - $server mcp not present"
        fi
    done
fi

echo ""
echo "Passed: $PASS  Failed: $FAIL"
[ "$FAIL" -eq 0 ]
