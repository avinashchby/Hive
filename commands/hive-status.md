---
description: Show Hive DB stats, memory counts by type, recent sessions, and compression history.
allowed-tools: Bash
---

# Hive Status

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"
```

Present the output above as a formatted report.

Add observations about memory health:
- If total memories > 500: strongly recommend running `/hive-compress`
- If total memories > 200: suggest running `/hive-compress` soon
- If no sessions logged: note that `/hive <task>` has not been used yet
- If last session was > 7 days ago: note how long since last use

Offer next actions:
- `/hive-memory list` — browse all memories
- `/hive-memory search <query>` — find specific memories
- `/hive-compress` — reduce DB size by compressing old entries
