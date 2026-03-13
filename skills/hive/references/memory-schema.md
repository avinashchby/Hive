# Memory Schema Reference

## Table: `memories`

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | Auto-increment |
| `type` | TEXT | One of: `fact`, `decision`, `pattern`, `error`, `preference` |
| `content` | TEXT | The memory content (full text, FTS5 indexed) |
| `project` | TEXT | Project name, e.g. `basename $(pwd)`. Empty = global |
| `tags` | TEXT | Space-separated tokens, also FTS5 indexed |
| `importance` | INTEGER 1–10 | See scale below |
| `access_count` | INTEGER | Incremented on every recall.sh read |
| `created_at` | INTEGER | Unix timestamp |
| `last_accessed` | INTEGER | Unix timestamp, updated on every recall.sh read |

## Memory Types

| Type | When to Use | Example |
|------|-------------|---------|
| `fact` | Concrete, verifiable truths about a project | "Project uses PostgreSQL 15 with pgvector extension" |
| `decision` | Architectural or technical choices with rationale | "Chose Redis over Memcached because TTL semantics are simpler for session expiry" |
| `pattern` | Recurring code patterns worth replicating | "All API handlers return `(Response, StatusCode)`, never panic on user input" |
| `error` | Failure modes that have been seen and resolved | "sqlite3 'database is locked' when two writers use WAL=OFF; fix: enable WAL mode" |
| `preference` | User preferences about style, workflow, tooling | "Prefers table-driven tests; dislikes mocks except at system boundaries" |

## Importance Scale

| Score | Meaning | Compression behavior |
|-------|---------|---------------------|
| 9–10 | **Critical** — security flaw, data-loss risk, must-remember decision | Never compressed |
| 7–8 | **High** — project architecture, language/framework choice | Never compressed |
| 5–6 | **Normal** — common patterns, standard preferences | Compressed after 90 days if never accessed |
| 3–4 | **Low** — minor observations, stylistic notes | Compressed after 30 days if never accessed |
| 1–2 | **Trivial** — obvious facts, one-off notes | Compressed after 30 days if never accessed |

## Ranking Formula (used by recall.sh)

```
score = (importance / 10) × (1 / (1 + days_since_last_access)) × (1 + access_count)
```

- High importance + recent access + frequent use → top of results
- Low importance + stale + never accessed → bottom, eligible for compression

## FTS5 Search Tips

- Use domain terms, not natural language: `"sqlite fts5"` not `"how does search work"`
- Combine terms: `"bash error handling"` matches both bash scripts and error-type memories
- Porter stemmer handles plurals/conjugations: `"implement"` matches `"implemented"`, `"implementing"`
- Phrase search: `"\"exact phrase\""` for exact matches
- Exclusion: `"sqlite NOT compression"` to exclude a term
