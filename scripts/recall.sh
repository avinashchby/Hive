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
LAST_SESSION=0

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --limit)        LIMIT="$2";          shift 2 ;;
            --project)      FILTER_PROJECT="$2"; shift 2 ;;
            --type)         FILTER_TYPE="$2";    shift 2 ;;
            --last-session) LAST_SESSION=1;      shift   ;;
            -*)             echo "Unknown flag: $1" >&2; exit 1 ;;
            *)              QUERY="${QUERY:+${QUERY} }$1"; shift ;;
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

show_last_session() {
    local project
    project="${FILTER_PROJECT}"
    if [[ -z "${project}" ]]; then
        echo "ERROR: --project is required with --last-session" >&2
        exit 1
    fi

    local esc_project
    esc_project="$(escape_sql "${project}")"
    local row
    row=$(db "SELECT last_task, last_agents, updated_at
              FROM project_context
              WHERE project = '${esc_project}'
              LIMIT 1;")

    if [[ -z "${row}" ]]; then
        return 0
    fi

    local last_task last_agents updated_at
    last_task="${row%%|*}"
    row="${row#*|}"
    last_agents="${row%%|*}"
    updated_at="${row#*|}"

    if [[ -z "${last_task}" ]]; then
        return 0
    fi

    local human_date
    human_date=$(date -r "${updated_at}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null \
                 || date -d "@${updated_at}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null \
                 || printf "%s" "${updated_at}")

    echo "## Last Session: ${project}"
    echo "**Task:** ${last_task}"
    echo "**Agents used:** ${last_agents}"
    echo "**Updated:** ${human_date}"
}

main() {
    parse_args "$@"
    require_db

    if [[ "${LAST_SESSION}" -eq 1 ]]; then
        show_last_session
        return 0
    fi

    if [[ -z "${QUERY}" ]]; then
        echo "Usage: recall.sh <query> [--limit N] [--project PROJECT] [--type TYPE] [--last-session]" >&2
        exit 1
    fi

    run_query | format_output
}

main "$@"
