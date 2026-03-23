#!/usr/bin/env bash
# test_seed.sh — Tests for scripts/seed.sh and recall.sh --last-session
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

echo "=== test_seed.sh ==="

# Test 1: missing --project exits with error
if bash "${SCRIPTS_DIR}/seed.sh" --stack "Go + Postgres" 2>/dev/null; then
    fail "missing --project should exit with error"
else
    pass "missing --project exits with error"
fi

# Test 2: missing --stack exits with error
if bash "${SCRIPTS_DIR}/seed.sh" --project "myapp" 2>/dev/null; then
    fail "missing --stack should exit with error"
else
    pass "missing --stack exits with error"
fi

# Test 3: basic seed creates 2 memories and outputs confirmation
output=$(bash "${SCRIPTS_DIR}/seed.sh" --project "testapp" --stack "Go + Postgres")
[[ "${output}" =~ "Seeded 2 memories for project: testapp" ]] \
    && pass "basic seed reports 2 memories" \
    || fail "unexpected output: ${output}"

# Test 4: architecture memory was saved
count=$(sqlite3 "${HIVE_DB}" "SELECT COUNT(*) FROM memories WHERE type='architecture' AND project='testapp';")
[[ "${count}" -eq 1 ]] && pass "architecture memory saved" || fail "architecture memory missing (count=${count})"

# Test 5: decision memory was saved
count=$(sqlite3 "${HIVE_DB}" "SELECT COUNT(*) FROM memories WHERE type='decision' AND project='testapp';")
[[ "${count}" -eq 1 ]] && pass "decision memory saved" || fail "decision memory missing (count=${count})"

# Test 6: architecture memory content includes stack
content=$(sqlite3 "${HIVE_DB}" "SELECT content FROM memories WHERE type='architecture' AND project='testapp';")
[[ "${content}" =~ "Go + Postgres" ]] \
    && pass "architecture memory contains stack" \
    || fail "architecture memory missing stack: ${content}"

# Test 7: --description is appended to architecture memory
bash "${SCRIPTS_DIR}/seed.sh" \
    --project "descapp" \
    --stack "Python + FastAPI" \
    --description "A REST API for widgets." \
    > /dev/null
content=$(sqlite3 "${HIVE_DB}" "SELECT content FROM memories WHERE type='architecture' AND project='descapp';")
[[ "${content}" =~ "A REST API for widgets." ]] \
    && pass "--description appended to architecture memory" \
    || fail "description not in architecture memory: ${content}"

# Test 8: --patterns seeds correct number of pattern memories
output=$(bash "${SCRIPTS_DIR}/seed.sh" \
    --project "patterned" \
    --stack "Rust + tokio" \
    --patterns "Use anyhow for errors,All handlers are async,No unwrap in production")
[[ "${output}" =~ "Seeded 5 memories for project: patterned" ]] \
    && pass "--patterns seeds 3 pattern memories (total=5)" \
    || fail "unexpected output: ${output}"

# Test 9: pattern rows exist in DB
count=$(sqlite3 "${HIVE_DB}" "SELECT COUNT(*) FROM memories WHERE type='pattern' AND project='patterned';")
[[ "${count}" -eq 3 ]] && pass "3 pattern memories saved" || fail "expected 3 pattern memories, got ${count}"

# Test 10: project_context row upserted after seed
row=$(sqlite3 "${HIVE_DB}" "SELECT last_task FROM project_context WHERE project='testapp';")
[[ "${row}" == "Initial scaffold" ]] \
    && pass "project_context upserted with last_task" \
    || fail "project_context last_task wrong: ${row}"

# Test 11: project_context last_agents set correctly
row=$(sqlite3 "${HIVE_DB}" "SELECT last_agents FROM project_context WHERE project='testapp';")
[[ "${row}" == "architect,scaffolder" ]] \
    && pass "project_context last_agents set correctly" \
    || fail "project_context last_agents wrong: ${row}"

# Test 12: SQL injection in project name is safe
bash "${SCRIPTS_DIR}/seed.sh" \
    --project "evil'); DROP TABLE memories;--" \
    --stack "evil stack" \
    > /dev/null
count=$(sqlite3 "${HIVE_DB}" "SELECT COUNT(*) FROM memories;")
[[ "${count}" -ge 7 ]] && pass "SQL injection in project name is safe" || fail "memories table was dropped!"

# Test 13: --last-session outputs last session info
output=$(bash "${SCRIPTS_DIR}/recall.sh" --project "testapp" --last-session)
[[ "${output}" =~ "## Last Session: testapp" ]] \
    && pass "--last-session outputs last session header" \
    || fail "--last-session missing header: ${output}"
[[ "${output}" =~ "Initial scaffold" ]] \
    && pass "--last-session shows last_task" \
    || fail "--last-session missing task: ${output}"
[[ "${output}" =~ "architect,scaffolder" ]] \
    && pass "--last-session shows agents" \
    || fail "--last-session missing agents: ${output}"

# Test 14: --last-session with unknown project is silent
output=$(bash "${SCRIPTS_DIR}/recall.sh" --project "nonexistent_proj_xyz" --last-session)
[[ -z "${output}" ]] \
    && pass "--last-session is silent for unknown project" \
    || fail "--last-session should be silent for unknown project, got: ${output}"

# Test 15: --last-session without --project exits with error
if bash "${SCRIPTS_DIR}/recall.sh" --last-session 2>/dev/null; then
    fail "--last-session without --project should exit with error"
else
    pass "--last-session without --project exits with error"
fi

# Test 16: --last-session skips FTS (no query required)
# If query were required, this would fail; it should succeed
output=$(bash "${SCRIPTS_DIR}/recall.sh" --project "testapp" --last-session)
[[ "${output}" =~ "Last Session" ]] \
    && pass "--last-session works without a query string" \
    || fail "--last-session without query failed: ${output}"

echo "=== test_seed.sh DONE ==="
