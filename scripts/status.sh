#!/usr/bin/env bash
# status.sh — Print DB stats for /hive-status command.
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/db.sh
source "${SCRIPT_DIR}/lib/db.sh"
# shellcheck source=lib/validate.sh
source "${SCRIPT_DIR}/lib/validate.sh"

main() {
    require_db

    local db_size
    db_size=$(du -sh "${DB_PATH}" 2>/dev/null | cut -f1 || echo "unknown")

    echo "## Hive Memory Status"
    echo ""
    echo "**Database:** \`${DB_PATH}\`"
    echo "**Size:** ${db_size}"
    echo ""

    echo "### Memories by Type"
    db "SELECT '- **' || type || '**: ' || COUNT(*)
        FROM memories GROUP BY type ORDER BY type;"
    echo ""
    echo "**Total:** $(db "SELECT COUNT(*) FROM memories;") memories"
    echo ""

    echo "### Top 5 Most Accessed"
    db "SELECT '- [' || type || '] ' || SUBSTR(content,1,70)
            || CASE WHEN LENGTH(content) > 70 THEN '...' ELSE '' END
            || ' (' || access_count || ' accesses)'
        FROM memories
        ORDER BY access_count DESC
        LIMIT 5;" || echo "_none_"
    echo ""

    echo "### Recent Sessions (last 5)"
    db "SELECT '- ' || DATETIME(started_at,'unixepoch','localtime')
            || ': ' || SUBSTR(task,1,60)
            || CASE WHEN LENGTH(task) > 60 THEN '...' ELSE '' END
        FROM sessions
        ORDER BY started_at DESC
        LIMIT 5;" || echo "_none_"
    echo ""

    echo "### Compression History"
    db "SELECT COALESCE(COUNT(*),0) || ' run(s), '
            || COALESCE(SUM(memories_in),0) || ' → '
            || COALESCE(SUM(memories_out),0) || ' memories'
        FROM compress_log;"

    # Nudge if memory count is high
    local total
    total=$(db "SELECT COUNT(*) FROM memories;")
    if (( total > 200 )); then
        echo ""
        echo "> **Tip:** ${total} memories is getting large. Run \`/hive-compress\` to compress old entries."
    fi
}

main "$@"
