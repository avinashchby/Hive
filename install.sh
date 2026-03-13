#!/usr/bin/env bash
# install.sh — Install Hive by copying it to ~/.claude/hive/
# Skills in ~/.claude/skills/<name>/SKILL.md are auto-discovered by Claude Code.
# Usage: bash install.sh
set -euo pipefail
IFS=$'\n\t'

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="${HOME}/.claude/hive"

# Check dependencies
check_deps() {
    if ! command -v sqlite3 &>/dev/null; then
        echo "ERROR: sqlite3 not found. Install it first:" >&2
        echo "  macOS: sqlite3 is built-in (should already be available)" >&2
        echo "  Linux: sudo apt-get install sqlite3  OR  sudo yum install sqlite" >&2
        exit 1
    fi

    # Verify FTS5 support
    if ! sqlite3 :memory: "CREATE VIRTUAL TABLE t USING fts5(x);" 2>/dev/null; then
        echo "ERROR: sqlite3 does not have FTS5 support compiled in." >&2
        echo "       Hive requires SQLite 3.x with FTS5 (standard on macOS)." >&2
        exit 1
    fi
}

install_plugin() {
    echo "Installing Hive to ${PLUGIN_DIR}..."

    # Remove previous installation
    if [[ -e "${PLUGIN_DIR}" ]]; then
        echo "Removing previous installation at ${PLUGIN_DIR}"
        rm -rf "${PLUGIN_DIR}"
    fi

    # Copy repo contents
    cp -r "${REPO_DIR}" "${PLUGIN_DIR}"

    # Make scripts executable
    chmod +x "${PLUGIN_DIR}/scripts/"*.sh
    chmod +x "${PLUGIN_DIR}/scripts/lib/"*.sh
    chmod +x "${PLUGIN_DIR}/tests/"*.sh
    chmod +x "${PLUGIN_DIR}/install.sh"

    echo "Files installed."
}

init_db() {
    echo "Initializing Hive memory database..."
    bash "${PLUGIN_DIR}/scripts/init.sh"
}

print_next_steps() {
    echo ""
    echo "========================================"
    echo "  Hive installed successfully!"
    echo "========================================"
    echo ""
    echo "Start Claude Code pointing at the plugin directory:"
    echo "  claude --plugin-dir ${PLUGIN_DIR}"
    echo ""
    echo "Or add an alias to your shell profile (~/.zshrc / ~/.bashrc):"
    echo "  alias claude='claude --plugin-dir ${PLUGIN_DIR}'"
    echo ""
    echo "Available commands (inside Claude Code):"
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
    echo "  bash ${PLUGIN_DIR}/tests/run_all.sh"
}

main() {
    check_deps
    install_plugin
    init_db
    print_next_steps
}

main "$@"
