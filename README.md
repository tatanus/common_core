# common_core
# Project Badges

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Build Status](https://github.com/tatanus/common_core/actions/workflows/main.yml/badge.svg)](https://github.com/tatanus/common_core/actions/workflows/main.yml)
[![Last Commit](https://img.shields.io/github/last-commit/tatanus/BASH)](https://github.com/tatanus/common_core/commits/main)

![Bash >=4.0](https://img.shields.io/badge/Bash-%3E%3D4.0-4EAA25?logo=gnu-bash&logoColor=white)

**common_core** is the single, shared Bash **core** for these related projects:

- **BASH_SETUP* – “ sets up a Bash environment (standalone)
- **PENTEST_SETUP** – “ installs pentest tooling (standalone or paired with BASH_SETUP)
- **PENTEST_MENU** – “ menu-driven pentest automations (**requires PENTEST_SETUP**)

This repository centralizes all reusable code (bootstrap, logging, safe sourcing, menus, and generic utilities) so the overlays don’t duplicate logic or drift out of sync.

---

## Key ideas

- **Single source of truth:* All shared Bash libraries live here and are versioned once.
- **Thin overlays:* Each project keeps only its own `config/` and optional `tasks/` plugins: it calls a tiny wrapper that delegates to core.
- **deterministic:* Overlays pin a specific core version (via submodule or subtree).
- **Consistent UX:** Shared bootstrap, menus, logging, and error handling across all projects.

---

## Requirements

- **Bash** 4.0+ (Linux) or system Bash on macOS (recommended: brew `bash`)
- Standard Unix utilities (`awk`, `sed`, `grep`, `tput`, `ls`, etc.)
- **git** (for submodules/subtrees)
- Optional package managers: `apt`, `brew` (consumed by utils if present)

---

## 📅 Authorship & Licensing

**Author**: Adam Compton  
**Date Created**: August 18, 2025 
This script is provided under the [MIT License](./policy/LICENSE). Feel free to use and modify it for your needs.
