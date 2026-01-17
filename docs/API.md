# Bash Utility Library
# Project Badges

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Build Status](https://github.com/tatanus/common_core/actions/workflows/main.yml/badge.svg)](https://github.com/tatanus/common_core/actions/workflows/main.yml)
[![Last Commit](https://img.shields.io/github/last-commit/tatanus/BASH)](https://github.com/tatanus/common_core/commits/main)

![Bash >=4.0](https://img.shields.io/badge/Bash-%3E%3D4.0-4EAA25?logo=gnu-bash&logoColor=white)

**common_core** is the single, shared Bash **core** for varius projects, such as:

- **BASH_SETUP* – “ sets up a Bash environment (standalone)
- **PENTEST_SETUP** – “ installs pentest tooling (standalone or paired with BASH_SETUP)
- **PENTEST_MENU** – “ menu-driven pentest automations (**requires PENTEST_SETUP**)

A comprehensive, modular bash utility library providing cross-platform support for Linux, macOS, and WSL. This library follows strict coding standards for security, maintainability, and portability.

## Features

- **Cross-platform compatibility** - Works on Linux, macOS, and WSL with automatic command abstraction
- **Secure by default** - No `eval` in user-facing APIs, proper quoting, input validation
- **Comprehensive logging** - Consistent logging with multiple levels
- **Self-testing** - Every module includes `::self_test` functions
- **Configuration system** - Centralized, validated configuration management

## Quick Start

### Installation

1. Clone or copy the utility scripts to your project:

```bash
git clone git@github.com:tatanus/common_core.git
```

2. Source the main loader in your script:

```bash
#!/usr/bin/env bash
source /path/to/util.sh
```

This automatically loads all modules in the correct dependency order.

## Module Overview

| Module | Description |
|--------|-------------|
| `util.sh` | Core loader - defines constants, logging fallbacks, loads all modules |
| `util_platform.sh` | Platform detection and command abstraction (GNU vs BSD) |
| `util_config.sh` | Configuration management with validation |
| `util_trap.sh` | Trap handling and automatic cleanup |
| `util_str.sh` | String manipulation utilities |
| `util_env.sh` | Environment variable management |
| `util_cmd.sh` | Command execution and process control |
| `util_file.sh` | File operations with safety checks |
| `util_dir.sh` | Directory operations |
| `util_tui.sh` | Terminal UI (spinners, prompts, dialogs) |
| `util_os.sh` | OS detection and information |
| `util_curl.sh` | HTTP operations via curl |
| `util_git.sh` | Git and GitHub operations |
| `util_net.sh` | Network utilities and diagnostics |
| `util_apt.sh` | APT package manager (Debian/Ubuntu) |
| `util_brew.sh` | Homebrew package manager |
| `util_py.sh` | Python environment management |
| `util_py_multi.sh` | Multi-version Python management |
| `util_ruby.sh` | Ruby environment management |
| `util_go.sh` | Go environment management |
| `util_menu.sh` | Interactive menu system |
| `util_tools.sh` | Tool installation and management |

## Usage Examples

### File Operations

```bash
source util.sh

# Check if file exists
if file::exists "/path/to/file"; then
    echo "File exists"
fi

# Create backup before modifying
file::backup "/path/to/file"

# Safe file copy
file::copy "/source" "/destination"

# Get file checksum
checksum=$(file::get_checksum "/path/to/file" "sha256")
```

### Command Execution

```bash
source util.sh

# Run command with logging
cmd::run git clone https://github.com/user/repo.git

# Run with timeout
cmd::timeout 30 wget https://example.com/large-file.zip

# Run with retry
cmd::retry 3 5 curl -f https://api.example.com/data

# Ensure tool is installed (auto-installs if missing)
cmd::ensure "jq"
```

### Terminal UI

```bash
source util.sh

# Show spinner while command runs
tui::show_spinner -- long_running_command arg1 arg2

# Show spinner for existing background process
long_command &
tui::show_spinner $!

# Prompt for confirmation
if tui::prompt_yes_no "Continue with installation?"; then
    # proceed
fi

# Get user input
name=$(tui::prompt_input "Enter your name" "default_value")
```

### Git Operations

```bash
source util.sh

# Clone repository
git::clone "https://github.com/user/repo.git" "/local/path"

# Check if in git repo
if git::is_repo; then
    branch=$(git::get_branch)
    echo "On branch: ${branch}"
fi

# Create and push branch
git::create_branch "feature/new-feature"
git::push
```

### Configuration

```bash
source util.sh

# Get configuration value
timeout=$(config::get "net.timeout" "30")

# Set configuration
config::set "log.level" "debug"

# Check boolean config
if config::get_bool "file.safe_mode"; then
    echo "Safe mode enabled"
fi
```

### Package Management

```bash
source util.sh

# APT (Debian/Ubuntu)
if apt::is_available; then
    apt::install "curl" "wget" "jq"
fi

# Homebrew (macOS/Linux)
if brew::is_available; then
    brew::install "coreutils" "gnu-sed"
fi
```

### String Manipulation

```bash
source util.sh

# Case conversion
upper=$(str::to_upper "hello")  # HELLO
lower=$(str::to_lower "WORLD")  # world

# Trimming
trimmed=$(str::trim "  hello  ")  # "hello"

# Checking
if str::contains "hello world" "world"; then
    echo "Found!"
fi

if str::is_integer "42"; then
    echo "It's a number"
fi
```

## Architecture

### Module Dependencies

```
util.sh (core loader)
├── util_platform.sh (Layer 1 - foundation)
├── util_config.sh (Layer 1)
├── util_trap.sh (Layer 1)
├── util_str.sh (Layer 2)
├── util_env.sh (Layer 2)
├── util_cmd.sh (Layer 3)
├── util_file.sh (Layer 4)
├── util_tui.sh (Layer 4)
├── util_os.sh (Layer 5)
├── util_dir.sh (Layer 5)
├── util_curl.sh (Layer 6)
├── util_git.sh (Layer 6)
├── util_net.sh (Layer 7)
├── util_apt.sh (Layer 8)
├── util_brew.sh (Layer 8)
├── util_py.sh (Layer 9)
├── util_ruby.sh (Layer 9)
├── util_go.sh (Layer 9)
├── util_menu.sh (Layer 10)
└── util_tools.sh (Layer 10)
```

### Global Constants

All modules share these constants:

```bash
PASS=0   # Success exit code
FAIL=1   # Failure exit code
```

### Logging Functions

Available in all modules:

```bash
info "Informational message"
warn "Warning message"
error "Error message"
debug "Debug message"
pass "Success message"
fail "Failure message"
```

## Configuration

The library uses a hierarchical configuration system. Configuration files are searched in order:

1. `${UTIL_CONFIG_FILE}` (environment variable)
2. `${HOME}/.config/bash_util/config`
3. `${HOME}/.bash_util.conf`

### Example Configuration

```ini
# Logging
log.level=info
log.color=auto

# Network
net.timeout=30
net.retries=3

# File safety
file.safe_mode=true
file.backup_suffix=.bak

# Curl settings
curl.timeout=30
curl.max_redirects=10
```

## Testing

Each module includes a self-test function:

```bash
# Test individual module
source util.sh
file::self_test
cmd::self_test
git::self_test

# Test all modules
for module in util_*.sh; do
    source "$module"
done
```

## Best Practices

### 1. Always quote variables

```bash
# Good
file::copy "${source}" "${destination}"

# Bad - vulnerable to word splitting
file::copy $source $destination
```

### 2. Use arrays for commands with complex arguments

```bash
# Good
local -a cmd=(git commit -m "Message with spaces")
cmd::run "${cmd[@]}"

# Bad - breaks with spaces
cmd::run git commit -m "Message with spaces"
```

### 3. Check return values

```bash
if ! file::copy "${src}" "${dst}"; then
    error "Copy failed"
    return "${FAIL}"
fi
```

### 4. Use the `--` separator with spinner functions

```bash
# Good - uses array-based execution
tui::show_spinner -- curl -fsSL "${url}"

# For monitoring existing process
long_command &
tui::show_spinner $!
```

## 📅 Authorship & Licensing

**Author**: Adam Compton  
**Date Created**: August 18, 2025 
This script is provided under the [MIT License](./policy/LICENSE). Feel free to use and modify it for your needs.
