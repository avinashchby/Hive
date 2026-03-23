#!/usr/bin/env bash
# seed.sh — Auto-seed initial project memories for a greenfield project.
# Usage: seed.sh --project NAME --stack STACK [--description DESC] [--patterns "p1,p2"]
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/db.sh
source "${SCRIPT_DIR}/lib/db.sh"
# shellcheck source=lib/validate.sh
source "${SCRIPT_DIR}/lib/validate.sh"

PROJECT=""
STACK=""
DESCRIPTION=""
PATTERNS=""

usage() {
    echo "Usage: seed.sh --project NAME --stack STACK [--description DESC] [--patterns \"p1,p2\"]" >&2
    exit 1
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --project)     PROJECT="$2";     shift 2 ;;
            --stack)       STACK="$2";       shift 2 ;;
            --description) DESCRIPTION="$2"; shift 2 ;;
            --patterns)    PATTERNS="$2";    shift 2 ;;
            *) echo "Unknown argument: $1" >&2; usage ;;
        esac
    done
}

save_memory() {
    local type="$1"
    local content="$2"
    local importance="$3"
    bash "${SCRIPT_DIR}/save.sh" \
        --type "${type}" \
        --content "${content}" \
        --project "${PROJECT}" \
        --importance "${importance}" \
        > /dev/null
}

save_tagged_memory() {
    local type="$1"
    local content="$2"
    local importance="$3"
    local tags="$4"
    bash "${SCRIPT_DIR}/save.sh" \
        --type "${type}" \
        --content "${content}" \
        --project "${PROJECT}" \
        --importance "${importance}" \
        --tags "${tags}" \
        > /dev/null
}

seed_patterns() {
    local count=0
    local remainder="${PATTERNS}"
    while [[ -n "${remainder}" ]]; do
        # Split on first comma
        local pattern="${remainder%%,*}"
        if [[ "${remainder}" == *,* ]]; then
            remainder="${remainder#*,}"
        else
            remainder=""
        fi
        # Trim leading/trailing whitespace
        pattern="${pattern#"${pattern%%[![:space:]]*}"}"
        pattern="${pattern%"${pattern##*[![:space:]]}"}"
        if [[ -n "${pattern}" ]]; then
            save_tagged_memory "pattern" "${pattern}" 7 "${PROJECT}"
            count=$((count + 1))
        fi
    done
    printf "%d" "${count}"
}

upsert_project_context() {
    local esc_project
    esc_project="$(escape_sql "${PROJECT}")"
    db "INSERT OR REPLACE INTO project_context(project, last_task, last_agents, updated_at)
        VALUES('${esc_project}', 'Initial scaffold', 'architect,scaffolder', strftime('%s','now'));"
}

main() {
    parse_args "$@"

    if [[ -z "${PROJECT}" ]] || [[ -z "${STACK}" ]]; then
        echo "ERROR: --project and --stack are required" >&2
        usage
    fi

    require_db

    local arch_content="Project ${PROJECT} uses ${STACK}."
    if [[ -n "${DESCRIPTION}" ]]; then
        arch_content="${arch_content} ${DESCRIPTION}"
    fi

    save_memory "architecture" "${arch_content}" 8
    save_memory "decision" "Started ${PROJECT} as a new project. Stack chosen: ${STACK}." 8

    local mem_count=2
    if [[ -n "${PATTERNS}" ]]; then
        local pattern_count
        pattern_count="$(seed_patterns)"
        mem_count=$((mem_count + pattern_count))
    fi

    upsert_project_context

    echo "Seeded ${mem_count} memories for project: ${PROJECT}"
}

main "$@"
