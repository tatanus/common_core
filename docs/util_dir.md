# util_dir.sh - Directory Operations

Directory operations with safety checks, traversal utilities, and common directory manipulation tasks.

## Overview

This module provides:
- Directory existence and permission checks
- Safe create, delete, copy, move operations
- Directory listing and searching
- Directory stack (pushd/popd) wrappers
- Temporary directory management
- Backup and rotation

## Dependencies

- `util_platform.sh`
- `util_config.sh`

## Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `dir.safe_mode` | `true` | Enable safety checks for destructive operations |
| `dir.max_depth` | `100` | Maximum directory traversal depth |

## Functions

### Existence and Permissions

#### dir::exists

Check if a directory exists.

```bash
if dir::exists "/path/to/dir"; then
    echo "Directory exists"
fi
```

**Arguments:**
- `$1` - Directory path

**Returns:** `PASS` (0) if exists, `FAIL` (1) otherwise

#### dir::is_readable

Check if a directory is readable.

```bash
if dir::is_readable "/path/to/dir"; then
    ls "/path/to/dir"
fi
```

**Arguments:**
- `$1` - Directory path

**Returns:** `PASS` (0) if readable, `FAIL` (1) otherwise

#### dir::is_writable

Check if a directory is writable.

```bash
if dir::is_writable "/path/to/dir"; then
    touch "/path/to/dir/newfile"
fi
```

**Arguments:**
- `$1` - Directory path

**Returns:** `PASS` (0) if writable, `FAIL` (1) otherwise

#### dir::is_empty

Check if a directory is empty.

```bash
if dir::is_empty "/path/to/dir"; then
    echo "Directory is empty"
fi
```

**Arguments:**
- `$1` - Directory path

**Returns:** `PASS` (0) if empty, `FAIL` (1) if has contents

### Directory Operations

#### dir::create

Create a directory (with parents if needed).

```bash
dir::create "/path/to/new/directory"
dir::create "/path/to/dir" "0755"  # With specific permissions
```

**Arguments:**
- `$1` - Directory path
- `$2` - Permissions (optional, default: 0755)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### dir::delete

Delete a directory and its contents.

```bash
dir::delete "/path/to/directory"
```

**Arguments:**
- `$1` - Directory path

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Notes:** Protected by safe mode - refuses to delete system directories

#### dir::copy

Copy a directory recursively.

```bash
dir::copy "/source/dir" "/destination/dir"
```

**Arguments:**
- `$1` - Source directory
- `$2` - Destination directory

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### dir::move

Move/rename a directory.

```bash
dir::move "/old/path" "/new/path"
```

**Arguments:**
- `$1` - Source directory
- `$2` - Destination directory

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### dir::empty

Remove all contents of a directory but keep the directory.

```bash
dir::empty "/path/to/dir"
```

**Arguments:**
- `$1` - Directory path

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

### Directory Information

#### dir::get_size

Get the total size of a directory in bytes.

```bash
size=$(dir::get_size "/path/to/dir")
echo "Size: ${size} bytes"
```

**Arguments:**
- `$1` - Directory path

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Size in bytes

#### dir::count_files

Count files in a directory.

```bash
count=$(dir::count_files "/path/to/dir")
echo "Files: ${count}"
```

**Arguments:**
- `$1` - Directory path
- `$2` - Recursive flag: "true" or "false" (default: false)

**Returns:** `PASS` (0) always

**Outputs:** File count

#### dir::count_dirs

Count subdirectories in a directory.

```bash
count=$(dir::count_dirs "/path/to/dir")
echo "Subdirectories: ${count}"
```

**Arguments:**
- `$1` - Directory path
- `$2` - Recursive flag (default: false)

**Returns:** `PASS` (0) always

**Outputs:** Directory count

### Listing and Searching

#### dir::list_files

List files in a directory.

```bash
# List to stdout
dir::list_files "/path/to/dir"

# Capture to array
mapfile -t files < <(dir::list_files "/path/to/dir")
```

**Arguments:**
- `$1` - Directory path
- `$2` - Recursive flag (default: false)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** One file path per line

#### dir::list_dirs

List subdirectories in a directory.

```bash
dir::list_dirs "/path/to/dir"
```

**Arguments:**
- `$1` - Directory path
- `$2` - Recursive flag (default: false)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** One directory path per line

#### dir::find_files

Find files matching a pattern.

```bash
# Find all shell scripts
dir::find_files "/project" "*.sh"

# Find all Python files recursively
dir::find_files "/project" "*.py" true
```

**Arguments:**
- `$1` - Directory path
- `$2` - Pattern (glob)
- `$3` - Recursive flag (default: true)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** One matching file path per line

### Path Operations

#### dir::get_absolute_path

Get the absolute path of a directory.

```bash
abs_path=$(dir::get_absolute_path "../relative/path")
```

**Arguments:**
- `$1` - Directory path (can be relative)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Absolute path

#### dir::get_relative_path

Get a relative path from one directory to another.

```bash
rel=$(dir::get_relative_path "/base/dir" "/base/dir/sub/path")
echo "${rel}"  # sub/path
```

**Arguments:**
- `$1` - Base directory
- `$2` - Target directory

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Relative path

#### dir::in_path

Check if a path is within another directory.

```bash
if dir::in_path "/home/user/project" "/home/user/project/src/file.txt"; then
    echo "File is within project"
fi
```

**Arguments:**
- `$1` - Base directory
- `$2` - Path to check

**Returns:** `PASS` (0) if within, `FAIL` (1) otherwise

### Directory Stack

#### dir::push

Push directory onto stack and change to it.

```bash
dir::push "/new/directory"
# Do work in new directory
dir::pop  # Return to previous
```

**Arguments:**
- `$1` - Directory path

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### dir::pop

Pop directory from stack and return to it.

```bash
dir::pop
```

**Returns:** `PASS` (0) on success, `FAIL` (1) if stack empty

### Utility Functions

#### dir::ensure_exists

Create directory if it doesn't exist.

```bash
dir::ensure_exists "/path/to/dir"
```

**Arguments:**
- `$1` - Directory path

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### dir::ensure_writable

Ensure directory exists and is writable.

```bash
if dir::ensure_writable "/path/to/dir"; then
    echo "Ready to write"
fi
```

**Arguments:**
- `$1` - Directory path

**Returns:** `PASS` (0) if writable, `FAIL` (1) otherwise

#### dir::tempdir

Create a temporary directory.

```bash
tmp=$(dir::tempdir)
# Use temporary directory
# Cleaned up on exit if using trap module
```

**Arguments:**
- `$1` - Template (optional, e.g., "/tmp/myapp.XXXXXX")

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Path to created directory

### Backup and Rotation

#### dir::backup

Create a backup of a directory.

```bash
dir::backup "/path/to/dir"
# Creates /path/to/dir.bak or /path/to/dir.bak.1, etc.
```

**Arguments:**
- `$1` - Directory path
- `$2` - Backup suffix (optional, default: .bak)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### dir::rotate

Rotate directory backups (keep N most recent).

```bash
dir::rotate "/path/to/dir" 5
# Keeps .bak, .bak.1, .bak.2, .bak.3, .bak.4
```

**Arguments:**
- `$1` - Base directory path
- `$2` - Number of backups to keep

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### dir::cleanup_old

Remove files/directories older than N days.

```bash
dir::cleanup_old "/var/log/myapp" 30
# Removes files older than 30 days
```

**Arguments:**
- `$1` - Directory path
- `$2` - Age in days

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

## Examples

### Project Initialization

```bash
#!/usr/bin/env bash
source util.sh

init_project() {
    local project_dir="$1"
    
    # Create project structure
    dir::create "${project_dir}/src"
    dir::create "${project_dir}/tests"
    dir::create "${project_dir}/docs"
    dir::create "${project_dir}/build" "0755"
    
    # Ensure writable
    if ! dir::ensure_writable "${project_dir}/build"; then
        error "Cannot write to build directory"
        return "${FAIL}"
    fi
    
    pass "Project initialized at ${project_dir}"
}
```

### Safe Directory Operations

```bash
#!/usr/bin/env bash
source util.sh

cleanup_build() {
    local build_dir="$1"
    
    # Safety checks
    if ! dir::exists "${build_dir}"; then
        warn "Build directory doesn't exist"
        return "${PASS}"
    fi
    
    if dir::is_empty "${build_dir}"; then
        info "Build directory already empty"
        return "${PASS}"
    fi
    
    # Create backup before cleaning
    dir::backup "${build_dir}"
    
    # Empty the directory
    dir::empty "${build_dir}"
    
    pass "Build directory cleaned"
}
```

### Finding and Processing Files

```bash
#!/usr/bin/env bash
source util.sh

process_logs() {
    local log_dir="$1"
    
    # Find all log files
    while IFS= read -r log_file; do
        info "Processing: ${log_file}"
        # Process log file
    done < <(dir::find_files "${log_dir}" "*.log")
    
    # Count processed
    local count
    count=$(dir::count_files "${log_dir}")
    pass "Processed ${count} log files"
}
```

### Working Directory Management

```bash
#!/usr/bin/env bash
source util.sh

build_in_temp() {
    # Save current directory
    dir::push "$(dir::tempdir)"
    
    # Do build work in temp directory
    git clone "$1" ./source
    cd ./source
    make build
    
    # Return to original directory
    dir::pop
}
```

### Log Rotation

```bash
#!/usr/bin/env bash
source util.sh

rotate_logs() {
    local log_dir="/var/log/myapp"
    
    # Rotate logs keeping last 7 days
    dir::cleanup_old "${log_dir}" 7
    
    # Keep only 5 backup directories
    dir::rotate "${log_dir}/archive" 5
    
    pass "Log rotation complete"
}
```

### Directory Comparison

```bash
#!/usr/bin/env bash
source util.sh

compare_directories() {
    local dir1="$1"
    local dir2="$2"
    
    local count1 count2
    count1=$(dir::count_files "${dir1}" true)
    count2=$(dir::count_files "${dir2}" true)
    
    local size1 size2
    size1=$(dir::get_size "${dir1}")
    size2=$(dir::get_size "${dir2}")
    
    echo "Directory 1: ${count1} files, ${size1} bytes"
    echo "Directory 2: ${count2} files, ${size2} bytes"
}
```

## Self-Test

```bash
source util.sh
dir::self_test
```

Tests:
- Directory creation and deletion
- Existence and permission checks
- Listing operations
- Path resolution

## Notes

- Safe mode prevents deletion of system directories
- Directory operations respect umask settings
- Recursive operations have depth limits
- Temporary directories are tracked for cleanup
- All paths should be quoted to handle spaces
