# Hive

**Long-term memory and multi-agent orchestration for Claude Code — including greenfield project bootstrapping.**

Hive is a Claude Code plugin that gives Claude three superpowers it doesn't have by default:

1. **Persistent memory** across all projects and sessions — stored locally in SQLite, never sent anywhere.
2. **Specialist agents** (Architect, Scaffolder, Planner, Coder, Debugger, Reviewer) coordinated by an orchestrator that loads relevant memories before dispatching work.
3. **Greenfield bootstrapping** — start a new project from scratch with `/hive-new`: architecture decision, scaffolded files, and seeded memory, all in one command.

---

## Why Hive?

| Problem | Hive's solution |
|---------|----------------|
| Claude forgets everything between sessions | SQLite FTS5 memory, survives restarts |
| No context when returning to a project | Session continuity — "Last session:" injected automatically |
| Starting from scratch has no workflow | `/hive-new` → Architect ADR → user approval → Scaffolder → seeded memory |
| One agent does everything mediocrely | 6 specialists: architect → scaffold → plan → code → debug → review |
| Memory systems need Chroma, LangChain, etc. | Zero dependencies: just `sqlite3` (built into macOS) |
| Existing DBs break when adding new memory types | Safe idempotent migration (`migrate.sh`) |
| Compression costs tokens over time | `claude-haiku` compresses old memories cheaply |

---

## Install

```bash
git clone https://github.com/avinashchby/Hive.git
cd Hive
bash install.sh
```

`install.sh`:
- Copies scripts to `~/.hive/scripts/`
- Copies skills to `~/.claude/skills/hive*/` (auto-discovered by Claude Code)
- Initializes the SQLite database at `~/.hive/memory.db`
- Runs any pending schema migrations automatically

Then restart Claude Code. All `/hive*` skills are available immediately — no flags needed.

**Requirements:** macOS (sqlite3 built-in) or Linux with `sqlite3` + FTS5. No Python, Node, or npm.

---

## Commands

### `/hive-new <description>`

Bootstrap a brand-new project from scratch. Give it a one-line description and Hive will:

1. Recall your past stack preferences from memory
2. Launch the **Architect** agent to produce an Architecture Decision Record (tech stack, module boundaries, key interfaces)
3. Present the ADR to you for approval — tweak anything before proceeding
4. Launch the **Scaffolder** agent to create the directory structure, build files, README, CI skeleton, and source stubs
5. Seed initial memories (`architecture` + `decision` types) for the project
6. Log the session

```
/hive-new a REST API for an e-commerce platform in Go
/hive-new a CLI tool for managing dotfiles in Rust
/hive-new a data pipeline that ingests Stripe webhooks into Postgres
```

### `/hive <task>`

The main command for ongoing work. Give it any task and Hive will:

1. Inject "Last session:" context for this project (session continuity)
2. Load relevant memories from past sessions
3. Detect if the task is greenfield → redirect to `/hive-new` if so
4. Route to appropriate specialist agents (in parallel)
5. Synthesize the results
6. Save learnings back to memory

```
/hive build a REST API for user authentication with JWT
/hive refactor the database layer to use connection pooling
/hive the login endpoint returns 500 when the email has a + sign
```

### `/hive-memory [search|delete|list]`

Browse and manage your memory store.

```
/hive-memory search postgres
/hive-memory list architecture
/hive-memory delete 42
```

### `/hive-status`

Show memory counts by type, recent sessions, DB size, and compression history.

### `/hive-compress`

Compress old, low-importance memories using `claude-haiku`. Run after large sessions to keep the DB lean.

---

## How Memory Works

Memories are stored in `~/.hive/memory.db` (SQLite with FTS5 full-text search).

**Six memory types:**

| Type | Example |
|------|---------|
| `fact` | "Project uses PostgreSQL 15 with pgvector" |
| `decision` | "Chose Redis over Memcached because TTL semantics are simpler" |
| `pattern` | "All API handlers return `(Response, StatusCode)`, never panic" |
| `error` | "SQLite 'database is locked' when WAL mode is off" |
| `preference` | "Prefers table-driven tests, dislikes mocks" |
| `architecture` | "Chose hexagonal architecture to isolate DB from domain logic" |

**Ranking formula:**
```
score = (importance/10) × (1 / (1 + days_since_access)) × (1 + access_count)
```

High importance + recent + frequently used = top of recall results.

**Session continuity:** Every `/hive` invocation queries `project_context` for the current project and prepends a "Last session:" block — what was worked on, which agents ran, when. No more re-explaining context at the start of every session.

**Compression:** Memories with importance ≤ 3, never accessed, older than 30 days are summarized by `claude-haiku` into a single `pattern` entry. Tune with env vars:
```bash
export HIVE_COMPRESS_AGE=30               # days threshold
export HIVE_COMPRESS_MAX_IMPORTANCE=3     # max importance to compress
export HIVE_COMPRESS_BATCH=20             # memories per batch
```

---

## How Agents Work

Hive has six specialist agents:

| Agent | Role | When used |
|-------|------|-----------|
| **Architect** | Tech stack choice, module boundaries, ADR | `/hive-new`, system design tasks |
| **Scaffolder** | Directory structure, boilerplate, CI skeleton | `/hive-new`, after Architect approves ADR |
| **Planner** | Decomposes task → steps, files, risks | Multi-step tasks, architecture |
| **Coder** | Implements code + tests | Any implementation work |
| **Debugger** | Root cause analysis + minimal fix | Error messages, test failures |
| **Reviewer** | Security, correctness, convention | Code touching APIs, auth, storage |

The orchestrator decides which agents to launch, runs them **in parallel where possible** (Architect → Scaffolder is sequential by design), then synthesizes the results.

---

## Configuration

| Env var | Default | Description |
|---------|---------|-------------|
| `HIVE_DB` | `~/.hive/memory.db` | Override DB location |
| `HIVE_HOME` | `~/.hive` | Override install directory |
| `HIVE_COMPRESS_AGE` | `30` | Days before compression eligibility |
| `HIVE_COMPRESS_MAX_IMPORTANCE` | `3` | Max importance level to compress |
| `HIVE_COMPRESS_BATCH` | `20` | Memories per compression batch |

---

## Running Tests

```bash
bash tests/run_all.sh
```

5 suites, 43 tests. Uses isolated temp DBs, no network calls, no `claude` CLI invocations.

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
