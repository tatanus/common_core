# util_platform.sh - Platform Abstraction

Platform abstraction layer for OS-specific command variations. Provides normalized interfaces to commands that differ between GNU/Linux, BSD/macOS, and other Unix variants.

## Overview

This module provides:
- OS and variant detection (Linux, macOS, WSL, BSD)
- Command abstraction (GNU vs BSD differences)
- Cross-platform wrappers for common operations
- Automatic GNU tool detection on macOS

## Dependencies

None (foundation module)

## Platform Detection

### platform::detect_os

Detect the current operating system.

```bash
platform::detect_os
echo "Running on: ${PLATFORM_OS}"
```

**Sets:**
- `PLATFORM_OS` - One of: `linux`, `macos`, `wsl`, `freebsd`, `openbsd`, `netbsd`, `solaris`, `windows`, `unknown`

**Returns:** `PASS` always

### platform::detect_variant

Detect the command variant (GNU, BSD, BusyBox, etc.).

```bash
platform::detect_variant
echo "Using: ${PLATFORM_VARIANT} tools"
```

**Sets:**
- `PLATFORM_VARIANT` - One of: `gnu`, `bsd`, `busybox`, `solaris`, `unknown`

**Returns:** `PASS` always

### platform::setup_commands

Initialize command mappings for the current platform.

```bash
platform::setup_commands
# Now PLATFORM_CMD and PLATFORM_FLAGS are populated
```

**Sets:**
- `PLATFORM_CMD` - Associative array mapping command names to paths
- `PLATFORM_FLAGS` - Associative array of platform-specific flags

**Returns:** `PASS` always

## Command Abstraction

The following commands have platform differences that are abstracted:

| Command | GNU (Linux) | BSD (macOS) |
|---------|-------------|-------------|
| `stat` | `stat -c%s file` | `stat -f%z file` |
| `date` | `date -d @123456` | `date -r 123456` |
| `sed` | `sed -i file` | `sed -i '' file` |
| `readlink` | `readlink -f` | No direct equivalent |
| `md5` | `md5sum` | `md5` |
| `sha256` | `sha256sum` | `shasum -a 256` |

### platform::find_command

Find the best available version of a command.

```bash
sed_cmd=$(platform::find_command "sed" "gsed gnu-sed")
```

**Arguments:**
- `$1` - Command name
- `$2` - Preferred names (space-separated, optional)

**Returns:** `PASS` if found, `FAIL` otherwise

**Outputs:** Command path

## Cross-Platform Wrappers

### platform::stat

Cross-platform stat wrapper.

```bash
# Get file size
size=$(platform::stat size "/path/to/file")

# Get modification time
mtime=$(platform::stat mtime "/path/to/file")

# Get access time
atime=$(platform::stat atime "/path/to/file")

# Get file mode (permissions)
mode=$(platform::stat mode "/path/to/file")
```

**Arguments:**
- `$1` - Property to get: `size`, `mtime`, `atime`, `ctime`, `mode`
- `$2` - File path

**Returns:** `PASS` on success, `FAIL` on error

**Outputs:** Requested property value

### platform::date

Cross-platform date wrapper.

```bash
# ISO 8601 format
iso_date=$(platform::date iso8601)

# Epoch timestamp
epoch=$(platform::date epoch)

# RFC 3339 format
rfc_date=$(platform::date rfc3339)

# Date from epoch
date_str=$(platform::date from_epoch 1703001234)

# Date with format
formatted=$(platform::date format "%Y-%m-%d")
```

**Arguments:**
- `$1` - Format type: `iso8601`, `epoch`, `rfc3339`, `from_epoch`, `format`
- `$2` - Additional argument (epoch value or format string)

**Returns:** `PASS` on success, `FAIL` on error

**Outputs:** Formatted date string

### platform::sed_inplace

Cross-platform in-place sed editing.

```bash
platform::sed_inplace 's/old/new/g' "/path/to/file"
```

**Arguments:**
- `$1` - Sed expression
- `$2` - File path

**Returns:** `PASS` on success, `FAIL` on error

### platform::readlink_canonical

Get canonical (absolute) path of a file or directory.

```bash
real_path=$(platform::readlink_canonical "/path/to/symlink")
```

**Arguments:**
- `$1` - Path to resolve

**Returns:** `PASS` on success, `FAIL` on error

**Outputs:** Canonical path

### platform::mktemp

Cross-platform temporary file/directory creation.

```bash
# Create temp file
tmp_file=$(platform::mktemp)

# Create temp file with template
tmp_file=$(platform::mktemp "/tmp/myapp.XXXXXX")

# Create temp directory
tmp_dir=$(platform::mktemp -d)
```

**Arguments:**
- `-d` - Create directory instead of file (optional)
- Template - Template pattern (optional)

**Returns:** `PASS` on success, `FAIL` on error

**Outputs:** Path to created file/directory

### platform::checksum

Cross-platform checksum calculation.

```bash
md5=$(platform::checksum md5 "/path/to/file")
sha256=$(platform::checksum sha256 "/path/to/file")
```

**Arguments:**
- `$1` - Algorithm: `md5`, `sha256`
- `$2` - File path

**Returns:** `PASS` on success, `FAIL` on error

**Outputs:** Checksum hash

## Platform Information

### platform::info

Display platform detection information.

```bash
platform::info
```

**Output:**
```
Platform Information:
  OS: linux
  Variant: gnu

Command Mappings:
  sed         : /usr/bin/sed
  stat        : /usr/bin/stat
  date        : /usr/bin/date
  ...
```

### platform::check_gnu_tools

Check if GNU tools are available on macOS.

```bash
if ! platform::check_gnu_tools; then
    echo "Install GNU tools: brew install coreutils findutils gnu-sed"
fi
```

**Returns:** `PASS` if all tools found, `FAIL` if any missing

## Global Variables

| Variable | Description |
|----------|-------------|
| `PLATFORM_OS` | Detected operating system |
| `PLATFORM_VARIANT` | Detected command variant (gnu/bsd) |
| `PLATFORM_CMD` | Associative array of command paths |
| `PLATFORM_FLAGS` | Associative array of platform-specific flags |

## Examples

### Cross-Platform Script

```bash
#!/usr/bin/env bash
source util.sh

# Get file info in a cross-platform way
size=$(platform::stat size "$file")
mtime=$(platform::stat mtime "$file")

echo "File size: ${size} bytes"
echo "Modified: $(platform::date from_epoch ${mtime})"
```

### macOS Compatibility

```bash
#!/usr/bin/env bash
source util.sh

# Check for GNU tools on macOS
if [[ "${PLATFORM_OS}" == "macos" ]]; then
    if ! platform::check_gnu_tools; then
        warn "Some features may not work without GNU tools"
        warn "Install with: brew install coreutils findutils gnu-sed gnu-tar"
    fi
fi
```

### Platform-Specific Logic

```bash
#!/usr/bin/env bash
source util.sh

platform::detect_os

case "${PLATFORM_OS}" in
    linux)
        config_dir="/etc/myapp"
        ;;
    macos)
        config_dir="${HOME}/Library/Application Support/myapp"
        ;;
    wsl)
        config_dir="/etc/myapp"
        # Also check Windows paths
        ;;
    *)
        error "Unsupported platform: ${PLATFORM_OS}"
        exit 1
        ;;
esac
```

### In-Place File Editing

```bash
#!/usr/bin/env bash
source util.sh

# Works on both Linux and macOS
platform::sed_inplace 's/DEBUG=false/DEBUG=true/' config.sh
platform::sed_inplace '/^#/d' config.sh  # Remove comments
```

## Self-Test

```bash
source util.sh
platform::self_test
```

Tests:
- Platform detection
- Command setup
- stat wrapper
- date wrapper
- checksum calculation

## Notes

- On macOS, the module automatically prefers GNU tools if installed (gsed, gstat, etc.)
- The module caches platform detection results for performance
- All wrappers handle errors gracefully and return appropriate exit codes
- The module auto-initializes when sourced
