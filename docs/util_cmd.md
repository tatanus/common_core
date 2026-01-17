# util_cmd.sh - Command Execution Utilities

Command execution, validation, and process control utilities providing safe wrappers for running external commands with logging, timeouts, retries, and parallelization.

## Overview

This module provides:
- Command existence checking
- Logged command execution
- Timeout and retry mechanisms
- Parallel command execution
- Privilege elevation (sudo)
- Automatic tool installation

## Dependencies

- `util_platform.sh` (for os detection in package installation)

## Functions

### Command Availability

#### cmd::exists

Check if a command exists in PATH.

```bash
if cmd::exists "jq"; then
    echo "jq is available"
fi
```

**Arguments:**
- `$1` - Command name to check

**Returns:** `PASS` (0) if exists, `FAIL` (1) otherwise

#### cmd::require

Ensure a command exists; exit with error if missing.

```bash
cmd::require "git"
cmd::require "docker"
# Script continues only if both exist
```

**Arguments:**
- `$1` - Command name to check

**Returns:** `PASS` (0) if exists, exits with code 1 if missing

### Command Execution

#### cmd::run

Execute a command with logging and exit code reporting.

```bash
cmd::run git clone https://github.com/user/repo.git

# With array for complex arguments
local -a args=(git commit -m "Message with spaces")
cmd::run "${args[@]}"
```

**Arguments:**
- `$@` - Command and arguments to execute

**Returns:** `PASS` (0) if command succeeds, `FAIL` (1) otherwise

#### cmd::run_silent

Execute a command silently (stdout/stderr suppressed).

```bash
if cmd::run_silent rm -f /tmp/tempfile; then
    echo "Cleaned up"
fi
```

**Arguments:**
- `$@` - Command and arguments to execute

**Returns:** `PASS` (0) if command succeeds, `FAIL` (1) otherwise

#### cmd::run_with_env

Run a command with custom environment variables.

```bash
cmd::run_with_env "GOOS=linux" "GOARCH=amd64" -- go build -o myapp
```

**Arguments:**
- Environment variables (VAR=value format)
- `--` separator
- Command and arguments

**Returns:** Exit code of the command

#### cmd::run_as_user

Execute a command as a specified user via sudo.

```bash
cmd::run_as_user "www-data" nginx -t
```

**Arguments:**
- `$1` - Username to run as
- `$@` - Command and arguments

**Returns:** `PASS` (0) if command succeeds, `FAIL` (1) otherwise

### Timeouts and Retries

#### cmd::timeout

Run a command with a timeout constraint.

```bash
cmd::timeout 30 wget https://example.com/large-file.zip
```

**Arguments:**
- `$1` - Timeout in seconds
- `$@` - Command and arguments

**Returns:** `PASS` (0) if completes in time, `FAIL` (1) on timeout/error

#### cmd::retry

Retry a command multiple times with delay intervals.

```bash
cmd::retry 3 5 curl -f https://api.example.com/health
# Tries up to 3 times with 5-second delays
```

**Arguments:**
- `$1` - Number of attempts
- `$2` - Delay between attempts (seconds)
- `$@` - Command and arguments

**Returns:** `PASS` (0) if eventually succeeds, `FAIL` (1) if all fail

### Parallel Execution

#### cmd::parallel

Run multiple commands in parallel.

```bash
cmd::parallel "make module1" "make module2" "make module3"
```

**Arguments:**
- `$@` - Commands to run (each as a string)

**Returns:** `PASS` (0) if all succeed, `FAIL` (1) if any fail

**Notes:** Command strings are split on whitespace. For complex arguments, use `cmd::parallel_array`.

#### cmd::parallel_array

Run multiple commands in parallel using array references (for complex arguments).

```bash
local -a cmd1=(git clone "https://github.com/user/repo1.git" "/path/to/repo1")
local -a cmd2=(git clone "https://github.com/user/repo2.git" "/path/to/repo2")
cmd::parallel_array cmd1 cmd2
```

**Arguments:**
- `$@` - Names of array variables containing commands

**Returns:** `PASS` (0) if all succeed, `FAIL` (1) if any fail

### Privilege Elevation

#### cmd::sudo_available

Check if sudo is installed and functional.

```bash
if cmd::sudo_available; then
    sudo apt-get update
fi
```

**Returns:** `PASS` (0) if sudo available, `FAIL` (1) otherwise

#### cmd::ensure_sudo_cached

Ensure sudo credentials are cached (prompts if needed).

```bash
cmd::ensure_sudo_cached
# Now sudo commands won't prompt for password
```

**Returns:** `PASS` (0) if cached, `FAIL` (1) otherwise

#### cmd::elevate

Run a command with elevated privileges.

```bash
cmd::elevate apt-get update
# Uses sudo if not root, runs directly if already root
```

**Arguments:**
- `$@` - Command and arguments

**Returns:** `PASS` (0) if succeeds, `FAIL` (1) otherwise

### Tool Management

#### cmd::ensure

Ensure a tool exists; auto-install via apt/brew if missing.

```bash
cmd::ensure "jq"
cmd::ensure "rg" "ripgrep" "ripgrep"  # tool, apt_pkg, brew_pkg
```

**Arguments:**
- `$1` - Tool name (executable to check for)
- `$2` - apt package name (optional, defaults to $1)
- `$3` - brew formula name (optional, defaults to $1)

**Returns:** `PASS` (0) if available, `FAIL` (1) if install failed

#### cmd::ensure_all

Ensure multiple tools exist.

```bash
cmd::ensure_all "curl" "wget" "jq" "git"
```

**Arguments:**
- `$@` - Tool names to ensure

**Returns:** `PASS` (0) if all available, `FAIL` (1) if any failed

#### cmd::install_package

Generic package install dispatcher by OS.

```bash
cmd::install_package "vim"
# Uses apt on Linux, brew on macOS
```

**Arguments:**
- `$1` - Package name

**Returns:** `PASS` (0) on success, `FAIL` (1) on failure

### Testing

#### cmd::test

Execute a command and verify its exit code matches expected.

```bash
# Test that true returns 0
cmd::test 0 true

# Test that false returns 1
cmd::test 1 false

# Test a real command
cmd::test 0 curl --version
```

**Arguments:**
- `$1` - Expected exit code
- `$@` - Command and arguments

**Returns:** `PASS` (0) if exit code matches, `FAIL` (1) otherwise

#### cmd::test_tool

Test if a tool is installed and functioning.

```bash
cmd::test_tool "curl" 0 curl --version
cmd::test_tool "jq" 0 jq --version
```

**Arguments:**
- `$1` - Tool name (for logging)
- `$2` - Expected exit code
- `$@` - Test command and arguments

**Returns:** `PASS` (0) if test passes, `FAIL` (1) otherwise

#### cmd::test_batch

Run multiple tool tests from an associative array.

```bash
declare -A TESTS=(
    [curl]="curl --version"
    [git]="git --version"
    [jq]="jq --version"
)
cmd::test_batch "TESTS"
```

**Arguments:**
- `$1` - Name of associative array mapping tool -> test command

**Returns:** `PASS` (0) if all pass, `FAIL` (1) if any fail

### Utility

#### cmd::build

Build a command array safely.

```bash
local -a my_cmd
cmd::build my_cmd git config --global user.name "John Doe"
"${my_cmd[@]}"
```

**Arguments:**
- `$1` - Name of array variable to populate
- `$@` - Command components

**Returns:** `PASS` always

#### cmd::get_exit_code

Print the exit code of the last command.

```bash
some_command
code=$(cmd::get_exit_code)
```

**Returns:** `PASS` always

**Outputs:** Exit code

## Examples

### Safe Script with Dependencies

```bash
#!/usr/bin/env bash
source util.sh

# Ensure required tools
cmd::require "git"
cmd::require "docker"

# Optional tools - install if missing
cmd::ensure "jq"
cmd::ensure "yq"

# Run commands with logging
cmd::run git pull
cmd::run docker build -t myapp .
```

### Parallel Downloads

```bash
#!/usr/bin/env bash
source util.sh

# Define downloads as arrays (for URLs with special chars)
local -a dl1=(curl -fsSL "https://example.com/file1.tar.gz" -o file1.tar.gz)
local -a dl2=(curl -fsSL "https://example.com/file2.tar.gz" -o file2.tar.gz)
local -a dl3=(curl -fsSL "https://example.com/file3.tar.gz" -o file3.tar.gz)

# Download in parallel
cmd::parallel_array dl1 dl2 dl3
```

### Retry with Timeout

```bash
#!/usr/bin/env bash
source util.sh

# Retry API call up to 5 times, with 30s timeout each try
if ! cmd::retry 5 10 cmd::timeout 30 curl -f https://api.example.com/data; then
    error "API unreachable after multiple attempts"
    exit "${FAIL}"
fi
```

### Tool Verification

```bash
#!/usr/bin/env bash
source util.sh

declare -A REQUIRED_TOOLS=(
    [docker]="docker --version"
    [kubectl]="kubectl version --client"
    [helm]="helm version"
)

if ! cmd::test_batch "REQUIRED_TOOLS"; then
    error "Missing required tools"
    exit "${FAIL}"
fi

pass "All tools verified"
```

## Self-Test

```bash
source util.sh
cmd::self_test
```

## Notes

- Command arrays preserve argument boundaries (spaces, special chars)
- The `cmd::parallel` function splits strings on whitespace; use `cmd::parallel_array` for complex arguments
- `cmd::test` expects exit code as first argument, followed by the command
- Tool installation requires `util_apt.sh` or `util_brew.sh` to be loaded
