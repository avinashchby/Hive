#!/usr/bin/env bash
# test_save.sh — Tests for scripts/save.sh
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

echo "=== test_save.sh ==="

# Test 1: save a fact
output=$(bash "${SCRIPTS_DIR}/save.sh" \
  --type fact \
  --content "Project uses PostgreSQL 15" \
  --project "myapp" \
  --importance 7)
[[ "${output}" =~ "Memory saved:" ]] && pass "save fact returns confirmation" || fail "save did not confirm"

# Test 2: verify row exists in DB
count=$(sqlite3 "${HIVE_DB}" "SELECT COUNT(*) FROM memories WHERE type='fact';")
[[ "${count}" -eq 1 ]] && pass "fact row inserted" || fail "fact row missing (count=${count})"

# Test 3: save all valid types
for t in decision pattern error preference; do
    bash "${SCRIPTS_DIR}/save.sh" --type "${t}" --content "test ${t}" > /dev/null
done
count=$(sqlite3 "${HIVE_DB}" "SELECT COUNT(*) FROM memories;")
[[ "${count}" -eq 5 ]] && pass "all 5 types save correctly" || fail "expected 5 rows, got ${count}"

# Test 4: invalid type is rejected
if bash "${SCRIPTS_DIR}/save.sh" --type "bogus" --content "test" 2>/dev/null; then
    fail "invalid type should have been rejected"
else
    pass "invalid type is rejected"
fi

# Test 5: importance validation - out of range
if bash "${SCRIPTS_DIR}/save.sh" --type fact --content "test" --importance 11 2>/dev/null; then
    fail "importance 11 should be rejected"
else
    pass "importance 11 is rejected"
fi

# Test 6: missing content is rejected
if bash "${SCRIPTS_DIR}/save.sh" --type fact 2>/dev/null; then
    fail "missing --content should be rejected"
else
    pass "missing --content is rejected"
fi

# Test 7: SQL injection in content is safe
bash "${SCRIPTS_DIR}/save.sh" \
  --type fact \
  --content "it's a test'); DROP TABLE memories;--" \
  > /dev/null
count=$(sqlite3 "${HIVE_DB}" "SELECT COUNT(*) FROM memories;")
[[ "${count}" -ge 5 ]] && pass "SQL injection in content is safe" || fail "memories table was dropped!"

# Test 8: FTS index is populated via trigger
result=$(sqlite3 "${HIVE_DB}" "SELECT COUNT(*) FROM memories_fts;")
[[ "${result}" -ge 5 ]] && pass "FTS triggers populated index" || fail "FTS index empty (count=${result})"

echo "=== test_save.sh DONE ==="
