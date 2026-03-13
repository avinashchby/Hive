---
name: hive-memory
description: View, search, and delete Hive long-term memories. Usage: /hive-memory search <query> | delete <id> | list [type]
argument-hint: [search <query> | delete <id> | list [type]]
---

# Hive Memory Manager

**Action:** $ARGUMENTS

Ensure DB exists:
```bash
bash "${CLAUDE_SKILL_DIR}/../../scripts/init.sh" 2>/dev/null || true
```

## Routing

**If action starts with `search`:**
```bash
bash "${CLAUDE_SKILL_DIR}/../../scripts/recall.sh" "${ARGUMENTS#search }" --limit 20
```
After showing results, offer to delete by ID or refine the search.

**If action starts with `delete`:**
Confirm with the user first, then:
```bash
sqlite3 "${HIVE_DB:-${HOME}/.hive/memory.db}" \
  "DELETE FROM memories WHERE id = ${ARGUMENTS#delete }; SELECT changes() || ' row(s) deleted';"
```

**If action is `list`, `list <type>`, or empty:**
```bash
sqlite3 "${HIVE_DB:-${HOME}/.hive/memory.db}" \
  "SELECT id, type, importance, SUBSTR(content,1,80) FROM memories ORDER BY last_accessed DESC LIMIT 30;"
```
Format as a table: ID | Type | Importance | Preview

## Always Show at the End

```bash
sqlite3 "${HIVE_DB:-${HOME}/.hive/memory.db}" \
  "SELECT COUNT(*) || ' total memories' FROM memories;" 2>/dev/null || echo "0 total memories"
```
