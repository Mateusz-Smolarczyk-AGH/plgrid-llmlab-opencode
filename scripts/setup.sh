#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PROFILE="container"
TARGET=""
BUILD=0
UP=0

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --profile <system|container>   Config profile to deploy (default: container)
  --target <dir>                 Config target dir (default: ./data/opencode-config
                                 for container, ~/.config/opencode for system)
  --build                        Build the container image (container profile only)
  --up                           Start the container (implies --build if image missing)
  -h, --help                     Show this help

Examples:
  scripts/setup.sh --profile system --target ~/.config/opencode
  scripts/setup.sh --profile container --build --up
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --profile) PROFILE="$2"; shift 2 ;;
        --target)  TARGET="$2"; shift 2 ;;
        --build)   BUILD=1; shift ;;
        --up)      UP=1; BUILD=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

case "$PROFILE" in
    system)
        [ -z "$TARGET" ] && TARGET="$HOME/.config/opencode"
        CONFIG_DIR="$TARGET"
        ;;
    container)
        [ -z "$TARGET" ] && TARGET="$REPO_ROOT/data/opencode-config"
        CONFIG_DIR="/home/user/.config/opencode"
        ;;
    *)
        echo "Unknown profile: $PROFILE (expected system or container)" >&2
        exit 1
        ;;
esac

if [ ! -f "$REPO_ROOT/profiles/$PROFILE.json" ]; then
    echo "Missing profile: $REPO_ROOT/profiles/$PROFILE.json" >&2
    exit 1
fi

echo "Deploying profile '$PROFILE' -> $TARGET"

mkdir -p "$TARGET"

cp "$REPO_ROOT/AGENTS.md" "$TARGET/AGENTS.md"

mkdir -p "$TARGET/plugins"
cp "$REPO_ROOT/.opencode/plugins/plgrid.js" "$TARGET/plugins/plgrid.js"

if [ "$PROFILE" = "container" ]; then
    if [ -d "$REPO_ROOT/skills" ]; then
        mkdir -p "$TARGET/skills"
        cp -R "$REPO_ROOT/skills/." "$TARGET/skills/"
    fi
    if [ -d "$REPO_ROOT/tool" ]; then
        mkdir -p "$TARGET/tool"
        cp -R "$REPO_ROOT/tool/." "$TARGET/tool/"
    fi
    if [ -f "$REPO_ROOT/package.json" ]; then
        cp "$REPO_ROOT/package.json" "$TARGET/package.json"
    fi
fi

python3 "$SCRIPT_DIR/render-config.py" \
    --base "$REPO_ROOT/opencode.json" \
    --profile "$REPO_ROOT/profiles/$PROFILE.json" \
    --config-dir "$CONFIG_DIR" \
    --out "$TARGET/opencode.json"

if [ "$PROFILE" = "container" ]; then
    mkdir -p "$REPO_ROOT/data/macrodata"
    if [ ! -f "$REPO_ROOT/.env" ] && [ -f "$REPO_ROOT/.env.example" ]; then
        cp "$REPO_ROOT/.env.example" "$REPO_ROOT/.env"
        echo "Created .env from .env.example - fill in PLGRID_API_KEY before building."
    fi
fi

if [ "$BUILD" = "1" ]; then
    if [ ! -f "$REPO_ROOT/.env" ]; then
        echo "No .env found; create one from .env.example first." >&2
        exit 1
    fi
    echo "Building image..."
    docker compose -f "$REPO_ROOT/docker-compose.yml" build
    if [ "$UP" = "1" ]; then
        echo "Starting container..."
        docker compose -f "$REPO_ROOT/docker-compose.yml" up -d
        sleep 5
        if [ -f "$SCRIPT_DIR/verify.sh" ]; then
            docker exec cyfrocode /workspace/scripts/verify.sh || true
        fi
    fi
fi

echo "Done."
