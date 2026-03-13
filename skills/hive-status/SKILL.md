---
name: hive-status
description: Show Hive DB stats, memory counts by type, recent sessions, and compression history.
---

# Hive Status

```bash
bash "${CLAUDE_SKILL_DIR}/../../scripts/status.sh"
```

Present the output as a formatted report. Add health observations:
- If total > 500 memories: strongly recommend `/hive-compress`
- If total > 200: suggest `/hive-compress` soon
- If no sessions logged: note `/hive <task>` hasn't been used yet
