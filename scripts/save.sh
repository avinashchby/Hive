#!/usr/bin/env bash
# save.sh — Insert a memory into the Hive DB.
# Usage: save.sh --type TYPE --content "..." [--project P] [--tags "a b c"] [--importance N]
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/db.sh
source "${SCRIPT_DIR}/lib/db.sh"
# shellcheck source=lib/validate.sh
source "${SCRIPT_DIR}/lib/validate.sh"

TYPE=""
CONTENT=""
PROJECT=""
TAGS=""
IMPORTANCE=5

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type)       TYPE="$2";       shift 2 ;;
            --content)    CONTENT="$2";    shift 2 ;;
            --project)    PROJECT="$2";    shift 2 ;;
            --tags)       TAGS="$2";       shift 2 ;;
            --importance) IMPORTANCE="$2"; shift 2 ;;
            *) echo "Unknown argument: $1" >&2; exit 1 ;;
        esac
    done
}

main() {
    parse_args "$@"
    require_db
    validate_type "${TYPE}"
    validate_importance "${IMPORTANCE}"

    if [[ -z "${CONTENT}" ]]; then
        echo "ERROR: --content is required" >&2
        exit 1
    fi

    local esc_content esc_project esc_tags
    esc_content="$(escape_sql "${CONTENT}")"
    esc_project="$(escape_sql "${PROJECT}")"
    esc_tags="$(escape_sql "${TAGS}")"

    local id
    id=$(db "INSERT INTO memories(type, content, project, tags, importance)
             VALUES('${TYPE}','${esc_content}','${esc_project}','${esc_tags}',${IMPORTANCE})
             RETURNING id;")

    echo "Memory saved: id=${id} type=${TYPE} importance=${IMPORTANCE}"
}

main "$@"
