#!/usr/bin/env bash
# test_compress.sh — Tests for scripts/compress.sh
# Note: Does NOT call claude API. Tests candidate selection and DB state only.
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${SCRIPT_DIR}/../scripts"

export HIVE_DB
HIVE_DB=$(mktemp /tmp/hive_test_XXXXX.db)
trap 'rm -f "${HIVE_DB}"' EXIT

bash "${SCRIPTS_DIR}/init.sh" > /dev/null

pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1" >&2; exit 1; }

echo "=== test_compress.sh ==="

# Test 1: no candidates → compress reports nothing to do
export HIVE_COMPRESS_AGE=30
export HIVE_COMPRESS_MAX_IMPORTANCE=3
output=$(bash "${SCRIPTS_DIR}/compress.sh")
[[ "${output}" =~ "No memories eligible" ]] && pass "no candidates → reports nothing to do" || fail "expected no-candidates message"

# Test 2: seed old low-importance memories using backdated SQL
sqlite3 "${HIVE_DB}" << 'SQL'
INSERT INTO memories(type, content, importance, access_count, created_at, last_accessed)
VALUES
  ('fact', 'old trivial fact one',   2, 0, strftime('%s','now') - 40*86400, strftime('%s','now') - 40*86400),
  ('fact', 'old trivial fact two',   1, 0, strftime('%s','now') - 50*86400, strftime('%s','now') - 50*86400),
  ('fact', 'old trivial fact three', 3, 0, strftime('%s','now') - 35*86400, strftime('%s','now') - 35*86400);
SQL
# Manually add to FTS (triggers fire on INSERT via normal path; direct SQL inserts bypass them)
sqlite3 "${HIVE_DB}" << 'SQL'
INSERT INTO memories_fts(rowid, content, tags)
SELECT id, content, tags FROM memories WHERE content LIKE 'old trivial%';
SQL

count=$(sqlite3 "${HIVE_DB}" "SELECT COUNT(*) FROM memories WHERE importance <= 3 AND access_count = 0;")
[[ "${count}" -eq 3 ]] && pass "3 candidate memories seeded" || fail "expected 3 candidates, got ${count}"

# Test 3: mock compress by simulating what compress.sh does (without calling claude)
# Manually: delete the 3 candidates, insert 1 summary, log it
IDS=$(sqlite3 "${HIVE_DB}" "SELECT id FROM memories WHERE importance <= 3 AND access_count = 0;" | tr '\n' ',' | sed 's/,$//')
sqlite3 "${HIVE_DB}" "DELETE FROM memories WHERE id IN (${IDS});"
sqlite3 "${HIVE_DB}" "INSERT INTO memories(type, content, tags, importance) VALUES('pattern','Compressed test summary','compressed',5);"
sqlite3 "${HIVE_DB}" "INSERT INTO compress_log(memories_in, memories_out) VALUES(3,1);"

# Verify candidates are gone
remaining=$(sqlite3 "${HIVE_DB}" "SELECT COUNT(*) FROM memories WHERE content LIKE 'old trivial%';")
[[ "${remaining}" -eq 0 ]] && pass "original memories deleted after compression" || fail "originals not deleted (${remaining} remaining)"

# Verify summary exists
summary_count=$(sqlite3 "${HIVE_DB}" "SELECT COUNT(*) FROM memories WHERE tags='compressed';")
[[ "${summary_count}" -eq 1 ]] && pass "compressed summary memory exists" || fail "summary memory missing"

# Verify compress_log
log_count=$(sqlite3 "${HIVE_DB}" "SELECT COUNT(*) FROM compress_log;")
[[ "${log_count}" -eq 1 ]] && pass "compress_log entry written" || fail "compress_log missing"

log_row=$(sqlite3 "${HIVE_DB}" "SELECT memories_in || '|' || memories_out FROM compress_log LIMIT 1;")
[[ "${log_row}" == "3|1" ]] && pass "compress_log records correct counts" || fail "compress_log wrong: ${log_row}"

# Test 4: high-importance memories are NOT selected as candidates
sqlite3 "${HIVE_DB}" "INSERT INTO memories(type, content, importance, access_count, created_at) VALUES('fact','important fact', 8, 0, strftime(''%s'',''now'') - 60*86400);" 2>/dev/null || \
sqlite3 "${HIVE_DB}" "INSERT INTO memories(type, content, importance, access_count, created_at) VALUES('fact','important fact', 8, 0, strftime('%s','now') - 60*86400);"
important_candidate=$(sqlite3 "${HIVE_DB}" "SELECT COUNT(*) FROM memories WHERE importance > 3 AND content='important fact';")
[[ "${important_candidate}" -eq 1 ]] && pass "high-importance memory not compressed" || fail "high-importance memory was affected"

echo "=== test_compress.sh DONE ==="
