#!/usr/bin/env bash
# test_recall.sh — Tests for scripts/recall.sh
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

# Seed test data
bash "${SCRIPTS_DIR}/save.sh" --type fact    --content "PostgreSQL 15 with pgvector extension" --project "myapp" --tags "database postgres" --importance 8 > /dev/null
bash "${SCRIPTS_DIR}/save.sh" --type pattern --content "All API handlers return tuple of response and status code" --tags "api handler python" --importance 6 > /dev/null
bash "${SCRIPTS_DIR}/save.sh" --type error   --content "SQLite locked error occurs when WAL mode is off" --tags "sqlite error locking" --importance 9 > /dev/null
bash "${SCRIPTS_DIR}/save.sh" --type decision --content "Chose Redis for session storage because of TTL semantics" --project "myapp" --importance 7 > /dev/null

echo "=== test_recall.sh ==="

# Test 1: basic search returns results
output=$(bash "${SCRIPTS_DIR}/recall.sh" "postgres")
[[ "${output}" =~ "PostgreSQL" ]] && pass "basic search returns matching memory" || fail "postgres search failed"

# Test 2: search for non-existent term returns no-match message
output=$(bash "${SCRIPTS_DIR}/recall.sh" "xyznonexistent123")
[[ "${output}" =~ "No memories found" ]] && pass "no-match returns empty message" || fail "expected no-match message"

# Test 3: search increments access_count
before=$(sqlite3 "${HIVE_DB}" "SELECT access_count FROM memories WHERE content LIKE '%PostgreSQL%';")
bash "${SCRIPTS_DIR}/recall.sh" "postgres" > /dev/null
after=$(sqlite3 "${HIVE_DB}" "SELECT access_count FROM memories WHERE content LIKE '%PostgreSQL%';")
[[ "${after}" -gt "${before}" ]] && pass "access_count incremented on recall" || fail "access_count not incremented (before=${before}, after=${after})"

# Test 4: --project filter
output=$(bash "${SCRIPTS_DIR}/recall.sh" "redis" --project "myapp")
[[ "${output}" =~ "Redis" ]] && pass "--project filter returns project memory" || fail "project filter failed"

# Test 5: --type filter
output=$(bash "${SCRIPTS_DIR}/recall.sh" "sqlite" --type error)
[[ "${output}" =~ "SQLite" ]] && pass "--type filter returns correct type" || fail "type filter failed"

# Test 6: --limit flag
# Insert extra records
for i in $(seq 1 10); do
    bash "${SCRIPTS_DIR}/save.sh" --type fact --content "extra fact number ${i} about postgres" > /dev/null
done
output=$(bash "${SCRIPTS_DIR}/recall.sh" "postgres" --limit 3)
count=$(echo "${output}" | grep -c "^### \[" || true)
[[ "${count}" -le 3 ]] && pass "--limit restricts result count" || fail "--limit not working (got ${count} results)"

# Test 7: multi-word query
output=$(bash "${SCRIPTS_DIR}/recall.sh" "sqlite locked")
[[ "${output}" =~ "SQLite" ]] && pass "multi-word query works" || fail "multi-word query failed"

# Test 8: missing query exits with error
if bash "${SCRIPTS_DIR}/recall.sh" 2>/dev/null; then
    fail "missing query should exit with error"
else
    pass "missing query exits with error"
fi

echo "=== test_recall.sh DONE ==="
