# Agent Routing Guide

## Decision Matrix

### Planner

**Launch when:**
- Task has 3 or more distinct steps
- Task involves multiple files or systems
- User said "design", "architect", "plan", "how should I", "what's the best way"
- Risk of scope creep or unclear requirements
- Task requires understanding existing structure before touching it

**Skip when:**
- Single-file fix with a clear, specific target
- User explicitly provided the plan ("do X, then Y, then Z")
- Task is pure debugging (Debugger handles this)
- Task is pure code review (Reviewer handles this)

### Coder

**Launch when:**
- Any implementation work is required
- Files need to be created, modified, or deleted
- Tests need to be written

**Skip when:**
- Task is purely analytical (explain this code, review this code)
- Task is purely debugging a trace with no fix yet identified
- User explicitly said "don't write code yet"

### Debugger

**Launch when:**
- A specific error message or stack trace is provided
- A test is failing with a specific failure output
- The task description contains: "broken", "fails", "error", "exception", "bug", "crash"
- Coder returns output with unresolved error references

**Skip when:**
- No existing failure to analyze
- Task is writing new code (Coder handles this)
- Error is obviously a missing dependency (just install it)

### Reviewer

**Launch when:**
- Coder has produced output AND any of:
  - Task affects a public API or interface
  - Task touches authentication, authorization, or cryptography
  - Task touches data storage or migrations
  - Task is marked importance >= 7 in context
  - User said "review", "check", "is this safe", "does this look right"

**Skip when:**
- Prototype or exploratory work
- User explicitly said "skip review" or "just do it"
- Coder made only trivial changes (renaming, formatting, adding a comment)
- No Coder output exists to review

---

## Common Routing Patterns

| Task Type | Planner | Coder | Debugger | Reviewer |
|-----------|---------|-------|----------|----------|
| New feature, multi-file | ✓ | ✓ | — | ✓ |
| Simple bug fix | — | ✓ | ✓ | — |
| Debug-only (no fix yet) | — | — | ✓ | — |
| Architecture design | ✓ | — | — | — |
| Code review request | — | — | — | ✓ |
| Refactor | ✓ | ✓ | — | ✓ |
| New feature, single file | — | ✓ | — | ✓ |
| Security audit | — | — | — | ✓ |

---

## Conflict Resolution

### Planner vs Coder disagree on approach
1. Surface the conflict explicitly in the synthesis
2. Prefer Planner's constraint if it involves: risk, security, API compatibility
3. Prefer Coder's approach if it involves: implementation feasibility, framework behavior
4. When genuinely ambiguous, present both options to the user before proceeding

### Reviewer blocks Coder output
1. Present Reviewer's objections verbatim in the synthesis
2. Ask the user: "Reviewer flagged [N] issue(s). Address before saving? (yes/no/skip-review)"
3. Do not discard Coder's work — wait for user direction
4. If user says skip: note in memory that review was bypassed and why

### No agents selected (wrong routing)
If you routed with zero agents, re-read the task. This should almost never happen. At minimum, Coder should run if any code change is involved.
