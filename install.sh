#!/usr/bin/env bash
# install.sh — Install Hive into ~/.hive/ and symlink skills into ~/.claude/skills/.
# Claude Code auto-discovers skills in ~/.claude/skills/<name>/SKILL.md.
# Usage: bash install.sh
set -euo pipefail
IFS=$'\n\t'

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HIVE_HOME="${HIVE_HOME:-${HOME}/.hive}"
CLAUDE_SKILLS_DIR="${HOME}/.claude/skills"

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
}

install_scripts() {
    echo "Installing scripts to ${HIVE_HOME}/scripts/..."
    mkdir -p "${HIVE_HOME}/scripts/lib"

    cp "${REPO_DIR}/scripts/"*.sh "${HIVE_HOME}/scripts/"
    cp "${REPO_DIR}/scripts/lib/"*.sh "${HIVE_HOME}/scripts/lib/"
    chmod +x "${HIVE_HOME}/scripts/"*.sh
    chmod +x "${HIVE_HOME}/scripts/lib/"*.sh

    echo "Scripts installed."
}

install_skills() {
    echo "Installing skills to ${CLAUDE_SKILLS_DIR}/..."
    mkdir -p "${CLAUDE_SKILLS_DIR}"

    local skill_names=("hive" "hive-memory" "hive-status" "hive-compress")

    for skill in "${skill_names[@]}"; do
        local src="${REPO_DIR}/skills/${skill}"
        local dst="${CLAUDE_SKILLS_DIR}/${skill}"

        if [[ ! -d "${src}" ]]; then
            echo "WARNING: skill source ${src} not found, skipping." >&2
            continue
        fi

        # Remove old symlink or directory
        rm -rf "${dst}"

        # Copy skill directory (not symlink — avoids breakage if repo moves)
        cp -r "${src}" "${dst}"
        echo "  Installed skill: ${skill}"
    done

    echo "Skills installed."
}

install_references() {
    echo "Installing reference files..."
    local ref_src="${REPO_DIR}/skills/hive/references"
    local ref_dst="${HIVE_HOME}/skills/hive/references"

    mkdir -p "${ref_dst}"
    cp "${ref_src}/"*.md "${ref_dst}/"
    echo "References installed to ${ref_dst}/"
}

install_agents() {
    echo "Installing agent definitions..."
    mkdir -p "${HIVE_HOME}/agents"
    cp "${REPO_DIR}/agents/"*.md "${HIVE_HOME}/agents/"
    echo "Agents installed to ${HIVE_HOME}/agents/"
}

init_db() {
    echo "Initializing Hive memory database..."
    bash "${HIVE_HOME}/scripts/init.sh"
}

cleanup_old_install() {
    # Remove stale plugin registry entry from previous install method
    local registry="${HOME}/.claude/plugins/installed_plugins.json"
    if [[ -f "${registry}" ]] && command -v python3 &>/dev/null; then
        if python3 -c "
import json, sys
with open('${registry}', 'r') as f:
    r = json.load(f)
if 'hive@local' in r.get('plugins', {}):
    del r['plugins']['hive@local']
    with open('${registry}', 'w') as f:
        json.dump(r, f, indent=2)
    print('Removed stale hive@local entry from installed_plugins.json')
" 2>/dev/null; then
            true
        fi
    fi

    # Remove old cache directory
    local old_cache="${HOME}/.claude/plugins/cache/local/hive"
    if [[ -d "${old_cache}" ]]; then
        rm -rf "${old_cache}"
        echo "Removed old plugin cache at ${old_cache}"
    fi
}

print_next_steps() {
    echo ""
    echo "========================================"
    echo "  Hive installed successfully!"
    echo "========================================"
    echo ""
    echo "Restart Claude Code (or open a new session)."
    echo "The following skills will be available:"
    echo ""
    echo "  /hive <task>       — orchestrated task with memory + multi-agent"
    echo "  /hive-memory       — search and manage memories"
    echo "  /hive-status       — DB stats and session history"
    echo "  /hive-compress     — compress old memories (uses haiku)"
    echo ""
    echo "Install location: ${HIVE_HOME}/"
    echo "Skills location:  ${CLAUDE_SKILLS_DIR}/hive*"
    echo "Database:         ${HIVE_DB:-${HIVE_HOME}/memory.db}"
    echo ""
    echo "Optional: override DB location:"
    echo "  export HIVE_DB=/path/to/custom/memory.db"
    echo ""
    echo "Run tests (from repo directory):"
    echo "  bash tests/run_all.sh"
}

main() {
    echo "Installing Hive..."
    echo ""
    check_deps
    cleanup_old_install
    install_scripts
    install_skills
    install_references
    install_agents
    init_db
    print_next_steps
}

main "$@"
