---
name: hive
description: Long-term memory and multi-agent orchestration for Claude Code. Provides persistent SQLite-backed memory across all projects and sessions, plus coordinated Planner/Coder/Debugger/Reviewer agents. Use when the user invokes /hive, /hive-memory, /hive-status, or /hive-compress.
version: 1.0.0
---

# Hive Memory & Orchestration System

Hive provides two capabilities:

1. **Persistent memory** — SQLite FTS5 database at `~/.hive/memory.db` storing facts, decisions, patterns, errors, and preferences across all projects and sessions.

2. **Multi-agent orchestration** — Planner, Coder, Debugger, and Reviewer agents coordinated by an orchestrator that loads relevant memories before dispatch and saves learnings after.

## Commands

| Command | Description |
|---------|-------------|
| `/hive <task>` | Run a task with full memory + multi-agent coordination |
| `/hive-memory [search\|delete\|list]` | Browse and manage stored memories |
| `/hive-status` | DB stats, session history, memory counts |
| `/hive-compress` | Compress old low-importance memories via haiku |

## Memory Operations

All memory operations use shell scripts in `${CLAUDE_PLUGIN_ROOT}/scripts/`. Never write SQL directly — always go through the scripts.

- **recall.sh** — FTS5 search, returns ranked markdown output, updates access stats
- **save.sh** — Insert memory with type, content, tags, importance
- **compress.sh** — Batch compress old memories via claude-haiku
- **init.sh** — Idempotent DB initialization (called automatically by /hive)
- **status.sh** — Print DB stats

See `references/memory-schema.md` for type definitions and importance guidelines.

## Agent Routing

Before launching any agents, read `references/routing-guide.md`. Launch only agents whose output you will use.

## Output Synthesis

All `/hive` runs must end with the synthesis block defined in `references/output-format.md`.
