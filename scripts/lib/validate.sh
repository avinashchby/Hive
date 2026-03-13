#!/usr/bin/env bash
# lib/validate.sh — Input validation helpers. Sourced by save.sh and recall.sh.
set -euo pipefail
IFS=$'\n\t'

VALID_TYPES="fact decision pattern error preference"

validate_type() {
    local t="$1"
    case "${t}" in
        fact|decision|pattern|error|preference) return 0 ;;
        *)
            echo "ERROR: invalid type '${t}'. Must be one of: ${VALID_TYPES}" >&2
            return 1
            ;;
    esac
}

validate_importance() {
    local n="$1"
    if ! [[ "${n}" =~ ^[0-9]+$ ]] || (( n < 1 || n > 10 )); then
        echo "ERROR: importance must be an integer 1-10, got '${n}'" >&2
        return 1
    fi
}

require_db() {
    if ! db_exists; then
        echo "ERROR: Hive DB not found at ${DB_PATH}." >&2
        echo "       Run: bash $(dirname "${BASH_SOURCE[0]}")/../init.sh" >&2
        return 1
    fi
}

# escape_sql: single-quote escape for safe SQLite interpolation.
# Usage: escaped=$(escape_sql "${user_input}")
escape_sql() {
    printf "%s" "$1" | sed "s/'/''/g"
}
