# dblm

Talk to your databases in plain English. dblm is a single-binary CLI that connects
to Postgres, MySQL, SQLite, MongoDB, and ClickHouse, indexes their schemas, and
uses Claude to translate natural-language questions into safe, validated queries.

It also ships a **master/worker broker** so a team can share access to one
machine's database connections over the network without ever sharing DSNs.

dblm is a single binary. Whether you're a master, a worker, or both, you run
the same `dblm`. Which mode you're in is determined by which command you run
and which flags you set.

## Table of contents

1. [Features](#features)
2. [Install](#install)
3. [Setup & configuration](#setup--configuration)
4. [Quickstart (single user, local databases)](#quickstart-single-user-local-databases)
5. [Global flags](#global-flags)
6. [Local mode commands](#local-mode-commands)
   - [`dblm connect`](#dblm-connect) — manage local DSNs
   - [`dblm index`](#dblm-index) — schema indexing
   - [`dblm knowledge`](#dblm-knowledge) — schema documentation
   - [`dblm module`](#dblm-module) — cross-database table groups
   - [`dblm fassad`](#dblm-fassad) — reusable parameterized query templates
   - [`dblm query`](#dblm-query) — natural-language queries
   - [`dblm schema`](#dblm-schema) — schema inspection
   - [`dblm session`](#dblm-session) — conversation sessions
   - [`dblm history`](#dblm-history) — search and manage query history
   - [`dblm skill`](#dblm-skill) — Claude Code AGENT.md installer
   - [`dblm config`](#dblm-config) — interactive LLM configuration
   - [`dblm license`](#dblm-license) — license management
   - [`dblm version`](#dblm-version) — print version
7. [Smart summarization](#smart-summarization)
8. [Self-healing](#self-healing)
9. [Same-server cross-DB queries](#same-server-cross-db-queries)
10. [Broker mode (master/worker)](#broker-mode-masterworker)
   - [What lives on the master vs. the worker](#what-lives-on-the-master-vs-the-worker)
   - [Master setup](#master-setup)
   - [Worker setup](#worker-setup)
   - [What a worker can do](#what-a-worker-can-do)
   - [Master mode commands (`dblm server`)](#master-mode-commands-dblm-server)
   - [Worker mode commands (`dblm remote`)](#worker-mode-commands-dblm-remote)
   - [Worker mode via `--remote` flag](#worker-mode-via---remote-flag)
   - [ACLs](#acls)
   - [Audit log](#audit-log)
   - [User & cert management](#user--cert-management)
11. [Removed commands](#removed-commands)
12. [Configuration paths](#configuration-paths)
13. [Testing](#testing)
14. [Repository layout](#repository-layout)
15. [Quick recipes](#quick-recipes)
16. [License](#license)

## Features

- **Multi-database** — Postgres, MySQL, SQLite, MongoDB, ClickHouse
- **Natural-language queries** — schema-aware SQL generation via Claude, Ollama, or Gemini
- **Same-server cross-DB JOINs** — bare connection names expand to all indexed
  databases; same-server queries use a single LLM call with combined schemas
- **Schema indexing** — local cache of tables/columns/FKs for fast prompting
- **Knowledge docs** — auto-generated, human-editable schema documentation. A short
  per-table summary is injected into the initial prompt; the LLM fetches full column
  details on demand via `get_table_knowledge` — keeping context small regardless of
  database size
- **Modules** — group related tables across databases for cross-database NLQ
- **Fassads** — reusable parameterized query templates (SQL or NLQ mode)
- **Multi-statement scripts** — temp-tables persist across statements in one session
- **Smart summarization** — LLM detects user intent (raw vs summarize vs analytical);
  result size drives summary mode (full / sampled / stats-only / skip)
- **Self-healing** — query retry on SQL errors, LLM rate-limit backoff, script
  regeneration, cross-connection extract-plan refinement
- **Chat sessions + memory** — per-user conversation history with vector search
  (chromem-go); LLM tools (`get_table_knowledge`, `search_history`, `replay_result`,
  `get_recent_turns`) let the model decide when and how to fetch schema details and
  past context
- **Broker mode** — expose connections over HTTP/2 + mTLS to remote workers, with
  per-user ACLs, read-only enforcement, audit logging, cert revocation, and
  per-user history isolation
- **NDJSON streaming** — large result sets stream row-by-row, no buffering
- **Ollama support** — use local models via Ollama instead of Anthropic

## Install

### macOS / Linux

```sh
curl -fsSL https://raw.githubusercontent.com/prasenjeet-symon/dblm-releases/main/install.sh | sh
```

Installs the latest release binary to `/usr/local/bin`. Uses `sudo` only if the directory isn't writable.

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/prasenjeet-symon/dblm-releases/main/install.ps1 | iex
```

Installs to `%LOCALAPPDATA%\dblm` and adds it to your user `PATH`. Open a new terminal after install.

### Manual download

Download the pre-built binary for your platform from the
[releases page](https://github.com/prasenjeet-symon/dblm-releases/releases/latest),
extract the archive, and place `dblm` (or `dblm.exe` on Windows) somewhere on your `PATH`.

| Platform | File |
|---|---|
| macOS (Apple Silicon) | `dblm_*_darwin_arm64.tar.gz` |
| macOS (Intel) | `dblm_*_darwin_x86_64.tar.gz` |
| Linux (x86-64) | `dblm_*_linux_x86_64.tar.gz` |
| Linux (ARM64) | `dblm_*_linux_arm64.tar.gz` |
| Windows (x86-64) | `dblm_*_windows_x86_64.zip` |
| Windows (ARM64) | `dblm_*_windows_arm64.zip` |

### Build from source

```bash
git clone https://github.com/prasenjeet-symon/dblm.git
cd dblm
go build -o dblm .
```

## Setup & configuration

### LLM provider

dblm supports three LLM providers, selected via the `provider` field in
`~/.dblm/config.json` or the `DBLM_LLM_PROVIDER` env var. Default is
`anthropic`. You can also configure interactively with `dblm config`.

#### Anthropic (default)

dblm reads its Anthropic API key from one of three places, in order:

1. `api_key` field in `~/.dblm/config.json`
2. `DBLM_ANTHROPIC_API_KEY` environment variable (preferred)
3. `ANTHROPIC_API_KEY` environment variable (legacy fallback)

```bash
export DBLM_ANTHROPIC_API_KEY="sk-ant-..."
# or
export ANTHROPIC_API_KEY="sk-ant-..."
```

#### Gemini

When `provider` is set to `gemini`, dblm uses the Google Gemini API.

```bash
export DBLM_LLM_PROVIDER="gemini"
export DBLM_GEMINI_API_KEY="your-gemini-key"   # preferred
# or
export GEMINI_API_KEY="your-gemini-key"         # fallback
export DBLM_LLM_MODEL="gemini-2.5-flash"        # default if not set
```

Or add to `~/.dblm/config.json`:

```json
{ "provider": "gemini", "model": "gemini-2.5-flash" }
```

#### Ollama

When `provider` is set to `ollama`, dblm talks to a local (or remote) Ollama
instance instead of Anthropic. No API key is required by default.

```bash
export DBLM_LLM_PROVIDER="ollama"
export DBLM_LLM_BASE_URL="http://localhost:11434"     # default if not set
export DBLM_LLM_MODEL="llama3"                         # default if not set
```

Or add to `~/.dblm/config.json`:

```json
{ "provider": "ollama", "base_url": "http://localhost:11434", "model": "llama3" }
```

| Config field | Env var | Default | Purpose |
|---|---|---|---|
| [v2.7.1](https://github.com/prasenjeet-symon/dblm-releases/releases/tag/v2.7.1) | 2026-08-22 | |
| [v2.7.0](https://github.com/prasenjeet-symon/dblm-releases/releases/tag/v2.7.0) | 2026-08-22 | |
| [v2.6.1](https://github.com/prasenjeet-symon/dblm-releases/releases/tag/v2.6.1) | 2026-08-10 | |
| [v2.6.0](https://github.com/prasenjeet-symon/dblm-releases/releases/tag/v2.6.0) | 2026-08-09 | |
| [v2.5.2](https://github.com/prasenjeet-symon/dblm-releases/releases/tag/v2.5.2) | 2026-08-08 | |
| [v2.5.1](https://github.com/prasenjeet-symon/dblm-releases/releases/tag/v2.5.1) | 2026-07-15 | |
| [v2.5.0](https://github.com/prasenjeet-symon/dblm-releases/releases/tag/v2.5.0) | 2026-07-15 | |
| [v2.4.0](https://github.com/prasenjeet-symon/dblm-releases/releases/tag/v2.4.0) | 2026-07-10 | |
| [v2.3.0](https://github.com/prasenjeet-symon/dblm-releases/releases/tag/v2.3.0) | 2026-07-10 | |
| [v2.2.0](https://github.com/prasenjeet-symon/dblm-releases/releases/tag/v2.2.0) | 2026-07-01 | |
| [v2.1.0](https://github.com/prasenjeet-symon/dblm-releases/releases/tag/v2.1.0) | 2026-06-30 | |
| [v2.0.0](https://github.com/prasenjeet-symon/dblm-releases/releases/tag/v2.0.0) | 2026-06-30 | |
| `base_url` | `DBLM_LLM_BASE_URL` or `OLLAMA_BASE_URL` | `http://localhost:11434` | Ollama server URL |
| `model` | `DBLM_LLM_MODEL` | `llama3` | Model to use |
| — | `DBLM_OLLAMA_API_KEY` or `OLLAMA_API_KEY` | — | API key if your Ollama setup requires one |

> **Worker mode tip:** if you only ever use dblm as a worker (`dblm query
> --remote ...`), you do **not** need an API key at all. The master holds it.

### Config file fields

| Field | Purpose |
|---|---|
| `api_key` | LLM API key (Anthropic, Gemini, or Ollama) |
| `provider` | `"anthropic"` (default), `"gemini"`, or `"ollama"` |
| `base_url` | Custom API base URL (for Ollama or Anthropic-compatible proxies) |
| `model` | Model name (default: `claude-sonnet-4-20250514` for Anthropic, `gemini-2.5-flash` for Gemini, `llama3` for Ollama) |
| `connections` | Array of `{name, driver, dsn}` objects |

### All environment variables

| Variable | Purpose |
|---|---|
| `DBLM_ANTHROPIC_API_KEY` | Anthropic API key (preferred) |
| `ANTHROPIC_API_KEY` | Anthropic API key (legacy fallback) |
| `DBLM_GEMINI_API_KEY` | Gemini API key (preferred) |
| `GEMINI_API_KEY` | Gemini API key (fallback) |
| `DBLM_OLLAMA_API_KEY` | Ollama API key (if auth required) |
| `OLLAMA_API_KEY` | Ollama API key (fallback) |
| `DBLM_LLM_PROVIDER` | LLM provider: `"anthropic"` (default), `"gemini"`, or `"ollama"` |
| `DBLM_LLM_BASE_URL` | Override API base URL |
| `OLLAMA_BASE_URL` | Override Ollama base URL (fallback) |
| `DBLM_LLM_MODEL` | Override model name |
| `DBLM_USER` | Override username for history/sessions (default: `local`) |
| `DBLM_SESSION` | Override active session by name |
| `DBLM_LLM_MAX_RETRIES` | Max LLM rate-limit retries (default: 3) |
| `DBLM_QUERY_MAX_RETRIES` | Max query retry attempts (default: 2) |
| `DBLM_SCRIPT_MAX_RETRIES` | Max script regeneration attempts (default: 1) |
| `DBLM_EXTRACT_REFINE_RETRIES` | Max extract-plan refinements (default: 1) |

## Quickstart (single user, local databases)

```bash
# 1. Register a connection (no database name in the DSN — that gets selected later)
dblm connect add lite --driver sqlite --dsn "./chinook.db"

# 2. Index its schema so the engine has something to send to the LLM
dblm index add lite

# 3. Ask a question
dblm query "list 5 artist names that start with A" --db lite
```

The engine sends the schema + your question to Claude, gets back SQL, validates
it as read-only, executes it locally, and prints the result with a summary.

For raw SQL (no LLM):

```bash
dblm query "SELECT * FROM Artist LIMIT 5" --db lite --raw
```

For multi-database servers (Postgres, MySQL, etc.), index all databases and
query across them:

```bash
# Register a multi-database connection (DSN without database name)
dblm connect add myshop --driver mysql --dsn "user:pass@tcp(localhost:3306)/"

# Index all databases on the server
dblm index add myshop

# Query across databases — "myshop" expands to all indexed DBs
dblm query "show me customers with their order counts" --db myshop
```

---

## Global flags

These work on every command.

| Flag | Default | Purpose |
|---|---|---|
| `--config <path>` | `~/.dblm/config.json` | Override the config file path |
| `-h`, `--help` | — | Show help for any command or subcommand |

---

## Local mode commands

These commands run against connections registered in this machine's
`~/.dblm/config.json`.

### `dblm connect`

Manage the database connections this machine can talk to. Master only — workers
should not use these.

```bash
dblm connect add <name> --driver <driver> --dsn "<dsn>"
dblm connect list                              # alias: ls
dblm connect test <name>
dblm connect remove <name>
```

#### `dblm connect add`

Register a new connection. The DSN must **not** contain a database name —
databases are selected at index/query time.

```bash
dblm connect add mydb --driver postgres --dsn "postgres://user:pass@localhost:5432/?sslmode=disable"
dblm connect add local --driver sqlite --dsn "./data.db"
dblm connect add cache --driver mysql --dsn "user:pass@tcp(localhost:3306)/"
dblm connect add docs --driver mongo --dsn "mongodb://user:pass@localhost:27017/"
dblm connect add events --driver clickhouse --dsn "clickhouse://user:pass@localhost:9000/"
```

| Flag | Required | Purpose |
|---|---|---|
| `--driver <name>` | yes | One of `postgres`, `mysql`, `sqlite`, `mongo`, `clickhouse` |
| `--dsn <string>` | yes | Connection string for the driver |

| Driver | DSN format |
|---|---|
| `postgres` | `postgres://user:pass@host:5432/?sslmode=disable` |
| `mysql` | `user:pass@tcp(host:3306)/` |
| `sqlite` | `./path/to/db.sqlite` |
| `mongo` | `mongodb://user:pass@host:27017/` |
| `clickhouse` | `clickhouse://user:pass@host:9000/` |

#### `dblm connect list` / `ls`

List every connection in `~/.dblm/config.json`. Passwords in DSNs are masked.

#### `dblm connect test <name>`

Try to open a connection and ping the database. Returns OK or the underlying
driver error.

#### `dblm connect remove <name>`

Delete a connection from the config. Cascades: any cached schema indexes and
knowledge docs scoped to this connection are also removed.

---

### `dblm index`

Schema indexes are local snapshots of database structure (tables, columns,
foreign keys, sample rows). The query engine reads from the index instead of
introspecting live, so an NLQ is one LLM call instead of an introspection round
trip plus an LLM call.

```bash
dblm index add <connection> [--db a,b]
dblm index add --all
dblm index refresh <connection> [--db a,b]
dblm index refresh --all
dblm index list                                 # alias: ls
dblm index remove <connection>
dblm index remove <connection>/<db>             # single database
```

#### `dblm index add`

Fetch schema from a live database and store it in `~/.dblm/index.db`.

```bash
dblm index add alpha                          # discover and index every DB on the server
dblm index add alpha --db orbit_japa          # index a single DB
dblm index add alpha --db orbit_japa,ShopDB   # index specific DBs (in parallel)
dblm index add --all                          # every connection, every DB
dblm index add --all --skip-existing           # only databases not yet in the index
```

| Flag | Purpose |
|---|---|
| `--all` | Index every configured connection |
| `--db <list>` | Comma-separated database names; default = all DBs on the server |
| `--skip-existing` | Skip databases that are already indexed (no re-index) |

#### `dblm index refresh`

Re-fetch schema and update the index. Marks any existing knowledge docs for the
refreshed connection as stale (so dblm warns next time you query that the
knowledge may be out of date).

```bash
dblm index refresh alpha
dblm index refresh alpha --db orbit_japa
dblm index refresh --all
```

| Flag | Purpose |
|---|---|
| `--all` | Refresh every configured connection |
| `--db <list>` | Comma-separated database names; default = all DBs on the server |

Note: `--skip-existing` is not available on `refresh` — it always re-fetches.

#### `dblm index list` / `ls`

List every indexed database with table count, column count, FK count, etc.

#### `dblm index remove`

Delete cached index entries. Also removes any knowledge docs scoped to the
removed connection/database.

```bash
dblm index remove alpha               # all alpha/* indexes + knowledge
dblm index remove alpha/orbit_japa    # one specific database + its knowledge
```

---

### `dblm knowledge`

Knowledge is human-readable Markdown describing what tables and columns mean.
dblm can generate it automatically with the LLM, you can edit it in a browser,
and it gets injected into LLM prompts to improve query generation on real-world
schemas.

```bash
dblm knowledge auto <connection>      # auto-generate via LLM
dblm knowledge edit <connection>      # browser editor
dblm knowledge list                   # alias: ls
dblm knowledge show <connection> [--remote <alias>] [--json]
dblm knowledge remove <connection>
```

#### `dblm knowledge auto`

Run the LLM over a connection's indexed schema and generate documentation:
a short per-table **summary** (used in the initial query prompt), a full table
description, column notes, relationships, business rules, example queries, and
a glossary.

During queries the initial context contains only the table summaries and
cross-table knowledge (relationships, rules, glossary). The LLM calls
`get_table_knowledge` to fetch full DDL and column docs for the specific tables
it needs — keeping prompts small even on databases with hundreds of tables.

```bash
dblm knowledge auto alpha/orbit_japa                  # one database
dblm knowledge auto alpha --db orbit_japa,ShopDB      # multiple DBs
dblm knowledge auto alpha                             # every indexed DB under alpha
dblm knowledge auto --all                             # every indexed DB everywhere
```

| Flag | Purpose |
|---|---|
| `--all` | Generate for every indexed database |
| `--db <list>` | Comma-separated database names |

Requires the LLM API key.

#### `dblm knowledge edit <connection>`

Open a local web UI in your browser to refine knowledge that was auto-generated
(or to write it from scratch). The server stops when you Ctrl-C.

#### `dblm knowledge list` / `ls`

Show every connection that has knowledge documented.

#### `dblm knowledge show <connection>`

Display the knowledge document.

| Flag | Purpose |
|---|---|
| `--json` | Output as JSON instead of formatted Markdown |
| `--remote <alias>` | Fetch from a remote master instead of locally (worker mode) |

In worker mode the user must have an explicit `--with-knowledge` grant on the
connection — see [`dblm server acl grant`](#dblm-server-acl).

#### `dblm knowledge remove <connection>`

Delete a knowledge document.

---

### `dblm module`

Modules group related tables — possibly from different databases — for cross-
database NLQ queries. When you add tables, FK parent tables are automatically
included even if they live in another database.

```bash
dblm module create <name>
dblm module add-tables <module> <connection> --db <db> [--tables a,b,c]
dblm module list [--remote <alias>]                       # alias: ls
dblm module show <module> [--remote <alias>]
dblm module remove <module>
dblm module knowledge-auto <module>
dblm module knowledge-show <module> [--json]
```

#### `dblm module create <name>`

Create a new empty module.

#### `dblm module add-tables <module> <connection>`

Add tables from a database to a module. FK parent tables are auto-included.

```bash
dblm module add-tables user-mgmt alpha --db orbit_japa
dblm module add-tables user-mgmt alpha --db orbit_japa --tables japa_user,japa_session
```

| Flag | Required | Purpose |
|---|---|---|
| `--db <name>` | yes | The database within the connection to pull tables from |
| `--tables <list>` | no | Comma-separated table names. If omitted, opens an interactive TUI selector |

#### `dblm module list` / `ls`

List all modules.

| Flag | Purpose |
|---|---|
| `--remote <alias>` | List modules visible on a remote master (strict ACL filtered) |

#### `dblm module show <module>`

Show every table in a module, grouped by source database.

| Flag | Purpose |
|---|---|
| `--remote <alias>` | Fetch from a remote master |

#### `dblm module remove <module>`

Delete a module definition.

#### `dblm module knowledge-auto <module>`

Generate cross-database knowledge for a module: relationships, example queries,
glossary entries that span databases. Per-database knowledge is not duplicated
— use `dblm knowledge auto` for that.

Only meaningful for modules that span multiple databases. Requires LLM API key.

#### `dblm module knowledge-show <module>`

Display module knowledge.

| Flag | Purpose |
|---|---|
| `--json` | JSON output |

---

### `dblm fassad`

Fassads are stored-procedure-like templates that accept runtime parameters.

#### Design intention

Each fassad is intended to do **exactly one thing**. A well-designed fassad has a
narrow, stable body — the same parameters always produce the same (or near-identical)
results. This near-determinism is deliberate: because the output is predictable, every
fassad can be individually indexed and its results cached, so repeated runs return
instantly without re-invoking the LLM or re-hitting the database. Think of each fassad
as a named, typed slot in your query catalogue — small, focused, and fast by design.

Two modes are supported:

- **`sql`** — direct SQL with parameter binding (`{param}` replaced with values via
  positional `?` placeholders for safety). Must target a single connection (`--conn`).
- **`nlq`** — natural language template, resolved through the LLM pipeline. Supports
  both single-connection (`--conn`) and multi-connection (`--module`) targets.

#### How NLQ mode works

At runtime, `{param}` placeholders in the template body are substituted first (the
**Render** step), then the fully-resolved question is passed to the same LLM pipeline
that `dblm query` uses — schema loading, SQL generation, execution, and optional
summarization. The engine receives the rendered question and has no knowledge that it
originated from a template.

```
Template body:  "show me revenue by region for {year}"
Runtime args:   { year: "2024" }
After Render:   "show me revenue by region for 2024"
                        ↓
              LLM pipeline (identical to dblm query)
```

#### NLQ fassad vs `dblm query`

| | `dblm query` | `dblm fassad run` (nlq) |
|---|---|---|
| Input | Raw question typed by user | Stored template with typed parameters |
| Reusability | One-time | Stored, reusable across runs |
| Parameters | None | Declared with name, kind, and optional defaults |
| Missing params | N/A | Prompted interactively at runtime |
| Multi-connection | Via `--module` | Via `--module` (stored or overridden at run time) |
| LLM pipeline | Same | Same (after Render) |

#### Single-connection vs multi-connection (NLQ)

| Target | Flag at create | Engine call | Use case |
|---|---|---|---|
| Single DB | `--conn pg/mydb` | `QueryWithOptions()` | One database |
| Multi-DB | `--module my-module` | `QueryModule()` | All DBs in the module (extract-merge pattern) |

SQL mode **cannot** target a module — only NLQ mode supports multi-connection queries,
because raw SQL is database-specific while the LLM can generate appropriate SQL per
connection.

```bash
dblm fassad create <name> --mode <sql|nlq> --body <template> [flags]
dblm fassad update <name> [flags]
dblm fassad list [--json]                                  # alias: ls
dblm fassad show <name> [--json]
dblm fassad remove <name>
dblm fassad run <name> [parameter flags] [flags]
```

#### `dblm fassad create <name>`

Create a new fassad template.

```bash
dblm fassad create daily-sales --mode sql --conn purpus/ShopDB \
  --body "SELECT * FROM orders WHERE order_date = '{date}' AND status = '{status}'" \
  --param date:string:required --param status:string:default=completed

dblm fassad create cross-db-report --mode nlq --module sales-analytics \
  --body "show me revenue by region for {year}" \
  --param year:int:required
```

| Flag | Required | Purpose |
|---|---|---|
| `--mode <sql\|nlq>` | yes | Template mode |
| `--body <template>` | yes | Template body (SQL or natural language with `{param}` placeholders) |
| `--conn <connection>` | for `sql` mode | Target connection (e.g., `purpus/ShopDB`) |
| `--module <module>` | for `nlq` mode | Target module for cross-database NLQ |
| `--param <name:kind[:qualifier]>` | no (repeatable) | Parameter declaration. Kind: `string`, `int`, `float`, `bool`. Qualifier: `required` (default), `optional`, or `default=<value>` |

`--conn` and `--module` are mutually exclusive. SQL mode fassads must use `--conn`.

#### `dblm fassad update <name>`

Update an existing fassad. Only specified flags are changed; omitted flags
retain their current value.

Same flags as `create`, but none are required. To clear the connection or
module target, pass an empty string.

#### `dblm fassad list` / `ls`

List all fassads.

| Flag | Purpose |
|---|---|
| `--json` | Output as JSON |

#### `dblm fassad show <name>`

Show details of a fassad including its body and parameters.

| Flag | Purpose |
|---|---|
| `--json` | Output as JSON |

#### `dblm fassad remove <name>`

Delete a fassad.

#### `dblm fassad run <name>`

Run a fassad template, supplying runtime parameters via `--key value` flags
(e.g., `--date 2024-01-15`). Unknown flags are treated as fassad parameter
values; known cobra flags (`--db`, `--module`, `--raw`, `--json`, etc.) are
consumed normally.

Missing required parameters are prompted interactively. Parameters with
defaults are filled automatically.

```bash
dblm fassad run daily-sales --date 2024-01-15
dblm fassad run daily-sales --date 2024-01-15 --status pending --db purpus/ShopDB
dblm fassad run cross-db-report --year 2024 --module sales-analytics
dblm fassad run top-artists --limit 10 --db purpus/ShopDB --remote staging
```

| Flag | Purpose |
|---|---|
| `--db <connection>` | Override the fassad's stored connection for this run |
| `--module <module>` | Override the fassad's stored module for this run (NLQ mode only) |
| `--raw` | For NLQ mode: execute as raw query instead of LLM planning |
| `--json` | Output results as JSON |
| `--no-summary` | Skip summarization |
| `--force-summary` | Always summarize |
| `--remote <alias>` | Run through a registered remote master |

---

### `dblm query`

Natural-language queries. Asks Claude to translate your question into SQL,
runs the SQL, and returns rows + an optional summary.

```bash
dblm query "<question>" [--db a,b] [--module name] [--raw] [--json] [--no-summary | --force-summary] [--context <text>] [--rule <rule>] [--remote <alias>]
```

| Flag | Purpose |
|---|---|
| `--db <list>` | Comma-separated target connections. Bare names (e.g., `myshop`) expand to all indexed databases; namespaced (e.g., `myshop/orders`) target a single database. Default: all configured connections expanded |
| `--module <name>` | Run against a module instead of individual connections (mutually exclusive with `--db`) |
| `--raw` | Skip the LLM planner — treat the question as raw SQL |
| `--stream` | Stream rows as they arrive (NDJSON over the wire). Requires `--raw` and `--remote`. Ideal for very large result sets |
| `--json` | Output as JSON (machine-readable). With `--stream`, emits one JSON object per row |
| `--no-summary` | Skip the summarization step |
| `--force-summary` | Always summarize the full result (warning: may overflow token limits on huge results) |
| `--context <text>` | Informational context prepended to the question — helps the LLM resolve references like "me" or "my data" (e.g. `"current user email: foo@bar.com"`) |
| `--rule <text>` | Enforced constraint injected into the **system prompt** — the LLM treats it as an operator rule it must obey (e.g. `"only return rows where user_id = 42"`). Incompatible with `--raw`. |
| `--report <format>` | Export results as a report file: `html`, `csv`, `pdf`, or `png`. HTML/PDF/PNG are LLM-designed; CSV is data-only. Incompatible with `--stream`. |
| `--output <path>` | Report output file path (default: `dblm-report-<timestamp>.<format>`). Only used with `--report`. |
| `--remote <alias>` | Route through a registered remote master instead of running locally |

#### `--context` vs `--rule`

These two flags look similar but serve different purposes:

| | `--context` | `--rule` |
|---|---|---|
| Injected into | User message | System prompt |
| LLM treats it as | Background information | Authoritative operator constraint |
| Use for | Resolving "me", "my data" references | Row filters, column restrictions, access rules |
| Example | `--context "user email: foo@bar.com"` | `--rule "never expose email columns"` |

Use `--context` to give the LLM facts it needs to understand the question. Use `--rule` when you want to enforce a constraint the LLM must not ignore — such as row-level data scoping or column visibility restrictions.

#### Examples — local mode

```bash
dblm query "show me all users who signed up last week"
dblm query "top 10 products by revenue" --db myshop
dblm query "count orders per day" --db postgres1,mysql1
dblm query "build a temp table of recent orders then list top customers" --db pg/testdb
```

#### Examples — bare connection expansion (same-server cross-DB JOINs)

When you specify a bare connection name (without `/dbname`) in NLQ mode, dblm
expands it to **all indexed databases** under that connection. If all those
databases are on the same server, dblm detects this and makes a single LLM call
with combined schemas — enabling cross-database JOINs using fully-qualified
table names (`dbname.table`).

```bash
# Expands "myshop" to all indexed databases (myshop/orders, myshop/users, etc.)
# Detects same-server → single LLM call, cross-DB JOINs with myshop.orders JOIN myshop.users
dblm query "show me customers with their order counts" --db myshop

# Multiple explicit databases on the same server — same optimization applies
dblm query "join orders and customers" --db myshop/orders,myshop/customers

# Single explicit database — no expansion, straightforward query
dblm query "show me recent orders" --db myshop/orders
```

#### Examples — raw SQL mode

```bash
dblm query "SELECT name FROM users LIMIT 5" --db pg/testdb --raw
dblm query "SELECT * FROM Genre" --db lite --raw --json
```

`--raw` requires exactly one `--db` target. When using a bare connection name
with `--raw`, no expansion happens — it connects to the default DSN only:

```bash
# Raw mode with bare name — connects to default DB, no cross-DB expansion
dblm query "SELECT * FROM users LIMIT 10" --db myshop --raw
```

#### Examples — module mode

```bash
dblm query "revenue by region last quarter" --module sales
dblm query "japa users with sessions in the last 7 days" --module japa-tracking
```

#### Examples — remote mode (worker)

See the [Worker mode via `--remote` flag](#worker-mode-via---remote-flag) section below.

#### Connection target shorthand

Anywhere a connection target appears (`--db`, the `dblm query` `--db` flag, etc.)
you can use either:

- `<connection>` — bare connection name. In NLQ mode, expands to **all indexed
  databases** under that connection (enabling same-server cross-DB JOINs). In
  `--raw` mode, connects to the connection's default DSN only.
- `<connection>/<dbname>` — explicit `connection/database` form. No expansion.
  Targets a single database on the server.

When no `--db` is specified in NLQ mode, all configured connections are expanded
to their indexed databases. Same-server optimization applies automatically when
all result databases share the same connection prefix.

---

### `dblm schema`

Inspect database schemas without running a query.

```bash
dblm schema [--db a,b | --all] [--format table|ddl|json] [--table <name>] [--remote <alias>]
```

| Flag | Purpose |
|---|---|
| `--db <list>` | Target connection(s), comma-separated |
| `--all` | Show schemas for every configured / granted connection |
| `--format <fmt>` | `table` (default human-readable), `ddl` (CREATE TABLE statements), `json` (machine-readable) |
| `--table <list>` | Filter to specific table name(s), comma-separated |
| `--remote <alias>` | Fetch schemas from a remote master instead of locally |

#### Examples — local mode

```bash
dblm schema --db mydb
dblm schema --db mydb --format ddl
dblm schema --db mydb --table users
dblm schema --db mydb --table users,orders,invoices    # multiple tables
dblm schema --all --format json
```

#### Examples — remote mode

```bash
dblm schema --remote prod --db lite --format ddl
dblm schema --remote prod                       # every connection the master grants
```

---

### `dblm session`

Sessions group related queries into a conversation. Recent session turns are
automatically injected into the LLM prompt for pronoun resolution and
contextual follow-ups. History is stored per-user (keyed by `DBLM_USER` env var
or `local` by default).

```bash
dblm session start [name]
dblm session end
dblm session list                                          # alias: ls
dblm session show <name>
dblm session continue <name>
dblm session remove <name>
```

#### `dblm session start [name]`

Start a named conversation session. All subsequent `dblm query` calls are
recorded under this session until you run `session end`. Without a name, the
session is auto-named with a timestamp.

```bash
dblm session start customer-analysis
dblm session start              # auto-named: 20260118-140503
```

#### `dblm session end`

End the current session. Prints the session name and number of turns recorded.

#### `dblm session list` / `ls`

List all sessions with turn counts and active marker.

#### `dblm session show <name>`

Show every turn in a session: question, target, SQL, result status, and row
count.

#### `dblm session continue <name>`

Resume a previously ended session. New queries will be appended to it.

#### `dblm session remove <name>`

Delete a session and all of its recorded turns.

---

### `dblm history`

Search past queries using semantic vector search, browse history linearly, or
inspect individual turns. Turns are automatically recorded when you run
NLQ queries.

```bash
dblm history search <query> [flags]
dblm history list [flags]
dblm history show <turn-id>
dblm history stats
```

#### `dblm history search <query>`

Semantic search over past queries. Finds past turns whose question, SQL, or
result matches your search text using vector embeddings.

```bash
dblm history search "customer churn"
dblm history search "orders last week" --session customer-analysis
dblm history search "aggregation query" --target pg/testdb --limit 10
```

| Flag | Default | Purpose |
|---|---|---|
| `--session <name>` | — | Filter to a specific session name |
| `--target <db>` | — | Filter to a specific database target |
| `--limit <n>` | 5 | Max number of results |

#### `dblm history list`

List recent turns in chronological order.

```bash
dblm history list --last 20
dblm history list --session customer-analysis
```

| Flag | Default | Purpose |
|---|---|---|
| `--last <n>` | 20 | Number of recent turns to show |
| `--session <name>` | — | Filter to a specific session name |

#### `dblm history show <turn-id>`

Show full details of a specific turn: ID, timestamp, session, question,
intent, target, SQL, success status, row count, and result fingerprint.

#### `dblm history stats`

Show storage statistics: total turns, vector index size, session count, and
date range.

When the LLM needs deeper context it calls `search_history` (vector search over
past turns) or `replay_result` (re-runs adapted past SQL as a temp table). In
broker mode, history is stored per-user on the master keyed by certificate CN.

---

### `dblm skill` — Claude Code AGENT.md installer

Downloads the dblm Claude Code skill file and saves it as `AGENT.md` in the
current directory. `AGENT.md` gives Claude deep knowledge of every dblm
command, the NLQ-first workflow, and the correct `--db` targeting rules — so
you can describe what you want and Claude runs the right `dblm` commands for you.

```bash
dblm skill install                      # saves to ./AGENT.md (default)
dblm skill install --output CLAUDE.md   # save to a custom path
```

| Flag | Default | Purpose |
|---|---|---|
| `--output <path>` | `AGENT.md` | Output file path |

Once `AGENT.md` is in your project, Claude automatically activates when you ask
about databases and will discover your connections, index them if needed, and
run `dblm query` — never raw SQL unless you ask.

---

### `dblm config`

Interactively configure the LLM provider, API key, model, and base URL.
Settings are saved to `~/.dblm/config.json`.

```bash
dblm config
```

Prompts for:
- **Provider** — `anthropic`, `gemini`, or `ollama`
- **API key** — masked input (press Enter to keep current)
- **Base URL** — for Ollama or custom endpoints (press Enter to keep current)
- **Model** — override the default model (press Enter to keep current)

---

### `dblm license`

Manage your dblm license. A valid license is required before any command can
run (except `dblm license`, `dblm config`, and `dblm skill`).

```bash
dblm license activate <key>   # activate with a license key
dblm license show             # show current license details
dblm license remove           # remove the current license
```

#### `dblm license activate <key>`

Verify and save a license key. Prints the license name, email, and expiry date
on success.

#### `dblm license show`

Display the current license status, name, email, license ID, issue date, and
expiry date.

#### `dblm license remove`

Delete the stored license file.

---

### `dblm version`

Print the dblm binary version.

```bash
dblm version
```

---

## Smart summarization

The engine detects user intent during SQL generation and picks a summary mode:

| Result size | Mode | What happens |
|---|---|---|
| 1 row (aggregation) | Full | Entire result sent to LLM |
| ≤50 rows | Full | LLM sees everything |
| 51–500 rows | Sampled | 20 representative rows + column stats |
| 501+ rows | Stats-only | Column statistics only (zero row data) |
| `--no-summary` | Skip | No LLM call for summarization |

Intent keywords like "show me all" (raw) vs "summarize" steer the mode
automatically. Override with `--no-summary` or `--force-summary`.

## Self-healing

| Layer | What it does | Env var |
|---|---|---|
| LLM rate-limit backoff | Exponential retry on 429/5xx | `DBLM_LLM_MAX_RETRIES` (3) |
| Query retry | LLM rewrites failed SQL | `DBLM_QUERY_MAX_RETRIES` (2) |
| Script regen | Full script regenerated if any statement fails | `DBLM_SCRIPT_MAX_RETRIES` (1) |
| Extract refinement | Cross-connection extract plan regenerated | `DBLM_EXTRACT_REFINE_RETRIES` (1) |

---

## Same-server cross-DB queries

When all queried databases are on the same server (e.g., `myshop/orders`,
`myshop/users`, `myshop/products` all share the `myshop` connection), dblm
detects this and optimizes the query into a **single LLM call** with combined
schemas. The LLM can then write cross-database JOINs using fully-qualified
table names (e.g., `orders.invoice JOIN users.customer`).

This works automatically when:

1. You specify a **bare connection name** — `--db myshop` expands to all
   indexed databases under that connection and triggers same-server detection.
2. You explicitly list databases under the same connection — `--db
   myshop/orders,myshop/users` also triggers the optimization.

When databases span **different servers** (e.g., Postgres + MySQL), dblm
falls back to the extract-merge pattern: each connection is queried
independently, and results are merged locally.

```bash
# Same-server: single LLM call, cross-DB JOINs possible
dblm query "show customers with their order totals" --db myshop

# Same-server with explicit databases
dblm query "join orders and customers" --db myshop/orders,myshop/customers

# Cross-server: independent queries, local merge
dblm query "compare revenue across systems" --db pg/analytics,mysql/shop
```

---

## Broker mode (master/worker)

The broker exposes one machine's database connections over HTTP/2 + mTLS so
remote workers can run queries without seeing the underlying DSNs. Auth is by
client certificate signed by the master's CA. Per-user, per-connection grants
control which databases each user can touch, and the read-only flag enforces
SELECT-only access.

### What lives on the master vs. the worker

| The master holds | The worker holds |
|---|---|
| All database DSNs and credentials | Only its mTLS bundle (cert + key + CA + endpoint) |
| The LLM API key (Anthropic or Ollama) | Nothing — no API key |
| Schema indexes (`dblm index add`) | Nothing — no schema cache |
| Knowledge documentation | Nothing |
| Per-user grants and ACLs | Nothing — the master decides |
| The audit log | Nothing |

The worker is genuinely dumb. It sends an English question over mTLS and gets
a fully-rendered result back. The LLM call, the schema lookup, the SQL
generation, the execution against the database, and the result summary all
happen on the master.

### Master setup

```bash
# 1. Configure connections + index their schemas (master does this for everyone)
dblm connect add lite --driver sqlite --dsn "./chinook.db"
dblm connect add pg   --driver postgres --dsn "postgres://user:pass@db:5432/?sslmode=disable"
dblm index add lite
dblm index add pg

# 2. Set the LLM API key in the env that runs `dblm server start`.
#    The master uses this to plan NLQ on workers' behalf.
export DBLM_ANTHROPIC_API_KEY="sk-ant-..."
#    Or use Ollama instead:
# export DBLM_LLM_PROVIDER="ollama"

# 3. Generate the CA + server cert
dblm server init --cn dblm-master --sans "your-host.example.com,127.0.0.1"

# 4. Create a user — produces a JSON bundle to give to the worker
dblm server user add alice \
  --endpoint https://your-host.example.com:8443 \
  --out alice.bundle.json

# 5. Grant access (--read-only is highly recommended)
dblm server acl grant alice lite --read-only
dblm server acl grant alice pg   --read-only

# 6. Start the broker
dblm server start --listen :8443
```

On startup the master prints `nlq: enabled (master-side engine)` if both the
LLM key and at least one schema index are present. If either is missing it
prints which one — `dblm query --remote` will return an error until both
are in place.

### Worker setup

The worker only needs the bundle file the admin gave them. It contains the
client cert, private key, CA cert, and endpoint URL.

```bash
# Register one or more remotes under short aliases
dblm remote add prod    --bundle alice.bundle.json
dblm remote add staging --bundle alice-staging.bundle.json

dblm remote list
dblm remote whoami --alias prod          # see who the master thinks we are
dblm remote connections --alias prod     # what we're allowed to use
```

### What a worker can do

Once a worker has registered a remote (`dblm remote add prod --bundle …`),
they can run the same commands they'd run locally — just with `--remote
prod` appended. The master enforces ACLs on every request.

```bash
# Natural-language queries
dblm query "list top 5 artists by track count" --remote prod --db lite
dblm query "show me revenue by region last quarter" --remote prod          # uses every granted connection
dblm query "SELECT * FROM Artist LIMIT 5" --remote prod --db lite --raw    # bypass the LLM planner
dblm query "..." --remote prod --module sales                              # module-mode NLQ

# NDJSON streaming for very large result sets — rows arrive one at a time,
# no buffering on either side. Add --json for newline-delimited JSON objects.
dblm query "SELECT * FROM Track" --remote prod --db lite --raw --stream
dblm query "SELECT * FROM Track" --remote prod --db lite --raw --stream --json

# Schema inspection (uses /v1/tables, ACL-filtered)
dblm schema --remote prod --db lite
dblm schema --remote prod --db lite --format ddl
dblm schema --remote prod                                                  # all granted connections

# Knowledge documentation (requires --with-knowledge grant)
dblm knowledge show lite --remote prod

# Modules (strict ACL — only modules where the user has every required grant)
dblm module list --remote prod
dblm module show sales --remote prod
```

Everything runs on the master. The worker never sees DSNs, never needs an
Anthropic API key, never needs its own schema index, and never needs to
know what kind of database is on the other end. The master:

1. Authenticates the worker via the client cert
2. Filters the request by the user's per-connection grants
3. Loads schemas + knowledge from its own local stores
4. Calls the LLM (using the master's API key)
5. Runs the generated SQL against the master's local drivers
6. Summarizes and returns a fully-rendered result

Read-only enforcement and the strict module ACL are applied at the master
side — even an LLM-generated mutation statement is rejected before
reaching the database, as a second line of defense after the planner's
own refusal.

---

## Master mode commands (`dblm server`)

The broker that exposes this machine's database connections to remote workers
over HTTP/2 + mTLS. Each user is identified by a client certificate signed by
the master's CA.

These commands are master-only — they manage PKI material, the user store, the
audit log, and the broker process itself.

### `dblm server init`

Generate a new master CA and server certificate. Run this **once** before
starting the broker for the first time.

```bash
dblm server init [--cn <name>] [--sans <list>] [--force]
```

| Flag | Default | Purpose |
|---|---|---|
| `--cn <name>` | `dblm-master` | CommonName for the server certificate |
| `--sans <list>` | `localhost,127.0.0.1` | Comma-separated DNS / IP Subject Alternative Names |
| `--force` | — | Overwrite existing CA / server cert (destructive) |

If you're going to expose the master on the public internet, set `--sans` to
include your real hostname:

```bash
dblm server init --cn dblm-master --sans "your-host.example.com,127.0.0.1"
```

Files produced under `~/.dblm/server/`:
- `ca.crt` / `ca.key` — the Certificate Authority that signs all client certs
- `server.crt` / `server.key` — the TLS cert the broker presents to workers

### `dblm server start`

Start the broker server. Binds to a TCP port and serves HTTPS with mutual TLS.

```bash
dblm server start [--listen <addr>]
```

| Flag | Default | Purpose |
|---|---|---|
| `--listen <addr>` | `:8443` | Address to bind |

On startup the broker prints which features are enabled:

```
dblm broker starting on :8443
  users:       3 configured
  connections: 5 configured
  nlq:         enabled (master-side engine)
Press Ctrl-C to stop.
```

The `nlq` line tells you whether master-side natural-language queries are
available:

| Status | What it means |
|---|---|
| `enabled (master-side engine)` | LLM key or Ollama provider + at least one schema index found — workers can use `dblm query --remote` |
| `disabled (no LLM key)` | Set `DBLM_ANTHROPIC_API_KEY` (or use Ollama via `DBLM_LLM_PROVIDER=ollama`) and restart |
| `disabled (no schema index — run dblm index add)` | Run `dblm index add <conn>` for at least one connection |

NLQ is optional — even with it disabled, workers can still use the lower-level
endpoints (raw query, schema, etc.).

### `dblm server user`

Manage broker users.

```bash
dblm server user add <name> [--endpoint <url>] [--out <path>] [--days <n>]
dblm server user list                              # alias: ls
dblm server user remove <name>
```

#### `dblm server user add <name>`

Generate a new user and issue them a client certificate bundle.

| Flag | Default | Purpose |
|---|---|---|
| `--endpoint <url>` | `https://localhost:8443` | The endpoint URL the worker will connect to |
| `--out <path>` | `./dblm-<name>.bundle.json` | Where to write the user bundle |
| `--days <n>` | `365` | Cert validity in days |

The bundle is a JSON file containing the CA cert, client cert, client private
key, and the endpoint URL. Hand this file to the user — it's everything they
need to register a remote with `dblm remote add`.

```bash
dblm server user add alice \
  --endpoint https://your-host.example.com:8443 \
  --out alice.bundle.json
```

#### `dblm server user list` / `ls`

List every user with cert count and grant summary.

#### `dblm server user remove <name>`

Delete a user. **All of their currently issued certificates are auto-revoked**
and the serials are added to the store-wide revocation set, so removing alice
and re-creating her with the same name does NOT un-revoke her old certs.

### `dblm server acl`

Manage per-user, per-connection grants. Two independent permission bits per
grant.

```bash
dblm server acl grant <user> <conn> [--read-only] [--with-knowledge]
dblm server acl revoke <user> <conn>
dblm server acl list [user]                        # alias: ls
```

#### `dblm server acl grant <user> <conn>`

| Flag | Purpose |
|---|---|
| `--read-only` | User may only run `SELECT`, `WITH`, `SHOW`, `EXPLAIN`, `DESCRIBE`, `PRAGMA`, `VALUES`. Anything else is rejected with HTTP 403 |
| `--with-knowledge` | User may fetch this connection's knowledge document via `dblm knowledge show --remote`. Off by default — knowledge often holds business context you want to gate even from users that can run SELECTs |

```bash
dblm server acl grant alice lite                              # full read/write
dblm server acl grant alice lite --read-only                  # SELECTs only
dblm server acl grant alice lite --read-only --with-knowledge # SELECTs + knowledge doc
```

#### `dblm server acl revoke <user> <conn>`

Remove a grant.

#### `dblm server acl list [user]` / `ls`

List grants. Without an argument, lists every grant for every user. With a
username, lists just that user's grants.

```bash
dblm server acl list
# USER   CONNECTION  MODE  KNOWLEDGE
# ----   ----------  ----  ---------
# alice  lite        ro    yes
# alice  pg          ro    no
```

> **Strict module ACL:** modules are visible to a user only when they have a
> grant on every connection the module references. Missing one connection
> hides the entire module from `dblm module list --remote`.

### `dblm server cert`

Inspect and revoke client certificates.

```bash
dblm server cert list [user]                       # alias: ls
dblm server cert revoke <user> [--serial <hex>]
```

#### `dblm server cert list [user]` / `ls`

List issued certs and their status (`valid`, `revoked`, `expired`). Without an
argument, lists every cert for every user. Also shows orphan revocations
(serials whose user was deleted).

#### `dblm server cert revoke <user>`

Revoke a user's certificates.

| Flag | Purpose |
|---|---|
| `--serial <hex>` | Revoke a single cert by its hex serial number (as shown in `cert list`). Default: revoke ALL of the user's certs |

Revocation takes effect immediately — the running broker hot-reloads the
revocation list and rejects the next request from that cert with HTTP 403.

```bash
dblm server cert revoke alice                                    # all of alice's certs
dblm server cert revoke alice --serial 1e799b2d76bbe567...       # one specific cert
```

### `dblm server audit`

Show recent broker activity.

```bash
dblm server audit [--user <name>] [--connection <name>] [--limit <n>]
```

| Flag | Default | Purpose |
|---|---|---|
| `--user <name>` | — | Filter by user |
| `--connection <name>` | — | Filter by connection |
| `--limit <n>` | 50 | Max rows to show |

The audit log records every authenticated request with timestamp, user,
operation, connection, row count, duration, and error. Operations recorded:

| Op | What it is |
|---|---|
| `query` | Buffered SQL via `/v1/query` |
| `stream` | NDJSON-streamed SQL via `/v1/query/stream` |
| `tables` | Schema fetch via `/v1/tables` |
| `nlq` | Natural-language query via `/v1/nlq` (logs the question, not the generated SQL) |
| `knowledge` | Knowledge doc fetch via `/v1/knowledge` |
| `module-list` | Module list via `/v1/modules` |
| `module-get` | Module fetch via `/v1/modules/{name}` |

---

## Worker mode commands (`dblm remote`)

These manage the worker's saved master endpoints. They are worker-only by
nature.

```bash
dblm remote add <alias> --bundle <path> [--endpoint <url>]
dblm remote list                                   # alias: ls
dblm remote remove <alias>
dblm remote test [--alias <alias>]
dblm remote whoami [--alias <alias>]
dblm remote connections [--alias <alias>]          # alias: conns
```

The `dblm remote` subtree has a global `--alias` flag. When only one remote is
registered, you can omit `--alias` and it picks the only one.

### `dblm remote add <alias>`

Register a master endpoint under a short alias. The bundle is the JSON file the
admin gave you (produced by `dblm server user add`).

| Flag | Required | Purpose |
|---|---|---|
| `--bundle <path>` | yes | Path to the user bundle file |
| `--endpoint <url>` | no | Override the endpoint URL embedded in the bundle |

```bash
dblm remote add prod --bundle alice.bundle.json
dblm remote add staging --bundle alice-staging.bundle.json
dblm remote add ci --bundle alice.bundle.json --endpoint https://ci-master.example.com:8443
```

### `dblm remote list` / `ls`

List every registered remote.

### `dblm remote remove <alias>`

Forget a remote. Local-only — does not contact the master.

### `dblm remote test`

Test connectivity by hitting `/v1/health` on the master.

```bash
dblm remote test                # only-one remote: alias inferred
dblm remote test --alias prod
```

### `dblm remote whoami`

Ask the master who it thinks you are. Returns the username, the connections
you're allowed to use, and your read-only flag.

```bash
dblm remote whoami --alias prod
# user:        alice
# connections: lite, pg
# read-only:   true
```

### `dblm remote connections` / `conns`

List the connections the master grants you, with driver and mode.

```bash
dblm remote connections --alias prod
# NAME  DRIVER    MODE
# lite  sqlite    ro
# pg    postgres  ro
```

---

## Worker mode via `--remote` flag

The preferred way for a worker to do real work. The same commands you'd run
locally, just with `--remote <alias>` to route through a master.

### `dblm query --remote <alias>`

Run a natural-language query through the master. The master holds the LLM key,
the schema index, and the DSNs. The worker just sends the question.

```bash
# Plain NLQ — master uses every connection you're granted
dblm query "show me top revenue accounts" --remote prod

# Scoped to specific connections
dblm query "join orders and customers" --remote prod --db pg,lite

# Scoped to one connection
dblm query "list 5 artists that start with A" --remote prod --db lite

# Module-mode NLQ
dblm query "revenue by region last quarter" --remote prod --module sales

# Raw SQL (no LLM at all — pure passthrough)
dblm query "SELECT Name FROM Artist LIMIT 5" --remote prod --db lite --raw

# Combine with --json for piping to other tools
dblm query "SELECT * FROM Genre" --remote prod --db lite --raw --json

# Stream a huge result set — neither side buffers, rows arrive one at a time
dblm query "SELECT * FROM events" --remote prod --db ch --raw --stream

# Stream as NDJSON (one JSON object per row), pipe into jq or any line-aware tool
dblm query "SELECT * FROM events" --remote prod --db ch --raw --stream --json

# Skip summarization (faster, fewer master-side LLM tokens)
dblm query "..." --remote prod --no-summary

# Always summarize (use carefully — large results may overflow tokens)
dblm query "..." --remote prod --force-summary

# Inject user context (e.g., to scope results to the requesting user)
dblm query "show me my recent orders" --remote prod --context "current user email: alice@example.com"
```

> **`--stream` rules:** requires `--raw` (no LLM planning to stream), requires
> `--remote` (worker-only), and requires exactly one `--db` target. Mutually
> exclusive with `--module`.

What runs where:

| Step | Where |
|---|---|
| TLS handshake (mTLS) | Worker ↔ Master |
| Schema lookup from index | Master |
| Knowledge injection | Master |
| LLM call to Claude | Master |
| SQL validation (read-only) | Master |
| SQL execution against the DB | Master |
| Result summarization | Master |
| Print to terminal | Worker |

### `dblm schema --remote <alias>`

Inspect schemas through the master.

```bash
# All connections you're granted
dblm schema --remote prod

# One connection
dblm schema --remote prod --db lite

# Specific format
dblm schema --remote prod --db lite --format ddl
dblm schema --remote prod --db lite --format json

# Filter to one table
dblm schema --remote prod --db lite --table Artist
```

### `dblm knowledge show <conn> --remote <alias>`

Fetch the master's knowledge document for a connection. Requires the
`--with-knowledge` ACL bit on the user's grant.

```bash
dblm knowledge show lite --remote prod
dblm knowledge show lite --remote prod --json
```

If you don't have the bit, the master returns `403 user does not have
--with-knowledge on <conn>`.

### `dblm module list --remote <alias>`

List modules visible to you. Strict ACL: a module is shown only when you have
grants on every connection it references.

```bash
dblm module list --remote prod
```

### `dblm module show <name> --remote <alias>`

Show one module's full table list. Same strict ACL applies.

```bash
dblm module show sales --remote prod
```

### `dblm fassad run <name> --remote <alias>`

Run a fassad template through the master. SQL fassads are sent as raw queries
(the master skips LLM planning). NLQ fassads use the master's LLM pipeline.

```bash
# SQL fassad via remote
dblm fassad run daily-sales --date 2024-01-15 --remote prod

# NLQ fassad via remote
dblm fassad run cross-db-report --year 2024 --remote prod

# With JSON output
dblm fassad run daily-sales --date 2024-01-15 --remote prod --json
```

---

## Removed commands

The following used to exist as direct subcommands but were removed in favor of
the unified `--remote` flag. There is now exactly one way to do each thing.

| Old (removed) | Replacement |
|---|---|
| `dblm remote query <conn> "<sql>"` | `dblm query "<sql>" --remote <alias> --db <conn> --raw` |
| `dblm remote query <conn> "<sql>" --stream` | `dblm query "<sql>" --remote <alias> --db <conn> --raw --stream` |
| `dblm remote tables <conn>` | `dblm schema --remote <alias> --db <conn>` |

If you have scripts using the old forms, update them — they're gone, not just
hidden.

---

## Configuration paths

| Path | What |
|---|---|
| `~/.dblm/config.json` | Connections + API key + provider settings |
| `~/.dblm/index.db` | Schema cache |
| `~/.dblm/knowledge.db` | Generated/edited schema docs |
| `~/.dblm/module.db` | Module definitions |
| `~/.dblm/fassad.db` | Fassad (query template) definitions |
| `~/.dblm/memory/` | Session + history stores (per-user) |
| `~/.dblm/server/` | Master PKI material (CA, server cert) |
| `~/.dblm/server/users.json` | Users + grants + cert revocation set |
| `~/.dblm/server/audit.db` | Broker audit log |
| `~/.dblm/remotes.json` | Worker-side registered remotes |

> **Worker tip:** if you only use dblm as a worker (always with `--remote`), you
> need none of the local state above except `~/.dblm/remotes.json`. No API key,
> no index, no knowledge, no DSNs.

## Testing

```bash
go test ./...
```

The broker has a 45-test suite covering the read-only SQL classifier, the user
store (cert tracking, revocation, hot reload), and full HTTP/2 + mTLS round
trips against a real in-process server with a real CA, real cert issuance, and
a real SQLite database — no mocks. See `internal/broker/*_test.go`.

## Repository layout

```
dblm/
├── main.go
├── cmd/                  # cobra subcommands
│   ├── connect.go
│   ├── fassad.go
│   ├── history.go
│   ├── index.go
│   ├── knowledge.go
│   ├── module.go
│   ├── query.go
│   ├── remote.go         # worker side of the broker
│   ├── root.go
│   ├── schema.go
│   ├── server.go         # master side of the broker
│   └── session.go
└── internal/
    ├── broker/           # master/worker broker (Phase 1-5)
    ├── config/           # config file & API key resolution
    ├── db/               # driver registry + per-DB drivers
    ├── engine/           # NLQ planner, fan-out, retry, summarization
    ├── fassad/           # reusable parameterized query templates
    ├── history/          # turn recording, vector search, sessions
    ├── knowledge/        # knowledge store
    ├── knowledge_gen/    # auto-generation via LLM
    ├── knowledge_web/    # browser-based editor
    ├── llm/              # Claude / Ollama API client
    ├── merge/            # multi-result merging
    ├── module/           # cross-database table groups
    ├── schema/           # schema introspection helpers
    ├── sqlsplit/         # safe SQL statement splitting
    ├── store/            # schema index store
    ├── summary/          # result summarization
    └── tui/              # terminal output formatting
```

---

## Quick recipes

### Brand-new master setup

```bash
# 1. Configure local connections
dblm connect add pg   --driver postgres --dsn "postgres://user:pass@localhost:5432/?sslmode=disable"
dblm connect add lite --driver sqlite   --dsn "./chinook.db"

# 2. Index their schemas
dblm index add pg
dblm index add lite

# 3. Generate knowledge docs (optional, improves NLQ quality)
dblm knowledge auto --all

# 4. Set up the broker
export DBLM_ANTHROPIC_API_KEY="sk-ant-..."
dblm server init --cn dblm-master --sans "your-host.example.com,127.0.0.1"

# 5. Create a user
dblm server user add alice \
  --endpoint https://your-host.example.com:8443 \
  --out alice.bundle.json

# 6. Grant access
dblm server acl grant alice pg   --read-only --with-knowledge
dblm server acl grant alice lite --read-only

# 7. Start the broker
dblm server start --listen :8443
```

Send `alice.bundle.json` to alice.

### Brand-new worker setup

```bash
# 1. Register the bundle the admin gave you
dblm remote add prod --bundle ./alice.bundle.json

# 2. Plumbing checks
dblm remote test
dblm remote whoami
dblm remote connections

# 3. Pick one connection and inspect its schema
dblm schema --remote prod --db lite

# 4. Try a real NLQ
dblm query "show me a sample of the largest table" --remote prod
```

Worker needs no API key, no schema index, no DSNs.

### Multi-master worker

```bash
# Register several masters under different aliases
dblm remote add prod      --bundle alice-prod.bundle.json
dblm remote add staging   --bundle alice-staging.bundle.json
dblm remote add analytics --bundle alice-analytics.bundle.json

# Switch between them with --remote
dblm query "..." --remote prod
dblm query "..." --remote staging
dblm query "..." --remote analytics

dblm schema --remote prod --db lite
dblm schema --remote staging --db lite
```

### Daily admin loop on the master

```bash
# Add a new user
dblm server user add bob --out bob.bundle.json
dblm server acl grant bob lite --read-only --with-knowledge

# Check who's been doing what
dblm server audit --limit 100
dblm server audit --user alice
dblm server audit --connection lite

# Rotate a compromised cert
dblm server cert revoke alice
dblm server user add alice --out alice-new.bundle.json
dblm server acl grant alice lite --read-only --with-knowledge

# Check the cert state
dblm server cert list
dblm server user list
```

The broker hot-reloads the user store, so all of these take effect immediately
without restarting `dblm server start`.

### Refreshing schema after a database migration

```bash
dblm index refresh pg                # re-pulls schema, marks knowledge stale
dblm knowledge auto pg               # regenerate knowledge with the new schema
```

Knowledge is auto-marked stale on `index refresh` so dblm warns you the next
time you query that the docs may be out of date.

### Creating and using a fassad (parameterized query template)

```bash
# 1. Create a SQL fassad with two parameters
dblm fassad create daily-orders --mode sql --conn myshop/orders \
  --body "SELECT * FROM orders WHERE order_date = '{date}' AND status = '{status}'" \
  --param date:string:required --param status:string:default=pending

# 2. List fassads
dblm fassad list

# 3. Inspect the fassad
dblm fassad show daily-orders

# 4. Run it with parameters
dblm fassad run daily-orders --date 2024-01-15
dblm fassad run daily-orders --date 2024-01-15 --status completed

# 5. Create an NLQ fassad for cross-database reporting
dblm fassad create revenue-report --mode nlq --module sales \
  --body "show me revenue by region for {year}" \
  --param year:int:required

# 6. Run the NLQ fassad
dblm fassad run revenue-report --year 2024

# 7. Run via remote master
dblm fassad run daily-orders --date 2024-01-15 --remote prod
```

### Starting a conversation session

```bash
# 1. Start a named session
dblm session start customer-analysis

# 2. Ask follow-up questions (the LLM sees prior turns for context)
dblm query "how many active users?" --db pg/testdb
dblm query "show me their emails"    # "their" resolves via session context
dblm query "filter those to just NYC"

# 3. End the session
dblm session end

# 4. Resume it later
dblm session continue customer-analysis

# 5. Search history for past queries
dblm history search "customer churn"
dblm history list --last 20
dblm history stats
```

---

## When in doubt

Every command has `--help`:

```bash
dblm --help
dblm query --help
dblm server cert revoke --help
```

If a command supports `--remote`, the help text says so. If it doesn't, it's
local-only by design.

## License

MIT