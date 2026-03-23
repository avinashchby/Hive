#!/usr/bin/env bash
# test_init.sh — Tests for scripts/init.sh
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${SCRIPT_DIR}/../scripts"

# Isolated temp DB for each test run
export HIVE_DB
HIVE_DB=$(mktemp /tmp/hive_test_XXXXX.db)
trap 'rm -f "${HIVE_DB}"' EXIT

pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1" >&2; exit 1; }

echo "=== test_init.sh ==="

# Test 1: init creates DB file
rm -f "${HIVE_DB}"
bash "${SCRIPTS_DIR}/init.sh" > /dev/null
[[ -f "${HIVE_DB}" ]] && pass "init creates DB file" || fail "DB file not created"

# Test 2: memories table exists
result=$(sqlite3 "${HIVE_DB}" "SELECT name FROM sqlite_master WHERE type='table' AND name='memories';")
[[ "${result}" == "memories" ]] && pass "memories table exists" || fail "memories table missing"

# Test 3: sessions table exists
result=$(sqlite3 "${HIVE_DB}" "SELECT name FROM sqlite_master WHERE type='table' AND name='sessions';")
[[ "${result}" == "sessions" ]] && pass "sessions table exists" || fail "sessions table missing"

# Test 4: compress_log table exists
result=$(sqlite3 "${HIVE_DB}" "SELECT name FROM sqlite_master WHERE type='table' AND name='compress_log';")
[[ "${result}" == "compress_log" ]] && pass "compress_log table exists" || fail "compress_log table missing"

# Test 5: FTS5 virtual table exists
result=$(sqlite3 "${HIVE_DB}" "SELECT name FROM sqlite_master WHERE type='table' AND name='memories_fts';")
[[ "${result}" == "memories_fts" ]] && pass "memories_fts FTS table exists" || fail "FTS table missing"

# Test 6: init is idempotent (running twice does not error)
bash "${SCRIPTS_DIR}/init.sh" > /dev/null
pass "init is idempotent"

# Test 7: WAL mode is active
result=$(sqlite3 "${HIVE_DB}" "PRAGMA journal_mode;")
[[ "${result}" == "wal" ]] && pass "WAL mode active" || fail "WAL mode not active (got: ${result})"

# Test 8: architecture type is accepted as valid
output=$(bash "${SCRIPTS_DIR}/save.sh" --type architecture --content "Chose hexagonal architecture" --importance 8 2>&1)
[[ "${output}" =~ "Memory saved:" ]] && pass "architecture type is accepted" || fail "architecture type rejected: ${output}"

# Test 9: project_context table exists
result=$(sqlite3 "${HIVE_DB}" "SELECT name FROM sqlite_master WHERE type='table' AND name='project_context';")
[[ "${result}" == "project_context" ]] && pass "project_context table exists" || fail "project_context table missing"

# Test 10: migration is idempotent (run twice, no error)
bash "${SCRIPTS_DIR}/migrate.sh" > /dev/null
pass "migration is idempotent"

# Test 11: migrate.sh correctly migrates an old-schema DB (no architecture type)
OLD_DB=$(mktemp /tmp/hive_old_XXXXX.db)
# Create DB with old 5-type CHECK constraint (no architecture)
sqlite3 "${OLD_DB}" "
PRAGMA journal_mode = WAL;
CREATE TABLE memories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT NOT NULL CHECK(type IN ('fact','decision','pattern','error','preference')),
    content TEXT NOT NULL,
    project TEXT NOT NULL DEFAULT '',
    tags TEXT NOT NULL DEFAULT '',
    importance INTEGER NOT NULL DEFAULT 5 CHECK(importance BETWEEN 1 AND 10),
    access_count INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
    last_accessed INTEGER NOT NULL DEFAULT (strftime('%s','now'))
);
INSERT INTO memories(type,content) VALUES('fact','old fact');
"
# Run init.sh against old DB (which creates FTS table and calls migrate.sh internally)
HIVE_DB="${OLD_DB}" bash "${SCRIPTS_DIR}/init.sh" > /dev/null
# Verify architecture type now accepted
output=$(HIVE_DB="${OLD_DB}" bash "${SCRIPTS_DIR}/save.sh" --type architecture --content "migrated test" 2>&1)
[[ "${output}" =~ "Memory saved:" ]] && pass "migrate.sh upgrades old-schema DB" || fail "migration failed: ${output}"
# Verify old data preserved
count=$(sqlite3 "${OLD_DB}" "SELECT COUNT(*) FROM memories WHERE type='fact';")
[[ "${count}" -eq 1 ]] && pass "old data preserved after migration" || fail "old data lost (count=${count})"
rm -f "${OLD_DB}"

echo "=== test_init.sh DONE ==="
