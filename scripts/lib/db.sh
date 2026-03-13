#!/usr/bin/env bash
# lib/db.sh — Shared database path resolution and query helper.
# Sourced by all scripts in scripts/. Do not execute directly.
set -euo pipefail
IFS=$'\n\t'

HIVE_HOME="${HIVE_HOME:-${HOME}/.hive}"
DB_PATH="${HIVE_DB:-${HIVE_HOME}/memory.db}"

# db: Run sqlite3 with standard separator and error handling.
# Usage: db "SQL statement"   OR   db <<'SQL' ... SQL
db() {
    sqlite3 -separator '|' "${DB_PATH}" "$@"
}

db_exists() {
    [[ -f "${DB_PATH}" ]]
}
