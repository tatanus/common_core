# common_core

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![CI](https://github.com/tatanus/common_core/actions/workflows/main.yml/badge.svg)](https://github.com/tatanus/common_core/actions/workflows/main.yml)
[![Last Commit](https://img.shields.io/github/last-commit/tatanus/common_core)](https://github.com/tatanus/common_core/commits/master)

![Bash >=4.0](https://img.shields.io/badge/Bash-%3E%3D4.0-4EAA25?logo=gnu-bash&logoColor=white)

---

## Overview

`common_core` is the shared Bash utility library that every other repo in
this stack depends on. It provides a single loader (`lib/util.sh`) that
sources a dependency-ordered set of modules under `lib/utils/` — string,
file, directory, command, environment, OS, platform, trap, logging,
package-manager (`apt`, `brew`), and language-runtime (`py`, `ruby`, `go`)
helpers, plus a TUI/menu layer and an HTTP/Git/Net layer. Every module
ships a `::self_test` function and has 1:1 documentation under `docs/`.

It is the foundation of the five-repo stack:

```
common_core  →  bash_setup  →  scripts  →  pentest_setup  →  pentest_menu
```

Downstream repos source `~/.config/bash/lib/common_core/util.sh` as a
hard dependency. There are **no submodules** — `common_core` is a
system-install, not a vendored copy.

---

## Requirements

- **Bash 4+** (macOS users: `brew install bash`)
- POSIX coreutils
- Recommended for development:
  - `shellcheck` (lint)
  - `shfmt` (format) — must support `-i 4 -ci -sr`
  - `bats` (test)

---

## Quick Start

```bash
git clone https://github.com/tatanus/common_core.git
cd common_core
./install.sh                    # default: install to ~/.config/bash/lib/common_core
./install.sh -d ~/.local/lib    # custom location
./install.sh -f                 # update over an existing install without prompting
./install.sh -n                 # dry-run: report what would happen
./install.sh -v                 # print version and exit
./install.sh -h                 # full help
```

`install.sh` copies `lib/` into the install directory, writes a `VERSION`
marker alongside it, sets executable permissions, configures `~/.bashrc`
to source the library on shell start, and runs the self-tests
(`--skip-tests` to skip). It refuses to install to system directories
(`/`, `/usr`, `/etc`, …) and creates backups when updating an existing
installation. When it detects a prior install (via that `VERSION` marker)
and is run interactively, it prompts before overwriting; `-f`/`--force`
skips the prompt (a non-interactive run proceeds without asking).

Source the library from your own script:

```bash
#!/usr/bin/env bash
source "${HOME}/.config/bash/lib/common_core/util.sh"
# all modules are now loaded in dependency order, with logging silenced
```

---

## Tool & system helper scripts

Three optional, standalone scripts sit alongside `install.sh`. Each is a
single responsibility and each is **OS-aware** — it detects the host and
never runs package-manager or filesystem operations that do not apply.

| Script | Platform | What it does |
|--------|----------|--------------|
| `install_tools.sh`      | Linux **and** macOS | Installs (or `--check`s) the external commands the whole stack shells out to but does not ship — `git`, `jq`, `eza`, `fzf`, `bat`/`batcat`, `ncat`, `shellcheck`, `shfmt`, `freeze`, etc. Picks the package manager from the OS (apt on Debian/Kali, Homebrew on macOS), and only touches tools relevant to that OS — the GNU `g*` tools install on macOS only, `xclip`/`wl-paste` on Linux only. On Debian/Kali it also configures the signed eza-community apt repository (since `eza` is not in the base repos) before installing `eza`. |
| `system_maintenance.sh` | Debian/Kali only    | System upkeep, **not** tool install: `apt update && apt upgrade`, sweep of stale `/pentest/*` checkouts, `apt` cleanup, and a disk-usage report. Phase flags: `--no-upgrade`, `--no-sweep`, `--no-cleanup`. |

```bash
./install_tools.sh --check          # audit what is missing (no privileges)
./install_tools.sh --list           # print the full tool table, marking OS-skipped rows
sudo ./install_tools.sh             # Debian/Kali: install everything applicable
./install_tools.sh                  # macOS: install everything applicable (no sudo)
sudo ./system_maintenance.sh        # Debian/Kali: patch + tidy the box
```

Each supports `-n/--dry-run`, honors a `PROXY` prefix (auto-detected, or set
via `--proxy`/`--no-proxy`), and refuses with a clear message on an
unsupported platform rather than failing mid-run.

---

## Repository Layout

```
.
├── install.sh                  # one-shot installer (deploys lib/ to ${HOME}/.config/bash/lib/common_core/)
├── install_tools.sh            # OS-aware external-tool bootstrapper (apt + Homebrew; sets up the eza-community apt repo on Debian/Kali)
├── system_maintenance.sh       # apt-only: apt upgrade, stale /pentest/* sweep, cleanup
├── Makefile                    # quality gates + release automation
├── VERSION                     # date-based version: YYYY.MM.DD.N
├── CHANGELOG.md                # Keep a Changelog
├── lib/
│   ├── util.sh                 # main loader (sources every util_*.sh in dependency order)
│   ├── logger.sh               # info/warn/error/debug/pass/fail (stderr only)
│   ├── API.yaml                # exported-function catalog
│   └── utils/
│       ├── util_platform.sh    # Linux / macOS / WSL detection + abstraction
│       ├── util_config.sh      # centralized, validated config
│       ├── util_trap.sh        # signal + cleanup management
│       ├── util_str.sh         # string helpers
│       ├── util_env.sh         # env var helpers
│       ├── util_cmd.sh         # command existence + execution
│       ├── util_file.sh        # safe file ops (path validation, backups)
│       ├── util_dir.sh         # directory helpers
│       ├── util_os.sh          # OS-specific ops
│       ├── util_tui.sh         # terminal UI helpers
│       ├── util_menu.sh        # interactive menus
│       ├── util_net.sh         # network helpers
│       ├── util_curl.sh        # HTTP request wrappers
│       ├── util_git.sh         # Git ops
│       ├── util_apt.sh         # Debian/Ubuntu package management
│       ├── util_brew.sh        # macOS package management
│       ├── util_py.sh          # Python env / pip helpers
│       ├── util_py_multi.sh    # multi-version Python helpers
│       ├── util_ruby.sh        # Ruby / Gem helpers
│       ├── util_go.sh          # Go toolchain helpers
│       └── util_tools.sh       # external-tool registry + install helpers
├── docs/                       # one Markdown file per util_*.sh module + API.md + ROADMAP.md
├── examples/                   # basic_usage.sh, config_example.sh, logging_example.sh
├── config/                     # example .conf files for util_config.sh
├── tests/
│   ├── unit/                   # BATS unit tests (108 passing)
│   ├── integration/
│   ├── helpers/
│   ├── fixtures/
│   ├── run_tests.sh            # legacy harness
│   └── run_self_tests.sh       # runs every module's `::self_test`
└── tools/
    ├── check_bash_style.sh     # comprehensive style scan (function form, backtick ban, …)
    ├── check_docs.sh           # verify docs/ stays in sync with lib/
    ├── lint.sh                 # shellcheck wrapper
    ├── format.sh               # shfmt wrapper
    ├── test.sh                 # bats wrapper
    └── update.sh               # local in-place update helper
```

---

## Make targets

| Target               | What it does                                                     |
|----------------------|------------------------------------------------------------------|
| `make help`          | Show all targets.                                                |
| `make ci`            | Format check + lint + tests. **Non-mutating. Run before PRs.**   |
| `make fmt`           | Auto-format with `shfmt -i 4 -ci -sr` (writes in place).         |
| `make fmt-check`     | Verify formatting without writing.                               |
| `make lint`          | `shellcheck -x` across `git ls-files '*.sh'`.                    |
| `make test`          | `bats -r tests`.                                                 |
| `make style`         | Comprehensive style scan via `tools/check_bash_style.sh`.        |
| `make check-docs`    | Verify `docs/` 1:1 with `lib/utils/`.                            |
| `make install`       | `bash install.sh` — deploy `lib/` to `~/.config/bash/lib/common_core/`. |
| `make show-version`  | Print current `VERSION`.                                         |
| `make release V=…`   | Cut a release (see [Releases](#releases)).                       |
| `make release-today` | Cut a release using today's UTC date (`YYYY.MM.DD.0`).           |

The mandated formatter flags are **`-i 4 -ci -sr`**. Do not add `-bn` or
`-kp` anywhere.

---

## Cross-repo contract

- **Depends on**: nothing. `common_core` is the root of the load chain.
- **Installed at**: `~/.config/bash/lib/common_core/`. This path is the
  hard dependency every downstream repo expects. **Not vendored as a
  submodule** in any downstream repo, despite some historical
  references to one in old docs / Makefiles.
- **Provides for the rest of the stack**:
  - `lib/util.sh` — single sourceable entry point.
  - Namespaced helpers: `str::`, `file::`, `dir::`, `cmd::`, `env::`,
    `os::`, `platform::`, `net::`, `curl::`, `git::`, `apt::`, `brew::`,
    `py::`, `ruby::`, `go::`, `trap::`, `tui::`, `menu::`, `tools::`.
  - Fallback log functions (`info` / `warn` / `error` / `debug` /
    `pass` / `fail`) that downstream installers reuse before their own
    loggers come online.

Downstream repos (`bash_setup`, `scripts`, `pentest_setup`,
`pentest_menu`) all source the installed copy directly — they never
clone `common_core` into themselves.

---

## Releases

Date-based four-part versioning (`YYYY.MM.DD.N`), tracked in `VERSION`
and `CHANGELOG.md`. To cut a release:

```bash
# 1. Land your changes as normal commits with `## [Unreleased]` notes.
git add …; git commit -m "feat(…): …"; git push

# 2. Cut the release. `make release` will:
#    - run `make ci` (refuse if anything fails)
#    - refuse on a dirty working tree
#    - stamp `## [Unreleased]` -> `## [Vx] - YYYY-MM-DD` (UTC) in CHANGELOG
#    - write VERSION
#    - single commit `chore(release): cut Vx`
#    - annotated tag `vVx`
#    - `git push --follow-tags`
make release-today          # today's UTC date.0
make release-today N=1      # second cut of the same UTC day -> .1
make release V=2026.06.27.0 # explicit version
```

---

## Style conventions

- Bash 4+, `set -uo pipefail`, `IFS=$'\n\t'`.
- `function name() { ... }` form (not bare `name()`).
- No `eval` in user-facing APIs, no `set -e`, no unquoted expansions.
- Source-guard idiom (`if [[ -z "${X_LOADED:-}" ]]; then … fi`) prevents
  double-sourcing.
- Data-producing functions emit to stdout only; logging always goes to
  stderr.

See [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md) for the full
contribution / style guide.

---

## License

MIT — see [LICENSE](LICENSE).
