# dblm releases

This repository hosts the official pre-built binaries for [dblm](https://github.com/prasenjeet-symon/dblm) — a single-binary CLI that lets you talk to your databases in plain English.

Supports Postgres, MySQL, SQLite, MongoDB, and ClickHouse.

---

## Install

### macOS / Linux (recommended)

```sh
curl -sSL https://raw.githubusercontent.com/prasenjeet-symon/dblm-releases/main/install.sh | sh
```

This auto-detects your OS and architecture, downloads the correct binary, and installs it to `/usr/local/bin/dblm`.

### Manual download

Download the binary for your platform from the [latest release](https://github.com/prasenjeet-symon/dblm-releases/releases/latest):

| Platform | File |
|---|---|
| macOS (Apple Silicon) | `dblm_*_darwin_arm64.tar.gz` |
| macOS (Intel) | `dblm_*_darwin_x86_64.tar.gz` |
| Linux (x86_64) | `dblm_*_linux_x86_64.tar.gz` |
| Linux (ARM64) | `dblm_*_linux_arm64.tar.gz` |
| Windows (x86_64) | `dblm_*_windows_x86_64.zip` |
| Windows (ARM64) | `dblm_*_windows_arm64.zip` |

Extract and move the binary to a directory in your `$PATH`:

```sh
tar -xzf dblm_*_darwin_arm64.tar.gz
mv dblm /usr/local/bin/
```

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
dblm config
```
Or set an environment variable:
```sh
export ANTHROPIC_API_KEY=sk-ant-...
```

**3. Add a database connection**
```sh
dblm connect add mydb --driver postgres --dsn "postgres://user:pass@localhost:5432/"
```

**4. Index the schema**
```sh
dblm index add mydb --db mydb_name
```

**5. Start querying**
```sh
dblm query "how many users signed up this month" --db mydb
```

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
| [v1.0.1](https://github.com/prasenjeet-symon/dblm-releases/releases/tag/v1.0.1) | 2026-05-23 | Initial public release |

---

## Links

- [Documentation](https://github.com/prasenjeet-symon/dblm-releases/releases/latest)
- [Report an issue](https://github.com/prasenjeet-symon/dblm-releases/issues)
