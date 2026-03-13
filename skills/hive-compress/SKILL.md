---
name: hive-compress
description: Compress old low-importance Hive memories using claude-haiku. Reduces DB size while preserving key facts.
---

# Hive Memory Compression

Show current candidates:
```bash
sqlite3 "${HIVE_DB:-${HOME}/.hive/memory.db}" \
  "SELECT COUNT(*) || ' memories eligible (importance <= 3, never accessed, older than 30 days)' \
   FROM memories \
   WHERE importance <= 3 AND access_count = 0 \
     AND created_at < strftime('%s','now') - 30*86400;" 2>/dev/null || echo "DB not initialized"
```

Ask the user to confirm before proceeding. If confirmed:

```bash
bash "${CLAUDE_SKILL_DIR}/../../scripts/compress.sh"
```

Then show updated memory count:
```bash
sqlite3 "${HIVE_DB:-${HOME}/.hive/memory.db}" \
  "SELECT COUNT(*) || ' memories remaining' FROM memories;" 2>/dev/null
```
