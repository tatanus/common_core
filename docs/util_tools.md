# util_tools.sh - Tool Installation and Management

Tool installation, shell function management, and testing utilities.

## Overview

This module provides:
- Git-based tool installation
- Shell function management
- Tool testing and verification
- Installation status tracking

## Dependencies

- `util_git.sh`
- `util_py.sh`
- `util_cmd.sh`

## Functions

### Tool Installation

#### tools::install_git_tool

Install a tool from a git repository.

```bash
tools::install_git_tool "https://github.com/user/tool" "tool-name"
```

**Arguments:**
- `$1` - Git repository URL
- `$2` - Tool name

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### tools::install_git_python

Install a Python tool from git with venv.

```bash
tools::install_git_python "https://github.com/user/pytool" "pytool"
```

**Arguments:**
- `$1` - Git repository URL
- `$2` - Tool name

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

### Shell Function Management

#### tools::add_function

Add a shell function to the environment.

```bash
tools::add_function "hello" 'echo "Hello, World!"'
```

**Arguments:**
- `$1` - Function name
- `$2` - Function body

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### tools::remove_function

Remove a shell function.

```bash
tools::remove_function "hello"
```

**Arguments:**
- `$1` - Function name

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### tools::list_functions

List all custom functions.

```bash
tools::list_functions
```

**Outputs:** List of function names

### Tool Testing

#### tools::test

Test if a tool is working.

```bash
tools::test "curl" "curl --version"
```

**Arguments:**
- `$1` - Tool name
- `$2` - Test command

**Returns:** `PASS` (0) if working, `FAIL` (1) otherwise

#### tools::test_batch

Test multiple tools.

```bash
declare -A TOOLS=(
    [curl]="curl --version"
    [git]="git --version"
)
tools::test_batch "TOOLS"
```

**Arguments:**
- `$1` - Name of associative array

**Returns:** `PASS` (0) if all pass, `FAIL` (1) otherwise

### Status

#### tools::list_installed

List installed tools.

```bash
tools::list_installed
```

**Outputs:** List of installed tools

#### tools::get_install_status

Get installation status of a tool.

```bash
status=$(tools::get_install_status "mytool")
```

**Arguments:**
- `$1` - Tool name

**Outputs:** "installed" or "not installed"

### Command Execution

#### tools::run_command

Run a tool command.

```bash
tools::run_command "mytool" --flag arg1 arg2
```

**Arguments:**
- `$1` - Tool name
- `$@` - Command arguments

**Returns:** Exit code of command

## Examples

### Install Security Tools

```bash
#!/usr/bin/env bash
source util.sh

install_security_tools() {
    # Install from git
    tools::install_git_tool "https://github.com/example/scanner" "scanner"
    
    # Install Python tool
    tools::install_git_python "https://github.com/example/analyzer" "analyzer"
    
    # Verify installation
    tools::test "scanner" "scanner --version"
    tools::test "analyzer" "analyzer --help"
}
```

### Create Wrapper Functions

```bash
#!/usr/bin/env bash
source util.sh

# Add convenience functions
tools::add_function "mygrep" 'grep -rn --color=auto "$@"'
tools::add_function "myps" 'ps aux | grep -v grep | grep "$@"'

# List what we added
tools::list_functions
```

## Self-Test

```bash
source util.sh
tools::self_test
```
