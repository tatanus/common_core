# util.sh - Core Utility Loader

The core module that initializes the utility framework, defines global constants, provides logging fallbacks, and loads all `util_*.sh` modules in dependency order.

## Overview

`util.sh` is the entry point for the entire utility library. When sourced, it:

1. Sets strict mode (`set -uo pipefail`)
2. Defines global constants (`PASS`, `FAIL`)
3. Provides logging function fallbacks
4. Loads all utility modules in the correct dependency order

## Usage

```bash
#!/usr/bin/env bash
source /path/to/util.sh

# All modules are now available
file::exists "/path/to/file"
cmd::run some_command
```

## Global Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `PASS` | `0` | Success exit code |
| `FAIL` | `1` | Failure exit code |

## Logging Functions

These logging functions are defined as fallbacks and can be overridden by `util_tui.sh` for colored output:

```bash
info "Informational message"   # [INFO ] message
warn "Warning message"         # [WARN ] message
error "Error message"          # [ERROR] message
debug "Debug message"          # [DEBUG] message
pass "Success message"         # [PASS ] message
fail "Failure message"         # [FAIL ] message
```

All logging output goes to `stderr`.

## Core Functions

### is_root

Check if the current user is root.

```bash
if is_root; then
    echo "Running as root"
else
    echo "Not root"
fi
```

**Returns:** `PASS` (0) if root, `FAIL` (1) otherwise

### os::is_root

Namespaced wrapper for `is_root` (for consistency with util_os.sh).

```bash
if os::is_root; then
    apt-get update
fi
```

### cmd::exists

Check if a command exists in PATH. This is a foundation function used by all modules.

```bash
if cmd::exists "curl"; then
    echo "curl is available"
fi
```

**Arguments:**
- `$1` - Command name to check

**Returns:** `PASS` (0) if exists, `FAIL` (1) otherwise

## Module Load Order

Modules are loaded in this specific order to satisfy dependencies:

| Layer | Modules |
|-------|---------|
| 1 | `util_platform.sh`, `util_config.sh`, `util_trap.sh` |
| 2 | `util_str.sh`, `util_env.sh` |
| 3 | `util_cmd.sh` |
| 4 | `util_file.sh`, `util_tui.sh` |
| 5 | `util_os.sh`, `util_dir.sh` |
| 6 | `util_curl.sh`, `util_git.sh` |
| 7 | `util_net.sh` |
| 8 | `util_apt.sh`, `util_brew.sh` |
| 9 | `util_py.sh`, `util_py_multi.sh`, `util_ruby.sh`, `util_go.sh` |
| 10 | `util_menu.sh`, `util_tools.sh` |

## Library Guard

The library uses a guard to prevent multiple loading:

```bash
if [[ -n "${UTILS_SH_LOADED:-}" ]]; then
    return 0  # Already loaded
fi
export UTILS_SH_LOADED=1
```

## Exported Variables

| Variable | Description |
|----------|-------------|
| `UTILS_DIR` | Directory containing the utility scripts |
| `UTILS_SOURCED` | Boolean indicating modules were loaded |
| `PASS` | Success constant (0) |
| `FAIL` | Failure constant (1) |

## Self-Test

```bash
source util.sh
utils::self_test
```

Tests:
- Module loaded properly
- PASS/FAIL constants set correctly
- Core functions available (is_root, cmd::exists, os::is_root)
- Logging functions available
- UTILS_DIR is set
- cmd::exists works with known command (bash)

## Example

```bash
#!/usr/bin/env bash

# Source the utility library
source "$(dirname "$0")/util.sh"

# Now use any module
if cmd::exists "git"; then
    info "Git is available"
    
    if git::is_repo; then
        branch=$(git::get_branch)
        pass "On branch: ${branch}"
    fi
fi

# File operations
if file::exists "config.yaml"; then
    file::backup "config.yaml"
fi

# Safe command execution
if ! cmd::run my_command --flag; then
    error "Command failed"
    exit "${FAIL}"
fi

exit "${PASS}"
```
