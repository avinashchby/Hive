# Hive Output Format

Every `/hive` run ends with a structured synthesis block. Keep the entire block under 200 words.

## Template

```
## Hive Summary

**Task:** <original task, truncated to 100 chars>
**Agents used:** Planner, Coder, Reviewer  ← list only what ran
**Memories loaded:** N  ← count from recall.sh

### Plan
- Step 1: ...
- Step 2: ...
(or "N/A — single-step task")

### Implementation Notes
- Files changed: path/to/a.ext (created), path/to/b.ext (modified)
- Key decision: [most important non-obvious choice made]

### Review Findings
[Paste Reviewer output here, or "Passed" if no issues, or "Skipped"]

### Memories Saved
- [type] "content preview..." (importance N)
- [type] "content preview..." (importance N)
(or "None — no significant learnings this session")
```

## Rules

1. Always present this block at the end of every `/hive` run, even if agents were skipped
2. "Memories Saved" must reflect actual `save.sh` calls made — do not list intentions
3. If Reviewer blocked Coder output, note that in Review Findings with the specific objection
4. Do not include agent prompts or intermediate reasoning in the final synthesis
5. This block is not a summary of what you did — it is a record for future sessions to reference
