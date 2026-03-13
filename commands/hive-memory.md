---
description: View, search, and delete Hive memories. Usage: /hive-memory search <query> | delete <id> | list [type]
argument-hint: [search <query> | delete <id> | list [type]]
allowed-tools: Bash
---

# Hive Memory Manager

**Action:** $ARGUMENTS

Ensure DB exists before proceeding:
```bash
bash "${HIVE_HOME:-${HOME}/.hive}/scripts/init.sh" 2>/dev/null || true
```

---

## Routing

Parse `$ARGUMENTS` and take the appropriate action:

### If action is `search <query>` or starts with `search`:

Run recall and present formatted results:
```bash
bash "${HIVE_HOME:-${HOME}/.hive}/scripts/recall.sh" "${ARGUMENTS#search }" --limit 20
```

After showing results, offer:
- "Delete a memory by ID? Enter: `/hive-memory delete <id>`"
- "Narrow search? Try: `/hive-memory search <refined query>`"

### If action is `delete <id>`:

Confirm with the user before deleting:
> "Delete memory ID [ID]? This cannot be undone."

If confirmed:
```bash
ID="${ARGUMENTS#delete }"
sqlite3 "${HIVE_DB:-${HOME}/.hive/memory.db}" \
  "DELETE FROM memories WHERE id = ${ID}; SELECT changes() || ' row(s) deleted';"
```

### If action is `list`, `list <type>`, or is empty:

Show recent memories, optionally filtered by type:
```bash
TYPE_FILTER="${ARGUMENTS#list}"
TYPE_FILTER="${TYPE_FILTER## }"  # trim leading space

if [[ -n "${TYPE_FILTER}" ]]; then
  sqlite3 "${HIVE_DB:-${HOME}/.hive/memory.db}" \
    "SELECT id, type, importance, SUBSTR(content,1,80) FROM memories WHERE type='${TYPE_FILTER}' ORDER BY last_accessed DESC LIMIT 30;"
else
  sqlite3 "${HIVE_DB:-${HOME}/.hive/memory.db}" \
    "SELECT id, type, importance, SUBSTR(content,1,80) FROM memories ORDER BY last_accessed DESC LIMIT 30;"
fi
```

Format as a table with columns: ID | Type | Importance | Preview

---

## Always Show at the End

```bash
sqlite3 "${HIVE_DB:-${HOME}/.hive/memory.db}" \
  "SELECT COUNT(*) || ' total memories (' || SUM(CASE WHEN type='fact' THEN 1 ELSE 0 END) || ' facts, ' || SUM(CASE WHEN type='decision' THEN 1 ELSE 0 END) || ' decisions, ' || SUM(CASE WHEN type='pattern' THEN 1 ELSE 0 END) || ' patterns, ' || SUM(CASE WHEN type='error' THEN 1 ELSE 0 END) || ' errors, ' || SUM(CASE WHEN type='preference' THEN 1 ELSE 0 END) || ' preferences)' FROM memories;" \
  2>/dev/null || echo "0 total memories"
```
