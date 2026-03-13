---
description: Compress old low-importance Hive memories using claude-haiku. Reduces DB size while preserving key facts.
allowed-tools: Bash
---

# Hive Memory Compression

Compression uses `claude-haiku-4-5-20251001` to summarize batches of low-importance, unaccessed memories older than 30 days into single `pattern` entries.

## Current Candidates

```bash
sqlite3 "${HIVE_DB:-${HOME}/.hive/memory.db}" \
  "SELECT COUNT(*) || ' memories eligible (importance <= 3, never accessed, older than 30 days)' \
   FROM memories \
   WHERE importance    <= 3 \
     AND access_count   = 0 \
     AND created_at    < strftime('%s','now') - 30*86400;" \
  2>/dev/null || echo "DB not initialized"
```

**Tunable environment variables:**
- `HIVE_COMPRESS_AGE` — days threshold (default: 30)
- `HIVE_COMPRESS_MAX_IMPORTANCE` — max importance to compress (default: 3)
- `HIVE_COMPRESS_BATCH` — memories per batch (default: 20)

## Confirm Before Running

Ask the user: "Proceed with compression? This will permanently merge the above memories into summarized entries."

If the user confirms, run:

```bash
bash "${HIVE_HOME:-${HOME}/.hive}/scripts/compress.sh"
```

Report the result. Then show updated memory count:

```bash
sqlite3 "${HIVE_DB:-${HOME}/.hive/memory.db}" \
  "SELECT COUNT(*) || ' memories remaining after compression' FROM memories;" \
  2>/dev/null
```
