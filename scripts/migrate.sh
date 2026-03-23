#!/usr/bin/env bash
# migrate.sh — Idempotent schema migration: adds 'architecture' to memories.type CHECK constraint.
# Safe to run multiple times — detects if migration is already applied.
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/db.sh
source "${SCRIPT_DIR}/lib/db.sh"

# check_already_applied: inspect the CREATE TABLE DDL in sqlite_master to see if
# 'architecture' is already present in the CHECK constraint. No INSERT needed.
# Returns 0 if already applied (or table doesn't exist yet), 1 otherwise.
check_already_applied() {
    local tbl
    tbl=$(db "SELECT name FROM sqlite_master WHERE type='table' AND name='memories';" 2>/dev/null || echo "")
    if [[ -z "${tbl}" ]]; then
        # No memories table yet — new DB, init.sh will create it correctly
        return 0
    fi
    local ddl
    ddl=$(db "SELECT sql FROM sqlite_master WHERE type='table' AND name='memories';")
    if [[ "${ddl}" == *"architecture"* ]]; then
        echo "Migration already applied."
        return 0
    fi
    return 1
}

recreate_triggers() {
    db << 'SQL'
CREATE TRIGGER memories_ai AFTER INSERT ON memories BEGIN
    INSERT INTO memories_fts(rowid, content, tags) VALUES (new.id, new.content, new.tags);
END;
CREATE TRIGGER memories_ad AFTER DELETE ON memories BEGIN
    INSERT INTO memories_fts(memories_fts, rowid, content, tags)
    VALUES ('delete', old.id, old.content, old.tags);
END;
CREATE TRIGGER memories_au AFTER UPDATE ON memories BEGIN
    INSERT INTO memories_fts(memories_fts, rowid, content, tags)
    VALUES ('delete', old.id, old.content, old.tags);
    INSERT INTO memories_fts(rowid, content, tags) VALUES (new.id, new.content, new.tags);
END;
SQL
}

run_migration() {
    db << 'SQL'
BEGIN TRANSACTION;

CREATE TABLE memories_new (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    type          TEXT    NOT NULL CHECK(type IN ('fact','decision','pattern','error','preference','architecture')),
    content       TEXT    NOT NULL,
    project       TEXT    NOT NULL DEFAULT '',
    tags          TEXT    NOT NULL DEFAULT '',
    importance    INTEGER NOT NULL DEFAULT 5 CHECK(importance BETWEEN 1 AND 10),
    access_count  INTEGER NOT NULL DEFAULT 0,
    created_at    INTEGER NOT NULL DEFAULT (strftime('%s','now')),
    last_accessed INTEGER NOT NULL DEFAULT (strftime('%s','now'))
);

INSERT INTO memories_new
    SELECT id, type, content, project, tags, importance, access_count, created_at, last_accessed
    FROM memories;

DROP TABLE memories;

ALTER TABLE memories_new RENAME TO memories;

COMMIT;
SQL

    recreate_triggers
}

main() {
    if check_already_applied; then
        echo "Migration already applied."
        exit 0
    fi

    run_migration
    echo "Migration applied: added architecture type."
}

main "$@"
