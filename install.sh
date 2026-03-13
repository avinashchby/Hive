#!/usr/bin/env bash
# install.sh — Install Hive by registering it in Claude Code's plugin system.
# This copies Hive to the plugins cache and registers it in installed_plugins.json
# so /hive, /hive-memory, /hive-status, /hive-compress appear automatically.
# Usage: bash install.sh
set -euo pipefail
IFS=$'\n\t'

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_NAME="hive"
PLUGIN_VERSION="1.0.0"
CACHE_DIR="${HOME}/.claude/plugins/cache/local/${PLUGIN_NAME}/${PLUGIN_VERSION}"
REGISTRY="${HOME}/.claude/plugins/installed_plugins.json"

check_deps() {
    if ! command -v sqlite3 &>/dev/null; then
        echo "ERROR: sqlite3 not found." >&2
        echo "  macOS: sqlite3 is built-in (should already be available)" >&2
        echo "  Linux: sudo apt-get install sqlite3" >&2
        exit 1
    fi

    if ! sqlite3 :memory: "CREATE VIRTUAL TABLE t USING fts5(x);" 2>/dev/null; then
        echo "ERROR: sqlite3 does not have FTS5 support compiled in." >&2
        exit 1
    fi

    if ! command -v python3 &>/dev/null; then
        echo "ERROR: python3 is required for JSON registry update." >&2
        exit 1
    fi
}

install_files() {
    echo "Installing Hive to ${CACHE_DIR}..."
    rm -rf "${CACHE_DIR}"
    mkdir -p "${CACHE_DIR}"
    cp -r "${REPO_DIR}/." "${CACHE_DIR}/"
    chmod +x "${CACHE_DIR}/scripts/"*.sh
    chmod +x "${CACHE_DIR}/scripts/lib/"*.sh
    chmod +x "${CACHE_DIR}/tests/"*.sh
    chmod +x "${CACHE_DIR}/install.sh"
    echo "Files installed."
}

register_plugin() {
    echo "Registering Hive in Claude Code plugin registry..."

    # Ensure registry file exists with base structure
    if [[ ! -f "${REGISTRY}" ]]; then
        echo '{"version": 2, "plugins": {}}' > "${REGISTRY}"
    fi

    local now
    now=$(python3 -c "from datetime import datetime, timezone; print(datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.000Z'))")

    python3 - << PYEOF
import json, sys

registry_path = "${REGISTRY}"
cache_dir = "${CACHE_DIR}"
now = "${now}"

with open(registry_path, 'r') as f:
    registry = json.load(f)

key = "hive@local"
entry = {
    "scope": "user",
    "installPath": cache_dir,
    "version": "${PLUGIN_VERSION}",
    "installedAt": now,
    "lastUpdated": now
}

registry["plugins"][key] = [entry]

with open(registry_path, 'w') as f:
    json.dump(registry, f, indent=2)

print(f"Registered {key} at {cache_dir}")
PYEOF
}

init_db() {
    echo "Initializing Hive memory database..."
    bash "${CACHE_DIR}/scripts/init.sh"
}

print_next_steps() {
    echo ""
    echo "========================================"
    echo "  Hive installed successfully!"
    echo "========================================"
    echo ""
    echo "Restart Claude Code (or open a new session)."
    echo "The following commands will be available:"
    echo ""
    echo "  /hive <task>       — orchestrated task with memory + multi-agent"
    echo "  /hive-memory       — search and manage memories"
    echo "  /hive-status       — DB stats and session history"
    echo "  /hive-compress     — compress old memories (uses haiku)"
    echo ""
    echo "Optional: override DB location:"
    echo "  export HIVE_DB=/path/to/custom/memory.db"
    echo "  # Add to ~/.zshrc or ~/.bashrc for persistence"
    echo ""
    echo "Run tests:"
    echo "  bash ${CACHE_DIR}/tests/run_all.sh"
}

main() {
    check_deps
    install_files
    register_plugin
    init_db
    print_next_steps
}

main "$@"
