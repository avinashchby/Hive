#!/usr/bin/env bash
# run_all.sh — Run all Hive test suites.
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0
FAIL=0
ERRORS=()

run_suite() {
    local name="$1"
    local file="${SCRIPT_DIR}/${name}"
    echo "--- Running ${name} ---"
    if bash "${file}"; then
        PASS=$((PASS + 1))
        echo "PASS: ${name}"
    else
        FAIL=$((FAIL + 1))
        ERRORS+=("${name}")
        echo "FAIL: ${name}"
    fi
    echo ""
}

run_suite "test_init.sh"
run_suite "test_save.sh"
run_suite "test_recall.sh"
run_suite "test_compress.sh"

echo "================================"
echo "Results: ${PASS} passed, ${FAIL} failed"
if [[ ${FAIL} -gt 0 ]]; then
    echo "Failed suites:"
    for e in "${ERRORS[@]}"; do
        echo "  - ${e}"
    done
    exit 1
fi
echo "All tests passed."
