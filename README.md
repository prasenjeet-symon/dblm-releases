# dblm releases

This repository hosts the official pre-built binaries for [dblm](https://github.com/prasenjeet-symon/dblm) — a single-binary CLI that lets you talk to your databases in plain English.

Supports Postgres, MySQL, SQLite, MongoDB, and ClickHouse.

---

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

Download the binary for your platform from the [latest release](https://github.com/prasenjeet-symon/dblm-releases/releases/latest):

| Platform | File |
|---|---|
| macOS (Apple Silicon) | `dblm_*_darwin_arm64.tar.gz` |
| macOS (Intel) | `dblm_*_darwin_x86_64.tar.gz` |
| Linux (x86-64) | `dblm_*_linux_x86_64.tar.gz` |
| Linux (ARM64) | `dblm_*_linux_arm64.tar.gz` |
| Windows (x86-64) | `dblm_*_windows_x86_64.zip` |
| Windows (ARM64) | `dblm_*_windows_arm64.zip` |

### Verify installation

```sh
dblm version
```

---

## Getting started

**1. Activate your license**
```sh
dblm license activate <your-license-key>
```

**2. Configure your LLM provider**
```sh
export ANTHROPIC_API_KEY=sk-ant-...
```
Or use Ollama:
```sh
export DBLM_LLM_PROVIDER=ollama
export OLLAMA_API_KEY=<your-key>
export OLLAMA_BASE_URL=https://ollama.com/v1
```

**3. Add a database connection**
```sh
dblm connect add mydb --driver postgres --dsn "postgres://user:pass@localhost:5432/"
```

**4. Index the schema**
```sh
dblm index add mydb
```

**5. Generate knowledge docs (optional, improves query quality)**
```sh
dblm knowledge auto mydb
```

**6. Start querying**
```sh
dblm query "how many users signed up this month" --db mydb
```

**7. Install the Claude Code skill (optional)**
```sh
dblm skill install
```

Saves a `AGENT.md` in the current directory. Claude Code picks it up automatically,
giving it full context to run `dblm` commands and query your databases in plain English.

---

## Supported databases

- PostgreSQL
- MySQL / MariaDB
- SQLite
- MongoDB
- ClickHouse

---

## Releases

| Version | Date | Notes |
|---|---|---|
| [v1.1.0](https://github.com/prasenjeet-symon/dblm-releases/releases/tag/v1.1.0) | 2026-05-27 | |
| [v1.0.7](https://github.com/prasenjeet-symon/dblm-releases/releases/tag/v1.0.7) | 2026-05-24 | |
| [v1.0.6](https://github.com/prasenjeet-symon/dblm-releases/releases/tag/v1.0.6) | 2026-05-24 | Batched knowledge generation for large schemas (100+ tables); fixes for silent load errors, empty-schema guard, and module knowledge warnings |
| [v1.0.5](https://github.com/prasenjeet-symon/dblm-releases/releases/tag/v1.0.5) | 2026-05-23 | |
| [v1.0.4](https://github.com/prasenjeet-symon/dblm-releases/releases/tag/v1.0.4) | 2026-05-23 | |
| [v1.0.3](https://github.com/prasenjeet-symon/dblm-releases/releases/tag/v1.0.3) | 2026-05-23 | |
| [v1.0.1](https://github.com/prasenjeet-symon/dblm-releases/releases/tag/v1.0.1) | 2026-05-23 | Initial public release |

---

## Links

- [Source code & full documentation](https://github.com/prasenjeet-symon/dblm)
- [Report an issue](https://github.com/prasenjeet-symon/dblm/issues)
