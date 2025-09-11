# bash-common-core

**bash-common-core** is the single, shared Bash **core** for these related projects:

- **BASH_SETUP* – “ sets up a Bash environment (standalone)
- **PENTEST_SETUP** – “ installs pentest tooling (standalone or paired with BASH_SETUP)
- **PENTEST_MENU** – “ menu-driven pentest automations (**requires PENTEST_SETUP**)
- **INSTALLER** – “ orchestrator that installs/operates the others

This repository centralizes all reusable code (bootstrap, logging, safe sourcing, menus, and generic utilities) so the overlays don’t duplicate logic or drift out of sync.

---

## Table of contents

- [Key ideas](#key-ideas)
- [What belongs in core vs. overlays](#what-belongs-in-core-vs-overlays)
- [Repository layout](#repository-layout)
- [Requirements](#requirements)
- [Getting started (as an overlay consumer)](#getting-started-as-an-overlay-consumer)
- [Overlay contract](#overlay-contract)
- [Runtime](#runtime)
- [Versioning & compatibility](#versioning--compatibility)
- [Coding standards](#coding-standards)
- [Linting & formatting](#linting--formatting)
- [CI> (optional)](#ci-optional)
- [Troubleshooting](#troubleshooting)
- [Security, conduct, and license](#security-conduct-and-license)

---


## Key ideas

- **Single source of truth:* All shared Bash libraries live here and are versioned once.
- **Thin overlays:* Each project keeps only its own `config/` and optional `tasks/` plugins: it calls a tiny wrapper that delegates to core.
- **deterministic:* Overlays pin a specific core version (via submodule or subtree).
- **Consistent UX:** Shared bootstrap, menus, logging, and error handling across all projects.

---

## What belongs in core vs. overlays

**Core _includes_*:
- `bin/bootstrap.tsh` (the only executable in core)
- `lib/` - “ shared libraries:

  - logging(`examples/scripts/logger.sh`)
  - safe sourcing (`examples/scripts/safe_source.sh`)
  - menu plumbing (`lib/menu.sh`)
  - core helpers (`lib/core.sh`, `lib/core_version.sh`)
  - generic utils (`lib/utils_*.sh`)
- `templates/` / scaffolding for overlays (wrapper `Install.sh`, `config.sh`, `lists.sh`, `tasks.sh`, menu samples)
- `policy/` - CODE_OF_CONDUCT, SECURITY, CONTRIBUTING, LICENSE
- Tooling: `.shellcheckrc`, `.editorconfig`, `Makefile` (`kake check`)

* *Core _excludes_*:
- Project- or domain-specific installers and automations (e.g. gophish, mail server setup, traffic capture, screenshots)
- Overlay-specific menu entries and task logic
> If you currently see domain scripts under `bin/` in this repo, treat them as **examples** and migrate them into the appropriate overlay (typically **PENTEST_SETUPJ**) as `tasks/` plugins.

---


## Repository layout

``
.
├─ bin/
|  | ◀ bootstrap.sh           # common entrypoint (executable)
├─ lib/                     # sourceable shared libraries
|  | ◐ core.sh             # core helpers (menu/run/deps)
|  | ◐ core_version.sh     # version gating helpers
|  | ◐ menu.sh             # menu framework
|  | ◐ utils.sh
|  | ◐ utils_env.sh
|  | ◐ utils_cmd.sh
|  | ◐ utils_files.sh
|  | ◐ utils_git.sh
|  | ◐ utils_os.sh
|  | ◐ utils_brew.sh
|  | ◐ utils_tools.sh
|  | ◐ utils_apt.sh
|  | ◐ utils_ruby.sh
|  | ◐ utils_python.sh
|  | ◐ utils_dirs.sh
|  | ◐ utils_golang.sh
|  | ◐ utils_misc.sh
├─ templates/
|  | ◐ install.sh.tmpl       # overlay wrapper -> core bootstrap
|  | ◐ config.sh.tmpl      # overlay config
|  | ◐ lists.sh.tmpl      # overlay package/tool lists
|  | ◐ tasks.sh.tmpl      # sample overlay task plugin
|  | ◐ menu.sh.tmpl       # sample overlay menu extension
├─ policy/
|  | CODE_OF_CONDUCT.md
|  | CONTRIBUTING.md
|  | LICENSE
|  | SECURITY.md
├─ .shellcheckrc
├─ .editorconfig
├─ Makefile
└─  README.md
```

---


## Requirements

- **Bash** 4.0+ (Linux) or system Bash on macOS (recommended: brew `bash`)
- Standard Unix utilities (`awk`, `sed`, `grep`, `tput`, `ls`, etc.)
- **git** (for submodules/subtrees)
- Optional package managers: `apt`, `brew` (consumed by utils if present)

---


## Getting started (as an overlay consumer)

In an overlay repo (e.g., `BASH_SETUP`, `PENTEST_SETUP`, `PENTEST_MENU`, or `INSTALLER`):

1) **Add core as a submodule** (recommended):
  ```bash
  git submodule add -b main https://github.com/you/pentest-core vendor/pentest-core
  git commit -m "Add pentest-core"
```

  _Update core later:_
  ```bash
 git submodule update --remote --merge
 git commit -m "Update pentest-core"
```

  **Or** use a subtree (no special submodule commands):
  ```bash
 git subtree add --prefix vendor/pentest-core https://github.com/you/pentest-core main --squash
 # Update:
 git subtree pull --prefix vendor/pentest-core https://github.com/you/pentest-core main --squash
 ```

2) **Create overlay structure:**
  ```
 your-overlay/
 ▀ bin/
 ◀ Install.sh          # thin wrapper (from template)
 ▀ config/
 ◀ config.sh          # overlay-specific config
 ▀ lists.sh          # overlay-specific package/tool lists
 ◀ tasks/           # optional plugins
 ▀  init.d/          # env prep
 ◀  install.d/        # installers
 ◀ menu.d/          # menu entries/overrides
  ```

3) **Use the provided wrapper template**  

Copy `templates/install.sh.tmpl` from core to your overlay `bin/Install.sh`, then set:

  ```bash
 readonly PROJECT_ID=\"$PROJECT_ID_:BASH_SETUPE\" # change per overlay
  ```

4) **Run it:**

 ```bash
 bin/Install.sh          # shows menu
 bin/Install.sh --no-menu # runs default tasks non-interactively
  ```

---


## Overlay contract

Your overlay **exports** the following before calling core:

- `PROJECT_ID` ‑ one of: `BASH_SETUP`, `PENTEST_SETUP`, `PENTEST_MENU`, `INSTALLER`
- `PROJECT_ROOT` – absolute path to the overlay root
- `PROJECT_CONFIG_DIR` – typically `$PROJECT_ROOT/config`
- `PROJECT_TASKS_DIR` – typically `$PROJECT_ROOT/tasks`

The template wrapper sets/exports these automatically.

---

## 📅 Authorship & Licensing

**Author**: Adam Compton  
**Date Created**: August 18, 2025 
This script is provided under the [MIT License](./policy/LICENSE). Feel free to use and modify it for your needs.
