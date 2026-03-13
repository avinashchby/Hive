# Hive — Contributor Conventions

## What is Hive?

Hive is an open-source Claude Code plugin that provides:
1. **Long-term cross-project memory** — SQLite FTS5 database persisting facts, decisions, patterns, errors, and preferences across all Claude Code sessions.
2. **Multi-agent orchestration** — Planner, Coder, Debugger, and Reviewer agents running in parallel, coordinated by an orchestrator that injects memory context before dispatch.

Install location: `~/.claude/hive/` (via `claude --plugin-dir ~/.claude/hive`)
DB location: `~/.hive/memory.db` (override with `$HIVE_DB`)

## Stack

- Shell: bash 3.2+ (macOS built-in — no Homebrew bash required)
- DB: SQLite 3.x with FTS5 (built into macOS since 10.6)
- Claude CLI: `claude-sonnet-4-6` for agents, `claude-haiku-4-5-20251001` for memory compression
- Zero Python/Node/npm dependencies

## Directory Layout

```
Hive/
├── CLAUDE.md                        ← this file
├── README.md
├── LICENSE
├── install.sh                       ← copies to ~/.claude/plugins/local/hive/
├── .claude-plugin/plugin.json       ← plugin manifest
├── commands/
│   ├── hive.md                      ← /hive <task>  (orchestrator)
│   ├── hive-memory.md               ← /hive-memory [search|delete|list]
│   ├── hive-status.md               ← /hive-status
│   └── hive-compress.md             ← /hive-compress
├── agents/
│   ├── hive-planner.md
│   ├── hive-coder.md
│   ├── hive-debugger.md
│   └── hive-reviewer.md
├── skills/hive/
│   ├── SKILL.md
│   └── references/
│       ├── memory-schema.md
│       ├── routing-guide.md
│       └── output-format.md
├── scripts/
│   ├── init.sh
│   ├── recall.sh
│   ├── save.sh
│   ├── compress.sh
│   ├── status.sh
│   └── lib/
│       ├── db.sh
│       └── validate.sh
└── tests/
    ├── run_all.sh
    ├── test_init.sh
    ├── test_save.sh
    ├── test_recall.sh
    └── test_compress.sh
```

## Code Quality Rules

- Every script starts with: `set -euo pipefail` and `IFS=$'\n\t'`
- Max function length: 50 lines. Move helpers to `lib/` if longer.
- Max file length: 500 lines. Split scripts if needed.
- No associative arrays (`declare -A`) — bash 3.2 on macOS does not support them.
- Quote all variable expansions: `"${VAR}"` not `$VAR`
- Escape SQL through `escape_sql()` in `lib/validate.sh` — never interpolate raw user input into SQL.
- No `|| true` on anything that could silently swallow real errors; use it only for idempotent init steps.

## Commit Conventions

- `feat:` new capability (new agent, new memory type, new command)
- `fix:` bug in scripts or skill/command files
- `refactor:` restructure without behavior change
- `docs:` README, CLAUDE.md, reference files only
- `test:` changes in tests/ only
- `chore:` install.sh, plugin.json, CI config

## Testing

Every script in `scripts/` has a corresponding test in `tests/`.

Tests use a temp DB:
```bash
export HIVE_DB=$(mktemp /tmp/hive_test_XXXXX.db)
trap 'rm -f "${HIVE_DB}"' EXIT
```

Run all tests:
```bash
bash tests/run_all.sh
```

Tests must not make network calls or invoke `claude` CLI.

## Cost Discipline

- Memory ops (recall.sh, compress.sh): `claude-haiku-4-5-20251001` only
- Agent work (planner, coder, debugger, reviewer): `claude-sonnet-4-6`
- Never use opus in automated/scripted paths
- Always pass `--no-session-persistence` and `--tools ""` when calling `claude` in scripts
- Unset `CLAUDECODE` before nested `claude` calls: `(unset CLAUDECODE; claude ...)`

## Security

- Never log memory content to stdout during normal operation (content may be sensitive)
- `escape_sql()` in `lib/validate.sh` is mandatory for any user-supplied string going into SQL
- `DB_PATH` must not be user-supplied via command arguments — only via `HIVE_DB` env var
- Scripts called from `commands/` run with the user's full Claude Code permissions — do not add unnecessary tool access

## Adding a New Memory Type

1. Update the CHECK constraint in `scripts/init.sh`
2. Update `validate_type()` in `scripts/lib/validate.sh`
3. Update the memory type table in `skills/hive/references/memory-schema.md`
4. Add a test case in `tests/test_save.sh`
5. Do NOT add a type unless you have 3 concrete use cases you cannot serve with existing types

## Adding a New Agent

1. Create `agents/hive-<name>.md` with the agent definition
2. Update `skills/hive/references/routing-guide.md` with when to use it
3. Update `commands/hive.md` orchestrator with the agent's parallel prompt
4. Update `agents/` section of this CLAUDE.md
5. Add to `commands/hive-status.md` if it produces loggable output

## Key Invariants (Do Not Break)

1. The FTS5 triggers in `init.sh` must stay in sync with the base table schema — if you add a column to `memories`, update all three triggers.
2. `recall.sh` updates `access_count` and `last_accessed` on every read — this is intentional (feedback loop for importance scoring).
3. The orchestrator (`commands/hive.md`) runs `init.sh` on every invocation — this must remain idempotent.
4. Agents do not access the DB directly — only the orchestrator calls shell scripts.
