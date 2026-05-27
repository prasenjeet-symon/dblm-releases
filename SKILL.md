---
description: Interact with dblm — a natural language CLI for querying multiple databases. Use this skill when the user wants to query databases, manage connections, indexes, knowledge, modules, sessions, templates, or configure dblm.
---

# dblm Skill

You are a dblm expert assistant. dblm is a CLI tool that lets users query databases in plain English. It supports Postgres, MySQL, SQLite, MongoDB, and ClickHouse.

When the user asks you to do something with their database(s), use `dblm` commands via the shell. **HARD RULE: rely on natural-language `dblm query` for every database question — do NOT write raw SQL.** `--raw` is a rare exception, only when NLQ has structurally failed 2+ times after rewording, or the user explicitly asks for it (see §4).

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
dblm index add <connection> --db <database>      # index specific database(s), comma-separated
dblm index add <connection> --all                 # index all databases on the connection
dblm index refresh <connection> --db <database>   # re-index after schema changes
dblm index list
dblm index remove <connection/database>           # also accepts a bare connection name
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

### Raw SQL — HARD RULE: almost never

**HARD RULE: Do NOT write raw SQL. Always answer database questions with natural-language `dblm query`.** Raw SQL (`--raw`) is the rare exception, not a tool you reach for. dblm's whole purpose is to generate the SQL for you — let it. Writing SQL yourself defeats the point and bypasses the knowledge, validation, and retry layers built into the query engine.

```sh
# ALWAYS do this — describe what you want in plain English
dblm query "how many orders were placed last week" --db myconn

# Rephrase and retry NLQ if the first attempt isn't right — do NOT jump to raw SQL
dblm query "count distinct event ids that appear more than once" --db myconn
```

**`--raw` is permitted ONLY when ALL of these hold:**
1. The SAME question has already failed via NLQ **at least twice**, AND
2. The failure is **structural** (the engine genuinely cannot express it), not just a poorly worded question that rephrasing would fix, AND
3. You have already tried **rewording** the natural-language question and it still fails.

**Plus** these always-allowed cases:
- The user **explicitly** asks for raw SQL ("run this SQL", "use --raw").
- Debugging: the LLM-generated SQL is known-wrong and you need to run a hand-corrected version to diagnose.

**If in doubt, do NOT use `--raw`.** Reword the NLQ instead. Anything a SELECT can express — aggregations, filters, JOINs, subqueries, window functions, CTEs, GROUP BY/HAVING — must go through NLQ, never `--raw`. When NLQ fails, your first move is to rephrase the question, not to hand-write SQL.

**Never use `--raw` for** anything NLQ can express — SELECT queries, aggregations, filtering, joins, subqueries, window functions, etc.

---

## 5. Knowledge — `dblm knowledge`

Rich per-database documentation (table/column descriptions, relationships, business rules, example queries) that improves NLQ accuracy. Knowledge is generated by the LLM or edited in a web UI — there is no per-table CLI "add".

```sh
dblm knowledge auto <connection/database>   # auto-generate with the LLM (per database)
dblm knowledge auto <connection> --db a,b    # specific databases on a connection
dblm knowledge auto --all                    # all indexed databases
dblm knowledge edit <connection>             # open the web UI to edit documentation
dblm knowledge show <connection/database>    # print documentation (--json, --remote <alias>)
dblm knowledge list                          # list connections that have knowledge
dblm knowledge remove <connection/database>  # delete documentation
```

There is no `knowledge add` command and no `--table` flag. To document a single table, edit via `dblm knowledge edit` or regenerate with `dblm knowledge auto`.

---

## 6. Modules — `dblm module`

Define named cross-database table groups for complex multi-DB queries. Tables are added per (connection, database); foreign-key parent tables are auto-included.

```sh
dblm module create <name>
dblm module add-tables <name> <connection> --db <database>                 # interactive table picker
dblm module add-tables <name> <connection> --db <database> --tables t1,t2  # explicit tables
dblm module show <name>                # list tables (grouped by database); --remote <alias>
dblm module list                       # list modules; --remote <alias>
dblm module remove <name>              # delete the whole module
dblm module knowledge-auto <name>      # auto-generate cross-database knowledge for the module
dblm module knowledge-show <name>      # print module knowledge (--json)
```

There is no per-table removal and no `--alias`. To change a module's tables, adjust and re-add, or `remove` and recreate.

Query a module (engine auto-detects same-server vs cross-connection):
```sh
dblm query "<question>" --module <name>
```

---

## 7. Schema Inspection — `dblm schema`

Inspect raw database schemas without querying. `schema` takes flags — there is no `show` subcommand.

```sh
dblm schema --db <connection/database>                      # table-format overview
dblm schema --db <connection/database> --table <table>      # filter to specific table(s), comma-separated
dblm schema --db <connection/database> --format ddl         # output: table (default), ddl, or json
dblm schema --all                                            # all connections
dblm schema --db <connection/database> --remote <alias>      # from a remote master
```

---

## 8. Templates — `dblm fassad`

Reusable parameterized query templates. A fassad has a **mode** (`sql` or `nlq`), a **body** (the template with `{param}` placeholders), and **param** declarations. Parameters are supplied at run time as dynamic flags (`--<paramname> <value>`).

```sh
# SQL-mode fassad (runs against a connection)
dblm fassad create <name> --mode sql --conn <conn/database> \
  --body "SELECT * FROM orders WHERE status = {status}" \
  --param "status:string"

# NLQ-mode fassad (natural language; can target a module for cross-db)
dblm fassad create <name> --mode nlq --module <module> \
  --body "show orders with status {status} since {since}" \
  --param "status:string" --param "since:date:optional"

dblm fassad run <name> --status pending --since 2024-01-01   # params as dynamic flags
dblm fassad run <name> --status pending --db <conn/database>  # override target
dblm fassad update <name> --body "<new template>"            # edit (same flags as create)
dblm fassad list
dblm fassad show <name>
dblm fassad remove <name>
```

Param declaration format: `name:kind[:default=val|optional]`. `--body` is required (not `--template`); SQL mode requires `--conn`, NLQ mode may use `--module`.

---

## 9. Sessions — `dblm session`

Manage conversation sessions for contextual multi-turn queries.

```sh
dblm session start [name]      # start a new session
dblm session continue [name]   # resume a previous session
dblm session list
dblm session show [name]       # show turns in a session
dblm session end               # end the current session
dblm session remove [name]     # delete a session and its turns
```

---

## 10. History — `dblm history`

Search and review past queries.

```sh
dblm history list
dblm history search "<keyword>"   # semantic search over past queries
dblm history show <id>
dblm history stats                # history storage statistics
```

---

## 11. Broker / Server — `dblm server` & `dblm remote`

Run dblm as a master broker to share database access across a team over HTTP/2 + mTLS.

```sh
# Master side
dblm server init                          # generate CA + server certificate
dblm server start
dblm server user add <username>           # also: user remove <name>, user list
dblm server acl grant <user> <connection> # also: acl revoke <user> <connection>, acl list <user>
dblm server cert list <user>              # inspect/revoke client certs (cert revoke <user>)
dblm server audit

# Worker side — register from the user's mTLS bundle file (not url/cert flags)
dblm remote add <alias> --bundle <path-to-bundle> [--endpoint <url>]
dblm remote list
dblm remote connections                   # connections you're authorized for
dblm remote whoami                        # which user the master sees you as
dblm query "<question>" --remote <alias>
```

---

## Behavior guidelines

- **Discover first.** Before any query, run `dblm connect list` and `dblm index list` to see the available connections and indexed databases. Never guess names — map the user's request to a real, indexed connection.
- dblm is a **read-only query tool** — never suggest it for mutations, DDL, or writes of any kind.
- **HARD RULE — rely on NLQ, not raw SQL.** Answer every database question with natural-language `dblm query`. `--raw` is the rare exception, allowed only when the same question has failed via NLQ 2+ times for a *structural* reason (after rewording), or when the user explicitly asks for raw SQL. When NLQ fails, rephrase the question — do not hand-write SQL. If in doubt, do not use `--raw`.
- For `--db` targeting: **always default to the bare connection name** (`--db <connection>`). Only use `--db <connection/database>` when the user explicitly specifies a database — never infer it to reduce noise or improve speed.
- If no index exists for a connection, suggest running `dblm index add` first.
- If LLM provider is not configured, suggest `dblm config` or setting `ANTHROPIC_API_KEY`.
- For cross-database questions, use a bare connection name or `--module`.
- Always show the generated SQL to the user so they can verify it.
- If a query fails, explain the error and suggest rewording the NLQ before falling back to `--raw`.
