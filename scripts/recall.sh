#!/usr/bin/env bash
# recall.sh — Search memories using FTS5. Outputs markdown-formatted results.
# Usage: recall.sh <query> [--limit N] [--project PROJECT] [--type TYPE]
# Side effect: increments access_count and updates last_accessed for matched rows.
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/db.sh
source "${SCRIPT_DIR}/lib/db.sh"
# shellcheck source=lib/validate.sh
source "${SCRIPT_DIR}/lib/validate.sh"

QUERY=""
LIMIT=10
FILTER_PROJECT=""
FILTER_TYPE=""

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --limit)   LIMIT="$2";          shift 2 ;;
            --project) FILTER_PROJECT="$2"; shift 2 ;;
            --type)    FILTER_TYPE="$2";    shift 2 ;;
            -*)        echo "Unknown flag: $1" >&2; exit 1 ;;
            *)         QUERY="${QUERY:+${QUERY} }$1"; shift ;;
        esac
    done
}

build_fts_query() {
    # Escape single quotes in the FTS query itself
    printf "%s" "${QUERY}" | sed "s/'/''/g"
}

run_query() {
    local fts_query
    fts_query="$(build_fts_query)"

    local project_clause=""
    local type_clause=""
    if [[ -n "${FILTER_PROJECT}" ]]; then
        project_clause="AND m.project = '$(escape_sql "${FILTER_PROJECT}")'"
    fi
    if [[ -n "${FILTER_TYPE}" ]]; then
        type_clause="AND m.type = '$(escape_sql "${FILTER_TYPE}")'"
    fi

    # Update access stats for matched rows
    db "UPDATE memories
        SET access_count  = access_count + 1,
            last_accessed = strftime('%s','now')
        WHERE id IN (
            SELECT m.id
            FROM memories m
            JOIN memories_fts ON memories_fts.rowid = m.id
            WHERE memories_fts MATCH '${fts_query}'
              ${project_clause}
              ${type_clause}
            LIMIT ${LIMIT}
        );"

    # Return ranked results
    # Ranking: (importance/10) × recency_decay × (1 + access_count)
    # recency_decay = 1 / (1 + days_since_last_access)
    db "SELECT m.type, m.importance, m.project, m.tags, m.content
        FROM memories m
        JOIN memories_fts ON memories_fts.rowid = m.id
        WHERE memories_fts MATCH '${fts_query}'
          ${project_clause}
          ${type_clause}
        ORDER BY
            (m.importance * 1.0 / 10)
            * (1.0 / (1 + (strftime('%s','now') - m.last_accessed) / 86400.0))
            * (1 + m.access_count)
        DESC
        LIMIT ${LIMIT};"
}

format_output() {
    local count=0
    echo "## Relevant Memories for: ${QUERY}"
    echo ""
    while IFS='|' read -r type importance project tags content; do
        count=$((count + 1))
        echo "### [${type}] (importance: ${importance})"
        [[ -n "${project}" ]] && echo "_project: ${project}_"
        [[ -n "${tags}"    ]] && echo "_tags: ${tags}_"
        echo ""
        echo "${content}"
        echo ""
        echo "---"
        echo ""
    done
    if [[ ${count} -eq 0 ]]; then
        echo "_No memories found for query: ${QUERY}_"
    fi
}

main() {
    parse_args "$@"
    require_db

    if [[ -z "${QUERY}" ]]; then
        echo "Usage: recall.sh <query> [--limit N] [--project PROJECT] [--type TYPE]" >&2
        exit 1
    fi

    run_query | format_output
}

main "$@"
