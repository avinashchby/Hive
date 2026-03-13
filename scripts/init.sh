#!/usr/bin/env bash
# init.sh — Idempotent DB initialization. Safe to run multiple times.
# Creates the SQLite database with FTS5 full-text search and sync triggers.
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/db.sh
source "${SCRIPT_DIR}/lib/db.sh"

main() {
    echo "Initializing Hive memory store at: ${DB_PATH}"
    mkdir -p "$(dirname "${DB_PATH}")"

    db << 'SQL'
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS memories (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    type          TEXT    NOT NULL CHECK(type IN ('fact','decision','pattern','error','preference')),
    content       TEXT    NOT NULL,
    project       TEXT    NOT NULL DEFAULT '',
    tags          TEXT    NOT NULL DEFAULT '',
    importance    INTEGER NOT NULL DEFAULT 5 CHECK(importance BETWEEN 1 AND 10),
    access_count  INTEGER NOT NULL DEFAULT 0,
    created_at    INTEGER NOT NULL DEFAULT (strftime('%s','now')),
    last_accessed INTEGER NOT NULL DEFAULT (strftime('%s','now'))
);

-- External-content FTS5 table: porter stemmer handles plurals/conjugations.
-- Single source of truth stays in memories; triggers keep FTS index in sync.
CREATE VIRTUAL TABLE IF NOT EXISTS memories_fts
    USING fts5(
        content,
        tags,
        content     = memories,
        content_rowid = id,
        tokenize    = 'porter ascii'
    );

CREATE TRIGGER IF NOT EXISTS memories_ai AFTER INSERT ON memories BEGIN
    INSERT INTO memories_fts(rowid, content, tags) VALUES (new.id, new.content, new.tags);
END;

CREATE TRIGGER IF NOT EXISTS memories_ad AFTER DELETE ON memories BEGIN
    INSERT INTO memories_fts(memories_fts, rowid, content, tags)
    VALUES ('delete', old.id, old.content, old.tags);
END;

CREATE TRIGGER IF NOT EXISTS memories_au AFTER UPDATE ON memories BEGIN
    INSERT INTO memories_fts(memories_fts, rowid, content, tags)
    VALUES ('delete', old.id, old.content, old.tags);
    INSERT INTO memories_fts(rowid, content, tags) VALUES (new.id, new.content, new.tags);
END;

-- Sessions: one row per /hive invocation for audit and status reporting.
CREATE TABLE IF NOT EXISTS sessions (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    task        TEXT    NOT NULL,
    project     TEXT    NOT NULL DEFAULT '',
    agents_used TEXT    NOT NULL DEFAULT '',
    started_at  INTEGER NOT NULL DEFAULT (strftime('%s','now')),
    ended_at    INTEGER,
    cost_note   TEXT    NOT NULL DEFAULT ''
);

-- Compression audit log.
CREATE TABLE IF NOT EXISTS compress_log (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    run_at       INTEGER NOT NULL DEFAULT (strftime('%s','now')),
    memories_in  INTEGER NOT NULL,
    memories_out INTEGER NOT NULL,
    bytes_saved  INTEGER NOT NULL DEFAULT 0
);
SQL

    echo "Hive initialized successfully."
    db "SELECT COUNT(*) || ' memories in store' FROM memories;"
}

main "$@"
