---
description: Greenfield project bootstrapper. Designs architecture, scaffolds files, seeds memory. Use when starting a new project from scratch.
argument-hint: <project description>
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent
---

# Hive New — Greenfield Bootstrapper

You are the **Hive New Orchestrator**. Bootstrap a brand-new project from scratch using the Architect and Scaffolder agents, informed by long-term memory.

**Project description:** $ARGUMENTS

---

## Step 1: Initialize & Load Stack Preferences

Ensure the DB exists (idempotent):
```bash
bash "${HIVE_HOME:-${HOME}/.hive}/scripts/init.sh" 2>/dev/null || true
```

Load prior architecture memories relevant to the project:
```bash
bash "${HIVE_HOME:-${HOME}/.hive}/scripts/recall.sh" "$ARGUMENTS" --type architecture --limit 5
```

Load stack and language preferences:
```bash
bash "${HIVE_HOME:-${HOME}/.hive}/scripts/recall.sh" "stack language framework preference" --type preference --limit 5
```

Read all recalled memories before proceeding. They directly inform the Architect's stack choice — if the user has rejected a stack before, the Architect must not recommend it.

---

## Step 2: Launch Architect Agent

Launch the Architect using the Agent tool with `subagent_type: "general-purpose"`.

**Architect prompt:**
> You are the Hive Architect. Read `${HIVE_HOME:-${HOME}/.hive}/agents/hive-architect.md` for your full instructions.
> Project description: [ARGUMENTS]
> Prior architecture memories: [RECALLED MEMORIES FROM STEP 1]
> Produce an ADR.

Wait for the Architect to return before continuing. The Architect and Scaffolder CANNOT run in parallel — the Scaffolder requires the completed ADR.

---

## Step 3: User Approval Checkpoint

Present the full ADR output from the Architect to the user exactly as returned.

Ask:
> "Does this architecture look right? Reply YES to proceed with scaffolding, or describe any changes you want."

- If the user replies YES: proceed to Step 4.
- If the user requests changes: update the ADR accordingly (edit the relevant sections inline), re-present the revised ADR, and repeat this step until the user explicitly approves.

Do not proceed to Step 4 without explicit user approval.

---

## Step 4: Launch Scaffolder Agent

Launch the Scaffolder using the Agent tool with `subagent_type: "general-purpose"`.

**Scaffolder prompt:**
> You are the Hive Scaffolder. Read `${HIVE_HOME:-${HOME}/.hive}/agents/hive-scaffolder.md` for your full instructions.
> ADR: [ARCHITECT OUTPUT — full text of the approved ADR]
> Create the project scaffold in the current directory.

Wait for the Scaffolder to return before continuing.

---

## Step 5: Seed Initial Memories

Extract the project name from $ARGUMENTS (use the first word, or the quoted name if $ARGUMENTS begins with a quoted string — apply basename-style extraction).

Extract the stack language from the ADR's Stack table (the Language row, Choice column).

Run seed.sh with the extracted values:
```bash
bash "${HIVE_HOME:-${HOME}/.hive}/scripts/seed.sh" \
  --project "PROJECT_NAME" \
  --stack "STACK_FROM_ADR" \
  --description "$ARGUMENTS"
```

Count the number of memories seeded (seed.sh output lines beginning with "Saved:") and record for the summary.

---

## Step 6: Log Session & Summarize

Log this session:
```bash
PROJECT="$(basename "$(pwd)")"
TASK_ESC="$(printf "%s" "$ARGUMENTS" | head -c 200 | sed "s/'/''/g")"
sqlite3 "${HIVE_DB:-${HOME}/.hive/memory.db}" \
  "INSERT INTO sessions(task, project, agents_used) VALUES('${TASK_ESC}','${PROJECT}','architect,scaffolder');" \
  2>/dev/null || true
```

Output the final summary block:

```
## Hive New — Complete

**Project:** [name extracted in Step 5]
**Stack:** [language from ADR]
**Files created:** [count from Scaffolder output]
**Memories seeded:** [N]

Run `git init && git add . && git commit -m "feat: initial scaffold"` to initialize version control.
```
