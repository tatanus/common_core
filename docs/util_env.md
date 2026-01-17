# util_env.sh - Environment Variable Management

Environment variable management and inspection utilities including XDG directory support, .env file handling, and runtime environment detection.

## Overview

This module provides:
- XDG Base Directory Specification support
- Environment variable get/set/check operations
- .env file loading and validation
- Runtime environment detection (CI, container, tmux, etc.)
- PATH manipulation

## Dependencies

None (standalone module)

## Functions

### XDG Directories

The XDG Base Directory Specification defines standard locations for user files.

#### env::get_xdg_config_home

Get XDG config directory.

```bash
config_dir=$(env::get_xdg_config_home)
# Returns: ~/.config (or $XDG_CONFIG_HOME if set)
```

**Returns:** `PASS` (0) always

**Outputs:** Config directory path

#### env::get_xdg_data_home

Get XDG data directory.

```bash
data_dir=$(env::get_xdg_data_home)
# Returns: ~/.local/share (or $XDG_DATA_HOME if set)
```

**Returns:** `PASS` (0) always

**Outputs:** Data directory path

#### env::get_xdg_cache_home

Get XDG cache directory.

```bash
cache_dir=$(env::get_xdg_cache_home)
# Returns: ~/.cache (or $XDG_CACHE_HOME if set)
```

**Returns:** `PASS` (0) always

**Outputs:** Cache directory path

#### env::get_xdg_state_home

Get XDG state directory.

```bash
state_dir=$(env::get_xdg_state_home)
# Returns: ~/.local/state (or $XDG_STATE_HOME if set)
```

**Returns:** `PASS` (0) always

**Outputs:** State directory path

### Variable Operations

#### env::exists

Check if an environment variable is set.

```bash
if env::exists "HOME"; then
    echo "HOME is set"
fi
```

**Arguments:**
- `$1` - Variable name

**Returns:** `PASS` (0) if set, `FAIL` (1) if not

#### env::check

Check if an environment variable is set and non-empty.

```bash
if env::check "DATABASE_URL"; then
    echo "Database configured"
fi
```

**Arguments:**
- `$1` - Variable name

**Returns:** `PASS` (0) if set and non-empty, `FAIL` (1) otherwise

#### env::get

Get environment variable value with optional default.

```bash
port=$(env::get "PORT" "8080")
echo "Using port: ${port}"
```

**Arguments:**
- `$1` - Variable name
- `$2` - Default value (optional)

**Returns:** `PASS` (0) always

**Outputs:** Variable value or default

#### env::set

Set an environment variable.

```bash
env::set "APP_MODE" "production"
```

**Arguments:**
- `$1` - Variable name
- `$2` - Value to set

**Returns:** `PASS` (0) always

**Notes:** Variable is exported automatically

#### env::unset

Unset an environment variable.

```bash
env::unset "TEMP_VAR"
```

**Arguments:**
- `$1` - Variable name

**Returns:** `PASS` (0) always

#### env::require

Require an environment variable to be set (exit if missing).

```bash
env::require "DATABASE_URL"
env::require "API_KEY"
# Script exits if either is missing
```

**Arguments:**
- `$1` - Variable name

**Returns:** `PASS` (0) if set

**Exits:** With code 1 if variable is not set

### PATH Manipulation

#### env::remove_from_path

Remove a directory from PATH.

```bash
env::remove_from_path "/usr/local/bad"
```

**Arguments:**
- `$1` - Directory to remove from PATH

**Returns:** `PASS` (0) always

### .env File Operations

#### env::validate_env_file

Validate the syntax of a .env file.

```bash
if env::validate_env_file ".env"; then
    echo "File is valid"
else
    echo "File has syntax errors"
fi
```

**Arguments:**
- `$1` - Path to .env file

**Returns:** `PASS` (0) if valid, `FAIL` (1) if errors found

**Notes:**
- Checks for valid KEY=value format
- Ignores comments (#) and blank lines
- Reports line numbers of errors

#### env::export_file

Load and export variables from a .env file.

```bash
env::export_file ".env"
env::export_file ".env.local"
```

**Arguments:**
- `$1` - Path to .env file

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Notes:**
- Lines with KEY=value are exported
- Comments (#) and blank lines are ignored
- Values can be quoted or unquoted
- Existing variables are overwritten

#### env::save_to_file

Save current environment variables to a file.

```bash
env::save_to_file "env_backup.txt"
```

**Arguments:**
- `$1` - Output file path

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### env::diff_files

Compare two .env files and show differences.

```bash
env::diff_files ".env.example" ".env"
```

**Arguments:**
- `$1` - First .env file
- `$2` - Second .env file

**Returns:** `PASS` (0) always

**Outputs:** Differences between files

### Runtime Detection

#### env::is_ci

Check if running in a CI/CD environment.

```bash
if env::is_ci; then
    echo "Running in CI"
    # Skip interactive prompts
fi
```

**Returns:** `PASS` (0) if CI detected, `FAIL` (1) otherwise

**Detection:** Checks for CI, CONTINUOUS_INTEGRATION, GITHUB_ACTIONS, GITLAB_CI, JENKINS_URL, TRAVIS, CIRCLECI, etc.

#### env::is_container

Check if running inside a container.

```bash
if env::is_container; then
    echo "Running in container"
fi
```

**Returns:** `PASS` (0) if container detected, `FAIL` (1) otherwise

**Detection:** Checks for /.dockerenv, /run/.containerenv, or container/docker in /proc/1/cgroup

#### env::is_tmux

Check if running inside tmux.

```bash
if env::is_tmux; then
    echo "Inside tmux session"
fi
```

**Returns:** `PASS` (0) if tmux detected, `FAIL` (1) otherwise

#### env::is_screen

Check if running inside GNU screen.

```bash
if env::is_screen; then
    echo "Inside screen session"
fi
```

**Returns:** `PASS` (0) if screen detected, `FAIL` (1) otherwise

### User/System Info

#### env::get_user

Get the current username.

```bash
user=$(env::get_user)
echo "Running as: ${user}"
```

**Returns:** `PASS` (0) always

**Outputs:** Username

#### env::get_home

Get the user's home directory.

```bash
home=$(env::get_home)
echo "Home: ${home}"
```

**Returns:** `PASS` (0) always

**Outputs:** Home directory path

#### env::get_temp_dir

Get the system temporary directory.

```bash
tmp=$(env::get_temp_dir)
echo "Temp dir: ${tmp}"
```

**Returns:** `PASS` (0) always

**Outputs:** Temp directory path (respects TMPDIR)

## Examples

### Application Configuration

```bash
#!/usr/bin/env bash
source util.sh

# Require critical variables
env::require "DATABASE_URL"
env::require "SECRET_KEY"

# Get with defaults
port=$(env::get "PORT" "3000")
host=$(env::get "HOST" "localhost")
debug=$(env::get "DEBUG" "false")

# Set runtime variables
env::set "APP_STARTED" "$(date +%s)"

echo "Starting on ${host}:${port}"
```

### Loading Environment Files

```bash
#!/usr/bin/env bash
source util.sh

# Load environment files in order (later overrides earlier)
env::export_file ".env"                    # Base config
env::export_file ".env.${APP_ENV:-local}"  # Environment-specific

# Validate before loading
if ! env::validate_env_file ".env.production"; then
    error "Invalid production config"
    exit 1
fi
```

### CI/CD Pipeline Script

```bash
#!/usr/bin/env bash
source util.sh

# Adjust behavior for CI
if env::is_ci; then
    info "Running in CI mode"
    env::set "NON_INTERACTIVE" "true"
    
    # Require CI-specific variables
    env::require "CI_COMMIT_SHA"
    env::require "CI_PROJECT_PATH"
else
    info "Running locally"
fi

# Container-specific adjustments
if env::is_container; then
    env::set "LOG_TO_STDOUT" "true"
fi
```

### XDG-Compliant Application

```bash
#!/usr/bin/env bash
source util.sh

# Get XDG directories
config_dir=$(env::get_xdg_config_home)/myapp
data_dir=$(env::get_xdg_data_home)/myapp
cache_dir=$(env::get_xdg_cache_home)/myapp

# Create directories if needed
mkdir -p "${config_dir}" "${data_dir}" "${cache_dir}"

# Use appropriate locations
config_file="${config_dir}/config.yaml"
database="${data_dir}/app.db"
cache_file="${cache_dir}/responses.cache"
```

### Environment Comparison

```bash
#!/usr/bin/env bash
source util.sh

# Compare example with actual
echo "Missing environment variables:"
env::diff_files ".env.example" ".env"

# Validate syntax
for file in .env .env.local .env.production; do
    if [[ -f "${file}" ]]; then
        if ! env::validate_env_file "${file}"; then
            error "Invalid: ${file}"
        fi
    fi
done
```

### PATH Management

```bash
#!/usr/bin/env bash
source util.sh

# Remove conflicting paths
env::remove_from_path "/usr/local/old-version/bin"

# Add new paths (standard bash)
export PATH="/usr/local/new-version/bin:${PATH}"

# Verify
echo "Updated PATH: ${PATH}"
```

## .env File Format

```bash
# Comments start with #
# Blank lines are ignored

# Simple assignment
DATABASE_URL=postgres://localhost/mydb

# Quoted values (preserves spaces)
APP_NAME="My Application"

# Single quotes (literal)
REGEX_PATTERN='^\d+$'

# No spaces around =
PORT=3000

# Values can reference other variables (in shell, not in file)
# BASE_PATH=/opt/app
# LOG_PATH=${BASE_PATH}/logs  # This won't expand in the file
```

## Self-Test

```bash
source util.sh
env::self_test
```

Tests:
- XDG directory functions
- Variable get/set/check
- Runtime detection functions
- .env file operations

## Notes

- XDG functions return defaults if XDG variables aren't set
- `env::require` exits immediately if variable is missing
- .env files are processed line by line
- Container detection works for Docker and Podman
- CI detection covers major CI/CD platforms
