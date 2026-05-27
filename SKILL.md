---
description: Interact with dblm — a natural language CLI for querying multiple databases. Use this skill when the user wants to query databases, manage connections, indexes, knowledge, modules, sessions, templates, or configure dblm.
---

# dblm Skill

You are a dblm expert assistant. dblm is a CLI tool that lets users query databases in plain English. It supports Postgres, MySQL, SQLite, MongoDB, and ClickHouse.

When the user asks you to do something with their database(s), use `dblm` commands via the shell. Always prefer natural language queries over raw SQL unless the user explicitly asks for raw SQL.

---

## 0. Workflow — ALWAYS start here

Before running any query, **discover what is actually available**. Never guess connection or database names from the conversation alone.

1. **List connections** — see what is configured:
   ```sh
   dblm connect list
   ```
2. **List indexes** — see which databases are indexed and therefore queryable:
   ```sh
   dblm index list
   ```
3. **Run the query against the bare connection name** (not a specific database):
   ```sh
   dblm query "<question>" --db <connection>
   ```

Only after the two discovery steps should you run `dblm query`. If the connection the user wants is not yet indexed, run `dblm index add <connection> --db <database>` first.

**Always favour the bare connection name** (`--db <connection>`). The engine automatically searches across every indexed database on that connection and picks the right one — you do NOT need to, and should not, narrow to `--db <connection/database>` unless the user explicitly names a database. Picking a specific database yourself risks targeting the wrong one and skips databases that might hold the answer.

---

## 1. Configuration — `dblm config`

Interactive setup of LLM provider, API key, model, and base URL. Saves to `~/.dblm/config.json`.

```sh
dblm config
```

Provider fallback order (highest to lowest):
1. `~/.dblm/config.json`
2. Env vars: `DBLM_ANTHROPIC_API_KEY`, `DBLM_LLM_PROVIDER`, `DBLM_LLM_MODEL`, `DBLM_LLM_BASE_URL`
3. Generic env vars: `ANTHROPIC_API_KEY`, `OLLAMA_API_KEY`, `OLLAMA_BASE_URL`
4. ogcode config (`~/.ogcode/config.db`) — auto-detected if ogcode is installed

---

## 2. Connections — `dblm connect`

Manage named database connections stored in `~/.dblm/config.json`.

```sh
dblm connect add <name> --driver <driver> --dsn "<dsn>"
dblm connect remove <name>
dblm connect list
dblm connect test <name>
```

Supported drivers: `postgres`, `mysql`, `sqlite`, `mongo`, `clickhouse`

DSN must NOT include a database name — databases are selected during indexing.

Examples:
```sh
dblm connect add mydb --driver postgres --dsn "postgres://user:pass@localhost:5432/"
dblm connect add local --driver sqlite --dsn "./data.db"
```

---

## 3. Schema Indexing — `dblm index`

Indexes database schemas for NLQ. Must be done before querying.

```sh
dblm index add <connection> --db <database>
dblm index remove <connection/database>
dblm index list
dblm index show <connection/database>
```

Examples:
```sh
dblm index add mydb --db orders
dblm index add mydb --db users
dblm index list
```

---

## 4. Querying — `dblm query`

Ask questions in plain English. The LLM generates and executes SQL.

```sh
dblm query "<question>" --db <connection>       # PREFERRED — searches all indexed DBs on the connection
dblm query "<question>"                          # query all connections
dblm query "<question>" --db a,b                 # multiple connections
dblm query "<question>" --db <conn/database>     # ONLY when the user explicitly names a database
dblm query "<sql>" --db <conn/database> --raw    # execute raw SQL (last resort only)
dblm query "<question>" --no-summary             # skip LLM summarization
dblm query "<question>" --json                   # output as JSON
dblm query "<question>" --context "user: alice"  # inject user context into prompt
dblm query "<question>" --module <name>          # cross-database module query
```

> **dblm is a read-only query tool.** It does not support schema mutations (CREATE, ALTER, DROP, INSERT, UPDATE, DELETE). Never attempt DDL or DML via `--raw` or otherwise — use your database client directly for those operations.

### When to use `--db <connection>` vs `--db <connection/database>`

**Default: always use the bare connection name** (`--db <connection>`). This queries all indexed databases on that connection and is the correct default for every query.

Only switch to `--db <connection/database>` when the user **explicitly names a specific database** in their request. Do not narrow to a specific database to "reduce noise" or "improve speed" on your own initiative — that is the user's decision.

| Situation | Use |
|---|---|
| Default / don't know which DB holds the data | `--db <connection>` |
| Question spans multiple DBs on the same connection | `--db <connection>` |
| No `--db` specified at all | `--db <connection>` (bare connection) |
| User explicitly names a specific database | `--db <connection/database>` |

**Never** infer or assume a specific database from prior context alone — always default to the bare connection unless the user tells you otherwise.

### Raw SQL — last resort only

**Never write raw SQL by default.** Always attempt NLQ first:

```sh
# Always try NLQ first — bare connection name
dblm query "how many orders were placed last week" --db myconn

# Only use --raw when NLQ has structurally failed (raw requires a specific database)
dblm query "SELECT id, COUNT(*) FROM events GROUP BY id HAVING COUNT(*) > 1" --db myconn/events --raw
```

**Only use `--raw` when:**
1. NLQ has failed 2+ times for the same question and the error is structural (not a poorly worded question)
2. The user explicitly asks for raw SQL
3. Debugging: the LLM-generated SQL is wrong and you need to run a hand-corrected version directly

**Never use `--raw` for** anything NLQ can express — SELECT queries, aggregations, filtering, joins, subqueries, window functions, etc.

---

## 5. Knowledge — `dblm knowledge`

Add human-readable documentation about tables/columns to improve NLQ accuracy.

```sh
dblm knowledge add <connection/database> --table <table> --content "<description>"
dblm knowledge edit <connection/database> --table <table>
dblm knowledge show <connection/database> --table <table>
dblm knowledge list <connection/database>
dblm knowledge remove <connection/database> --table <table>
dblm knowledge auto <connection/database>      # auto-generate using LLM
```

---

## 6. Modules — `dblm module`

Define named cross-database table groups for complex multi-DB queries.

```sh
dblm module create <name>
dblm module add <name> --table <conn/db.table> --alias <alias>
dblm module remove-table <name> --table <conn/db.table>
dblm module list
dblm module show <name>
dblm module delete <name>
```

Query a module:
```sh
dblm query "<question>" --module <name>
```

---

## 7. Schema Inspection — `dblm schema`

Inspect raw database schemas without querying.

```sh
dblm schema show <connection/database>
dblm schema show <connection/database> --table <table>
```

---

## 8. Templates — `dblm fassad`

Reusable parameterized query templates.

```sh
dblm fassad create <name> --db <conn/database> --template "<NLQ with {params}>"
dblm fassad run <name> --param key=value
dblm fassad list
dblm fassad show <name>
dblm fassad delete <name>
```

---

## 9. Sessions — `dblm session`

Manage conversation sessions for contextual multi-turn queries.

```sh
dblm session list
dblm session new [title]
dblm session switch <id>
dblm session show
dblm session delete <id>
```

---

## 10. History — `dblm history`

Search and review past queries.

```sh
dblm history list
dblm history search "<keyword>"
dblm history show <id>
dblm history clear
```

---

## 11. Broker / Server — `dblm server` & `dblm remote`

Run dblm as a master broker to share database access across a team over HTTP/2 + mTLS.

```sh
# Master side
dblm server start
dblm server users add <username>
dblm server acl add <username> --connection <conn>
dblm server audit

# Worker side
dblm remote add <alias> --url <master-url> --cert <cert>
dblm remote list
dblm query "<question>" --remote <alias>
```

---

## Behavior guidelines

- **Discover first.** Before any query, run `dblm connect list` and `dblm index list` to see the available connections and indexed databases. Never guess names — map the user's request to a real, indexed connection.
- dblm is a **read-only query tool** — never suggest it for mutations, DDL, or writes of any kind.
- When the user asks a database question, run `dblm query` with NLQ. Do not write raw SQL unless NLQ has structurally failed multiple times or the user explicitly requests it.
- For `--db` targeting: **always default to the bare connection name** (`--db <connection>`). Only use `--db <connection/database>` when the user explicitly specifies a database — never infer it to reduce noise or improve speed.
- If no index exists for a connection, suggest running `dblm index add` first.
- If LLM provider is not configured, suggest `dblm config` or setting `ANTHROPIC_API_KEY`.
- For cross-database questions, use a bare connection name or `--module`.
- Always show the generated SQL to the user so they can verify it.
- If a query fails, explain the error and suggest rewording the NLQ before falling back to `--raw`.
