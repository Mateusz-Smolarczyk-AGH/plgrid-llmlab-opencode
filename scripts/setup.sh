#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OVERRIDE_FILE="$REPO_ROOT/docker-compose.override.yml"
PROJECTS_FILE="$REPO_ROOT/projects.json"

PROFILE="container"
TARGET=""
BUILD=0
UP=0
OPENCODE_VERSION="2"
OPENCODE_REFRESH=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --profile <system|container>   Config profile to deploy (default: container)
  --target <dir>                 Config target dir (default: ./data/opencode-config
                                 for container, ~/.config/opencode for system)
  --build                        Build the container image (container profile only)
  --up                           Start the container (implies --build if image missing)
  --opencode-version <spec>      OpenCode version to install in the image
                                 (npm dist-tag or version, default: 2)
  --update-opencode              Install the newest OpenCode (equivalent to
                                 --opencode-version latest, forces a fresh install)
  -h, --help                     Show this help

Examples:
  scripts/setup.sh --profile system --target ~/.config/opencode
  scripts/setup.sh --profile container --build --up
  scripts/setup.sh --profile container --build --up --update-opencode
  scripts/setup.sh --profile container --build --opencode-version 2.1.0
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --profile)          PROFILE="$2"; shift 2 ;;
        --target)           TARGET="$2"; shift 2 ;;
        --build)            BUILD=1; shift ;;
        --up)               UP=1; BUILD=1; shift ;;
        --opencode-version) OPENCODE_VERSION="$2"; shift 2 ;;
        --update-opencode)  OPENCODE_VERSION="latest"; OPENCODE_REFRESH="$(date +%s)"; shift ;;
        -h|--help)          usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

if [ "$PROFILE" != "container" ] \
    && { [ "$OPENCODE_VERSION" != "2" ] || [ -n "$OPENCODE_REFRESH" ]; }; then
    echo "OpenCode version options apply only to the container profile." >&2
    exit 1
fi

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

ensure_data_dir() {
    local dir="$1"
    if [ -e "$dir" ] && [ ! -w "$dir" ]; then
        if [ -z "$(ls -A "$dir" 2>/dev/null)" ] && rmdir "$dir" 2>/dev/null; then
            mkdir -p "$dir"
            echo "Recreated non-writable empty dir: $dir"
        else
            echo "WARN: $dir is not writable; fix ownership with: sudo chown $(id -u):$(id -g) $dir" >&2
        fi
    fi
    mkdir -p "$dir"
}

echo "Deploying profile '$PROFILE' -> $TARGET"

mkdir -p "$TARGET"

cp "$REPO_ROOT/AGENTS.md" "$TARGET/AGENTS.md"

mkdir -p "$TARGET/plugins"
cp "$REPO_ROOT/plugin/plgrid.js" "$TARGET/plugins/plgrid.js"

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
    ensure_data_dir "$REPO_ROOT/data/opencode-data"
    ensure_data_dir "$REPO_ROOT/data/basic-memory"
    ensure_data_dir "$REPO_ROOT/data/basic-memory-config"
    ensure_data_dir "$REPO_ROOT/data/wikis"
    if [ ! -f "$REPO_ROOT/.env" ] && [ -f "$REPO_ROOT/.env.example" ]; then
        cp "$REPO_ROOT/.env.example" "$REPO_ROOT/.env"
        echo "Created .env from .env.example - fill in PLGRID_API_KEY before building."
    fi
    if [ -f "$PROJECTS_FILE" ]; then
        python3 "$SCRIPT_DIR/render-override.py" \
            --projects "$PROJECTS_FILE" \
            --out "$OVERRIDE_FILE"
    fi
fi

if [ "$BUILD" = "1" ]; then
    if [ ! -f "$REPO_ROOT/.env" ]; then
        echo "No .env found; create one from .env.example first." >&2
        exit 1
    fi
    COMPOSE=(docker compose -f "$REPO_ROOT/docker-compose.yml")
    if [ -f "$OVERRIDE_FILE" ]; then
        COMPOSE+=(-f "$OVERRIDE_FILE")
    fi
    BUILD_ARGS=(--build-arg "OPENCODE_VERSION=$OPENCODE_VERSION")
    if [ -n "$OPENCODE_REFRESH" ]; then
        BUILD_ARGS+=(--build-arg "OPENCODE_REFRESH=$OPENCODE_REFRESH")
    fi
    echo "Building image (opencode $OPENCODE_VERSION)..."
    "${COMPOSE[@]}" build "${BUILD_ARGS[@]}"
    if [ "$UP" = "1" ]; then
        echo "Starting container..."
        "${COMPOSE[@]}" up -d
        sleep 5
        if [ -f "$SCRIPT_DIR/verify.sh" ]; then
            docker exec cyfrocode /workspace/scripts/verify.sh || true
        fi
    fi
fi

echo "Done."
