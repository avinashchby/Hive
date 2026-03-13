# Hive

**Long-term memory and multi-agent orchestration for Claude Code.**

Hive is a Claude Code plugin that gives Claude two superpowers it doesn't have by default:

1. **Persistent memory** across all projects and sessions — stored locally in SQLite, never sent anywhere.
2. **Specialist agents** (Planner, Coder, Debugger, Reviewer) running in parallel, coordinated by an orchestrator that loads relevant memories before dispatching work.

---

## Why Hive?

| Problem | Hive's solution |
|---------|----------------|
| Claude forgets everything between sessions | SQLite FTS5 memory, survives restarts |
| One agent does everything mediocrely | Specialists: plan → code → debug → review |
| Memory systems need Chroma, LangChain, etc. | Zero dependencies: just `sqlite3` (built into macOS) |
| Compression costs tokens over time | `claude-haiku` compresses old memories cheaply |
| Memory leaks across unrelated projects | Per-project scoping + global fallback |

---

## Install

```bash
git clone https://github.com/avinashcheby/Hive-Claude-Code-Skill
cd Hive-Claude-Code-Skill
bash install.sh
```

`install.sh` copies Hive to `~/.claude/hive/` and initializes the SQLite database.

Then restart Claude Code. The `/hive` commands will be available automatically — no flags needed.

**Requirements:** macOS (sqlite3 built-in) or Linux with `sqlite3` + FTS5.

---

## Commands

### `/hive <task>`

The main command. Give it any task and Hive will:
1. Load relevant memories from past sessions
2. Route to appropriate specialist agents (in parallel)
3. Synthesize the results
4. Save learnings back to memory

```
/hive build a REST API for user authentication with JWT
/hive refactor the database layer to use connection pooling
/hive the login endpoint returns 500 when the email has a + sign
```

### `/hive-memory [search|delete|list]`

Browse and manage your memory store.

```
/hive-memory search postgres
/hive-memory list error
/hive-memory delete 42
```

### `/hive-status`

Show memory counts, recent sessions, DB size, and compression history.

### `/hive-compress`

Compress old, low-importance memories using `claude-haiku`. Run this after large sessions to keep the DB lean.

---

## How Memory Works

Memories are stored in `~/.hive/memory.db` (SQLite with FTS5 full-text search).

**Five memory types:**

| Type | Example |
|------|---------|
| `fact` | "Project uses PostgreSQL 15 with pgvector" |
| `decision` | "Chose Redis over Memcached because TTL semantics are simpler" |
| `pattern` | "All API handlers return `(Response, StatusCode)`, never panic" |
| `error` | "SQLite 'database is locked' when WAL mode is off" |
| `preference` | "Prefers table-driven tests, dislikes mocks" |

**Ranking formula:**
```
score = (importance/10) × (1 / (1 + days_since_access)) × (1 + access_count)
```

High importance + recent + frequently used = top of recall results.

**Compression:** Memories with importance ≤ 3, never accessed, older than 30 days are summarized by `claude-haiku` into a single `pattern` entry. Tune with env vars:
```bash
export HIVE_COMPRESS_AGE=30               # days threshold
export HIVE_COMPRESS_MAX_IMPORTANCE=3     # max importance to compress
export HIVE_COMPRESS_BATCH=20             # memories per batch
```

---

## How Agents Work

Hive has four specialist agents:

| Agent | Role | When used |
|-------|------|-----------|
| **Planner** | Decomposes task → steps, files, risks | Multi-step tasks, architecture |
| **Coder** | Implements code + tests | Any implementation work |
| **Debugger** | Root cause analysis + minimal fix | Error messages, test failures |
| **Reviewer** | Security, correctness, convention | Code touching APIs, auth, storage |

The orchestrator (`/hive`) decides which agents to launch based on the task, launches them **in parallel**, then synthesizes the results. It never launches agents whose output it won't use.

---

## Configuration

| Env var | Default | Description |
|---------|---------|-------------|
| `HIVE_DB` | `~/.hive/memory.db` | Override DB location |
| `HIVE_HOME` | `~/.hive` | Override DB directory |
| `HIVE_COMPRESS_AGE` | `30` | Days before compression eligibility |
| `HIVE_COMPRESS_MAX_IMPORTANCE` | `3` | Max importance level to compress |
| `HIVE_COMPRESS_BATCH` | `20` | Memories per compression batch |

---

## Running Tests

```bash
bash tests/run_all.sh
```

Tests use isolated temp DBs and do not make network calls.

---

## Contributing

See [CLAUDE.md](CLAUDE.md) for contributor conventions.

Key rules:
- No Python/Node dependencies — bash + sqlite3 only
- Bash 3.2 compatible (macOS built-in)
- `set -euo pipefail` on every script
- Max 50 lines per function, 500 lines per file
- Every script in `scripts/` gets a test in `tests/`

---

## License

MIT
