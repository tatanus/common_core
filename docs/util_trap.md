# util_trap.sh - Trap Handling and Cleanup

Safe trap handling and automatic cleanup utilities for managing temporary files, directories, and cleanup functions.

## Overview

This module provides:
- Exit trap management with cleanup function stacking
- Automatic temporary file/directory registration and cleanup
- LIFO (Last In, First Out) cleanup execution order
- Signal handling (EXIT, SIGINT, SIGTERM)

## Dependencies

None (foundation module)

## Global Variables

| Variable | Type | Description |
|----------|------|-------------|
| `TRAP_CLEANUP_STACK` | Array | Stack of cleanup functions |
| `TRAP_TEMP_FILES` | Array | Registered temporary files |
| `TRAP_TEMP_DIRS` | Array | Registered temporary directories |
| `TRAP_HANDLER_INSTALLED` | Boolean | Whether trap handler is installed |

## Functions

### trap::add_cleanup

Add a cleanup function to the exit trap stack.

```bash
trap::add_cleanup "my_cleanup_function"
trap::add_cleanup "rm -f /tmp/myfile"
```

**Arguments:**
- `$1` - Function name or command to execute on exit

**Returns:** `PASS` (0) on success, `FAIL` (1) if no argument provided

**Notes:**
- Cleanup functions execute in LIFO order (last added, first executed)
- The trap handler is automatically installed on first use
- Errors in cleanup functions are suppressed to prevent masking exit codes

### trap::add_temp_file

Register a temporary file for automatic cleanup on exit.

```bash
tmp_file=$(mktemp)
trap::add_temp_file "${tmp_file}"
echo "data" > "${tmp_file}"
# File is automatically deleted on script exit
```

**Arguments:**
- `$1` - Path to temporary file

**Returns:** `PASS` (0) on success, `FAIL` (1) if no argument provided

### trap::add_temp_dir

Register a temporary directory for automatic cleanup on exit.

```bash
tmp_dir=$(mktemp -d)
trap::add_temp_dir "${tmp_dir}"
# Directory and contents are automatically deleted on script exit
```

**Arguments:**
- `$1` - Path to temporary directory

**Returns:** `PASS` (0) on success, `FAIL` (1) if no argument provided

### trap::with_cleanup

Execute a command and automatically register its output for cleanup.

```bash
# Create temp file and auto-register for cleanup
tmp=$(trap::with_cleanup mktemp)

# Create temp directory and auto-register
tmp_dir=$(trap::with_cleanup mktemp -d)

# Works with platform::mktemp too
tmp=$(trap::with_cleanup platform::mktemp "/tmp/myapp.XXXXXX")
```

**Arguments:**
- `$@` - Command to execute

**Returns:** Exit code of the executed command

**Outputs:** Output of the executed command (typically a path)

**Notes:**
- If the command output is a path to an existing file, it's registered with `trap::add_temp_file`
- If the command output is a path to an existing directory, it's registered with `trap::add_temp_dir`
- This is the recommended way to create temporary files/directories

### trap::clear_all

Clear all registered cleanup functions and temp files/dirs.

```bash
trap::clear_all
```

**Returns:** `PASS` (0) always

**Notes:**
- Use with caution - typically only needed in testing
- Does not uninstall the trap handler itself

### trap::_cleanup_handler

Internal cleanup handler executed on exit (not for direct use).

**Notes:**
- Executes cleanup functions in reverse order (LIFO)
- Removes registered temp files and directories
- Suppresses errors to prevent masking original exit code
- Preserves and returns the original exit code

### trap::_install_handler

Internal function to install the trap handler (not for direct use).

**Notes:**
- Idempotent - safe to call multiple times
- Installs traps for EXIT, SIGINT, and SIGTERM

## Examples

### Basic Temp File Cleanup

```bash
#!/usr/bin/env bash
source util.sh

# Create temp file with automatic cleanup
tmp=$(trap::with_cleanup mktemp)

# Use the temp file
curl -fsSL "https://example.com/data" > "${tmp}"
process_data "${tmp}"

# No manual cleanup needed - file is deleted on exit
```

### Multiple Cleanup Functions

```bash
#!/usr/bin/env bash
source util.sh

# Define cleanup functions
cleanup_network() {
    info "Restoring network settings..."
    # restore network
}

cleanup_mounts() {
    info "Unmounting filesystems..."
    # unmount
}

# Register cleanups (executed in reverse order)
trap::add_cleanup cleanup_network
trap::add_cleanup cleanup_mounts

# Do work...
modify_network
mount_filesystem

# On exit: cleanup_mounts runs first, then cleanup_network
```

### Database Connection Cleanup

```bash
#!/usr/bin/env bash
source util.sh

# Open database connection
db_connect

# Register cleanup
trap::add_cleanup "db_disconnect"

# Work with database
db_query "SELECT * FROM users"

# Connection automatically closed on exit
```

### Complex Workflow with Multiple Resources

```bash
#!/usr/bin/env bash
source util.sh

# Create working directory
work_dir=$(trap::with_cleanup mktemp -d)

# Create multiple temp files
config=$(trap::with_cleanup mktemp "${work_dir}/config.XXXXXX")
data=$(trap::with_cleanup mktemp "${work_dir}/data.XXXXXX")
log=$(trap::with_cleanup mktemp "${work_dir}/log.XXXXXX")

# Add custom cleanup
trap::add_cleanup "info 'Workflow complete'"

# Do work
echo "setting=value" > "${config}"
process_with_config "${config}" > "${data}" 2> "${log}"

# Everything cleaned up automatically
```

### Cleanup on Error

```bash
#!/usr/bin/env bash
source util.sh

set -uo pipefail

# Create temp resources
tmp=$(trap::with_cleanup mktemp)

# This will trigger cleanup even on error
some_command_that_might_fail || {
    error "Command failed, but cleanup still runs"
    exit 1
}
```

### Conditional Cleanup

```bash
#!/usr/bin/env bash
source util.sh

output_file="/tmp/output.txt"
keep_output=false

# Conditional cleanup
cleanup_output() {
    if [[ "${keep_output}" == "false" ]]; then
        rm -f "${output_file}"
    fi
}

trap::add_cleanup cleanup_output

# Generate output
generate_data > "${output_file}"

# Decide whether to keep
if validate_data "${output_file}"; then
    keep_output=true
    pass "Output saved to ${output_file}"
fi
```

## Integration with Other Modules

### With util_curl.sh

```bash
# _curl_exec_body uses trap::with_cleanup internally
body=$(_curl_exec_body "Downloading" -fsSL "https://example.com/api")
# Temp file automatically cleaned up
```

### With util_file.sh

```bash
# file::mktemp registers with trap automatically
tmp=$(file::mktemp)
```

### With util_platform.sh

```bash
# platform::mktemp can be used with trap::with_cleanup
tmp=$(trap::with_cleanup platform::mktemp "/tmp/myapp.XXXXXX")
```

## Self-Test

```bash
source util.sh
trap::self_test
```

Tests:
- TRAP_CLEANUP_STACK array exists
- trap::add_cleanup function available
- trap::add_temp_file function available
- trap::add_temp_dir function available
- Basic cleanup registration works

## Best Practices

1. **Always use `trap::with_cleanup` for temp files**
   ```bash
   # Good
   tmp=$(trap::with_cleanup mktemp)
   
   # Manual (only if needed)
   tmp=$(mktemp)
   trap::add_temp_file "${tmp}"
   ```

2. **Register cleanup early**
   ```bash
   # Register cleanup immediately after resource creation
   db_connect
   trap::add_cleanup "db_disconnect"  # Right after connect
   ```

3. **Order matters for dependencies**
   ```bash
   # If B depends on A, register A's cleanup first
   trap::add_cleanup "cleanup_A"  # Runs second
   trap::add_cleanup "cleanup_B"  # Runs first (LIFO)
   ```

4. **Don't rely on cleanup for critical data**
   ```bash
   # Save important data before exit
   save_critical_data
   # Cleanup is for temporary resources only
   ```

## Notes

- Cleanup functions run even on SIGINT (Ctrl+C) and SIGTERM
- Errors in cleanup functions are suppressed (logged if debug enabled)
- The original exit code is preserved through cleanup
- Cleanup runs in the same shell context (has access to variables)
