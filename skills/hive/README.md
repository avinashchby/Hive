# Hive

Multi-agent task orchestrator with long-term memory — routes to specialist agents and loads relevant context from past sessions before every run.

![License](https://img.shields.io/badge/license-MIT-blue) ![Agent Compatible](https://img.shields.io/badge/agents-Claude%20Code%20%7C%20Cursor%20%7C%20Codex%20%7C%20Gemini%20CLI%20%7C%20Copilot-green)

## What It Does

Hive gives Claude two capabilities it lacks by default: persistent cross-session memory and coordinated specialist agents. Before executing any task, the orchestrator queries a local SQLite FTS5 database to surface relevant decisions, patterns, and errors from past sessions. It then routes the task to the appropriate combination of Planner, Coder, Debugger, and Reviewer agents — launched in parallel — and synthesizes their outputs into a structured summary. Learnings from each session are written back to memory so future runs benefit from accumulated project context.

## When to Use This

- You're working on a multi-step feature that touches several files or systems and want upfront planning before any code is written.
- A specific error message or failing test needs root cause analysis, not just a guess.
- Implementation touches authentication, public APIs, or data storage and needs a security-focused review pass.
- You want Claude to remember architectural decisions, recurring patterns, and project-specific preferences across sessions and projects.
- You're doing a refactor and want plan → implement → review in one coordinated pass.
- You want a code review or security audit without writing any new code.

## Key Features

- **Five typed memories:** `fact`, `decision`, `pattern`, `error`, `preference` — each with importance scoring 1–10.
- **FTS5 full-text search** with relevance ranking: `score = (importance/10) × (1 / (1 + days_since_access)) × (1 + access_count)`.
- **Four specialist agents** (Planner, Coder, Debugger, Reviewer) launched in parallel based on a routing decision matrix.
- **Automatic memory compression** via `claude-haiku` for low-importance, stale entries — keeps the DB lean without losing signal.
- **Per-project scoping** with global fallback — memories are tagged to the current project by `basename $(pwd)`.
- **Zero dependencies** — pure bash 3.2+ and SQLite (built into macOS); no Python, Node, or npm.
- **Structured synthesis block** at the end of every run — a machine-readable record for future sessions to reference.
- **Cost-conscious model selection** — haiku for memory ops, sonnet for agent work; opus never used in automated paths.

## Quick Start

### Install (copy to your agent's skills directory)

```bash
# Claude Code
cp -r ~/Claude\ Code\ Skills/Hive/skills/hive ~/.claude/skills/

# Or symlink for auto-updates
ln -s ~/Claude\ Code\ Skills/Hive/skills/hive ~/.claude/skills/hive
```

### For other agents

```bash
# Cursor
cp -r ~/Claude\ Code\ Skills/Hive/skills/hive .cursor/skills/

# Codex CLI
cp -r ~/Claude\ Code\ Skills/Hive/skills/hive .codex/skills/

# Gemini CLI
cp -r ~/Claude\ Code\ Skills/Hive/skills/hive .gemini/skills/
```

## Usage Examples

```
/hive build a REST API for user authentication with JWT
```

```
/hive the login endpoint returns 500 when the email contains a + sign
```

```
/hive refactor the database layer to use connection pooling
```

```
/hive design the event sourcing architecture for the orders service — don't write code yet
```

```
/hive review the storage layer in src/db/ for security and correctness issues
```

## Skill Structure

```
hive/
├── SKILL.md                  (114 lines — orchestrator instructions: init, routing, parallel dispatch, synthesis, memory save)
└── references/
    ├── memory-schema.md      (52 lines — table schema, memory types, importance scale, FTS5 search tips)
    ├── routing-guide.md      (93 lines — per-agent launch/skip rules, routing matrix, conflict resolution)
    └── output-format.md      (38 lines — structured synthesis block template and output rules)
```

Total: 297 lines across 4 files.

## Part of Forge Skills

This skill is part of the [Forge Skills](../README.md) collection — 23 production-grade agent skills for modern development.

## License

MIT
