# util_file.sh - File Operations

File operations, safety checks, and manipulation utilities with built-in protection against destructive operations on sensitive paths.

## Overview

This module provides:
- File existence and permission checks
- Safe copy, move, delete operations
- Backup and restore functionality
- File content manipulation
- Checksum calculation

## Dependencies

- `util_platform.sh`
- `util_config.sh`

## Safety Features

The module implements a "Home-Safe File Policy" that prevents destructive operations on:
- Root directory (`/`)
- Home directory (`$HOME`)
- System directories (`/etc`, `/bin`, `/usr`, `/lib`, `/var`, etc.)
- Paths containing `..` (parent traversal)

Safety mode can be disabled via configuration:
```bash
config::set "file.safe_mode" "false"
```

## Functions

### Existence and Permissions

#### file::exists

Check if a file exists.

```bash
if file::exists "/path/to/file"; then
    echo "File exists"
fi
```

**Arguments:**
- `$1` - File path

**Returns:** `PASS` (0) if exists, `FAIL` (1) otherwise

#### file::is_readable

Check if a file is readable.

```bash
if file::is_readable "/path/to/file"; then
    cat "/path/to/file"
fi
```

**Returns:** `PASS` (0) if readable, `FAIL` (1) otherwise

#### file::is_writable

Check if a file is writable.

```bash
if file::is_writable "/path/to/file"; then
    echo "data" >> "/path/to/file"
fi
```

**Returns:** `PASS` (0) if writable, `FAIL` (1) otherwise

#### file::is_executable

Check if a file is executable.

```bash
if file::is_executable "/path/to/script"; then
    /path/to/script
fi
```

**Returns:** `PASS` (0) if executable, `FAIL` (1) otherwise

#### file::is_non_empty

Check if a file exists and is not empty.

```bash
if file::is_non_empty "/path/to/file"; then
    echo "File has content"
fi
```

**Returns:** `PASS` (0) if non-empty, `FAIL` (1) if empty or missing

### File Information

#### file::get_size

Get file size in bytes.

```bash
size=$(file::get_size "/path/to/file")
echo "File is ${size} bytes"
```

**Outputs:** Size in bytes

#### file::get_extension

Get file extension.

```bash
ext=$(file::get_extension "/path/to/file.tar.gz")
# Returns: tar.gz
```

**Outputs:** File extension (without leading dot)

#### file::get_basename

Get filename without directory path.

```bash
name=$(file::get_basename "/path/to/file.txt")
# Returns: file.txt
```

**Outputs:** Base filename

#### file::get_dirname

Get directory path without filename.

```bash
dir=$(file::get_dirname "/path/to/file.txt")
# Returns: /path/to
```

**Outputs:** Directory path

#### file::count_lines

Count lines in a file.

```bash
lines=$(file::count_lines "/path/to/file")
```

**Outputs:** Line count

### File Operations

#### file::copy

Copy a file safely.

```bash
file::copy "/source/file" "/dest/file"
```

**Arguments:**
- `$1` - Source file path
- `$2` - Destination file path

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### file::copy_list_from_array

Copy multiple files from an array.

```bash
local -a files=("/path/file1" "/path/file2" "/path/file3")
file::copy_list_from_array "/dest/dir" files
```

**Arguments:**
- `$1` - Destination directory
- `$2` - Name of array containing file paths

**Returns:** `PASS` (0) if all succeed, `FAIL` (1) if any fail

#### file::move

Move a file safely.

```bash
file::move "/source/file" "/dest/file"
```

**Arguments:**
- `$1` - Source file path
- `$2` - Destination file path

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### file::delete

Delete a file safely.

```bash
file::delete "/path/to/file"
```

**Arguments:**
- `$1` - File path to delete

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Note:** Protected by safe mode - will refuse to delete files in sensitive locations.

#### file::touch

Create an empty file or update timestamp.

```bash
file::touch "/path/to/file"
```

**Arguments:**
- `$1` - File path

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

### Backup and Restore

#### file::backup

Create a backup of a file.

```bash
file::backup "/path/to/file"
# Creates: /path/to/file.bak
```

**Arguments:**
- `$1` - File path to backup
- `$2` - Backup suffix (optional, default: `.bak` from config)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### file::restore_old_backup

Restore the highest-numbered `.old-N` backup.

```bash
file::restore_old_backup "/path/to/file"
# Restores from /path/to/file.old-2 (highest number)
```

**Arguments:**
- `$1` - Original file path

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

### Content Manipulation

#### file::append

Append text to a file.

```bash
file::append "/path/to/file" "New line of text"
```

**Arguments:**
- `$1` - File path
- `$2` - Text to append

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### file::prepend

Prepend text to a file.

```bash
file::prepend "/path/to/file" "First line"
```

**Arguments:**
- `$1` - File path
- `$2` - Text to prepend

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### file::replace_line

Replace a line matching a pattern.

```bash
file::replace_line "/path/to/file" "^old_pattern" "new_content"
```

**Arguments:**
- `$1` - File path
- `$2` - Pattern to match
- `$3` - Replacement text

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### file::replace_env_vars

Replace environment variable placeholders in a file.

```bash
export MY_VAR="value"
file::replace_env_vars "/path/to/template" "/path/to/output"
# Replaces ${MY_VAR} with "value"
```

**Arguments:**
- `$1` - Source file path
- `$2` - Output file path

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### file::contains

Check if a file contains a pattern.

```bash
if file::contains "/path/to/file" "search_pattern"; then
    echo "Pattern found"
fi
```

**Arguments:**
- `$1` - File path
- `$2` - Pattern to search for

**Returns:** `PASS` (0) if found, `FAIL` (1) if not found

### Checksums

#### file::get_checksum

Calculate file checksum.

```bash
sum=$(file::get_checksum "/path/to/file" "sha256")
sum=$(file::get_checksum "/path/to/file")  # Uses default algorithm
```

**Arguments:**
- `$1` - File path
- `$2` - Algorithm (optional, default from config: `sha256`)

**Supported algorithms:** `md5`, `sha1`, `sha256`, `sha512`

**Outputs:** Checksum hash

#### file::compare

Compare two files for byte-for-byte equality.

```bash
if file::compare "/path/to/file1" "/path/to/file2"; then
    echo "Files are identical"
fi
```

**Arguments:**
- `$1` - First file path
- `$2` - Second file path

**Returns:** `PASS` (0) if identical, `FAIL` (1) if different

### Utility

#### file::mktemp

Create a secure temporary file.

```bash
tmp=$(file::mktemp)
echo "data" > "$tmp"
```

**Arguments:**
- `$1` - Template (optional, e.g., `/tmp/myapp.XXXXXX`)

**Outputs:** Path to temporary file

#### file::generate_filename

Generate a unique filename.

```bash
name=$(file::generate_filename "backup" "tar.gz")
# Returns something like: backup_20231215_143022.tar.gz
```

**Arguments:**
- `$1` - Base name
- `$2` - Extension

**Outputs:** Generated filename with timestamp

## Examples

### Safe Config File Update

```bash
#!/usr/bin/env bash
source util.sh

config_file="/etc/myapp/config.yaml"

if file::exists "${config_file}"; then
    # Create backup before modifying
    file::backup "${config_file}"
    
    # Modify file
    file::append "${config_file}" "new_setting: value"
    
    pass "Configuration updated"
else
    error "Config file not found"
    exit "${FAIL}"
fi
```

### Template Processing

```bash
#!/usr/bin/env bash
source util.sh

export APP_NAME="MyApp"
export APP_PORT="8080"
export APP_ENV="production"

# Process template
file::replace_env_vars "config.template" "config.yaml"

# Verify
if file::contains "config.yaml" "${APP_NAME}"; then
    pass "Template processed successfully"
fi
```

### File Verification

```bash
#!/usr/bin/env bash
source util.sh

expected_checksum="abc123..."
file="/path/to/download"

actual_checksum=$(file::get_checksum "${file}" "sha256")

if [[ "${actual_checksum}" == "${expected_checksum}" ]]; then
    pass "Checksum verified"
else
    fail "Checksum mismatch!"
    file::delete "${file}"
    exit "${FAIL}"
fi
```

### Batch File Operations

```bash
#!/usr/bin/env bash
source util.sh

# Copy multiple files
local -a source_files=(
    "/source/file1.txt"
    "/source/file2.txt"
    "/source/file3.txt"
)

file::copy_list_from_array "/destination" source_files
```

## Configuration Options

| Key | Default | Description |
|-----|---------|-------------|
| `file.safe_mode` | `true` | Enable safety checks |
| `file.backup_suffix` | `.bak` | Default backup suffix |
| `file.checksum_algo` | `sha256` | Default checksum algorithm |

## Self-Test

```bash
source util.sh
file::self_test
```

## Notes

- All destructive operations respect `file.safe_mode` configuration
- Backup functions create rotating backups (`.old-0`, `.old-1`, etc.)
- Cross-platform checksum calculation via `util_platform.sh`
- Temporary files are automatically tracked for cleanup via `util_trap.sh`
