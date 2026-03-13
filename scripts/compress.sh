#!/usr/bin/env bash
# compress.sh — Summarize old low-importance memories using claude-haiku.
# Candidates: importance <= HIVE_COMPRESS_MAX_IMPORTANCE, access_count = 0,
#             older than HIVE_COMPRESS_AGE days.
# Batches candidates, compresses to a single 'pattern' memory, deletes originals.
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/db.sh
source "${SCRIPT_DIR}/lib/db.sh"
# shellcheck source=lib/validate.sh
source "${SCRIPT_DIR}/lib/validate.sh"

AGE_DAYS="${HIVE_COMPRESS_AGE:-30}"
MAX_IMPORTANCE="${HIVE_COMPRESS_MAX_IMPORTANCE:-3}"
BATCH_SIZE="${HIVE_COMPRESS_BATCH:-20}"

fetch_candidates() {
    local cutoff
    cutoff=$(( $(date +%s) - AGE_DAYS * 86400 ))
    db "SELECT id, type, content
        FROM memories
        WHERE importance   <= ${MAX_IMPORTANCE}
          AND access_count  = 0
          AND created_at   <  ${cutoff}
        ORDER BY importance ASC, created_at ASC
        LIMIT ${BATCH_SIZE};"
}

build_prompt() {
    local prompt
    prompt="You are a memory compressor for a developer assistant. "
    prompt+="Summarize these memories into ONE concise paragraph (max 200 words) "
    prompt+="preserving all unique facts. Output ONLY the summary text, no preamble.\n\nMemories:\n"

    while IFS='|' read -r id type content; do
        prompt+="[${type}] ${content}\n"
    done <<< "$1"

    printf "%s" "${prompt}"
}

compress_batch() {
    local candidates
    candidates=$(fetch_candidates)

    if [[ -z "${candidates}" ]]; then
        echo "No memories eligible for compression (age > ${AGE_DAYS}d, importance <= ${MAX_IMPORTANCE}, not accessed)."
        return 0
    fi

    local count
    count=$(echo "${candidates}" | wc -l | tr -d ' ')
    echo "Compressing ${count} memories..."

    # Extract IDs as comma-separated list for DELETE
    local ids
    ids=$(echo "${candidates}" | cut -d'|' -f1 | tr '\n' ',' | sed 's/,$//')

    # Call haiku for compression (nested claude call — unset CLAUDECODE to allow nesting)
    local summary
    summary=$(build_prompt "${candidates}" | \
        (unset CLAUDECODE; claude \
            --model claude-haiku-4-5-20251001 \
            --print \
            --no-session-persistence \
            --tools '' \
            2>/dev/null) || true)

    if [[ -z "${summary}" ]]; then
        echo "ERROR: haiku returned empty summary. Aborting compression." >&2
        exit 1
    fi

    local esc_summary
    esc_summary="$(escape_sql "${summary}")"

    # Save summary as new pattern memory
    local new_id
    new_id=$(db "INSERT INTO memories(type, content, project, tags, importance)
                  VALUES('pattern','${esc_summary}','','compressed',5)
                  RETURNING id;")

    # Delete original candidates
    db "DELETE FROM memories WHERE id IN (${ids});"

    # Log compression run
    db "INSERT INTO compress_log(memories_in, memories_out)
        VALUES(${count}, 1);"

    echo "Done: compressed ${count} memories → 1 (new id=${new_id})"
}

main() {
    require_db
    compress_batch
}

main "$@"
