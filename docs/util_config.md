# util_config.sh - Configuration Management

Centralized configuration management system with validation, persistence, environment integration, and hierarchical settings.

## Overview

This module provides:
- Hierarchical key-value configuration storage
- Type validation (string, int, bool, path)
- Pattern-based validation
- Configuration locking
- File persistence
- Environment variable integration
- Export to JSON/environment

## Dependencies

None (foundation module)

## Configuration Storage

Configuration is stored in associative arrays:

| Array | Purpose |
|-------|---------|
| `UTIL_CONFIG` | Current values |
| `UTIL_CONFIG_DEFAULTS` | Default values |
| `UTIL_CONFIG_META` | Type, description, validation |
| `UTIL_CONFIG_SOURCE` | Where value came from |
| `UTIL_CONFIG_LOCKED` | Lock status |

## Functions

### Initialization

#### config::init

Initialize the configuration system with defaults.

```bash
config::init
```

**Returns:** `PASS` always

**Notes:** Called automatically when module is sourced.

#### config::load

Load configuration from a file.

```bash
config::load "/path/to/config"
```

**Arguments:**
- `$1` - Configuration file path (optional, searches default paths)

**Returns:** `PASS` on success, `FAIL` on error

### Registration

#### config::register

Register a new configuration key with type and validation.

```bash
config::register "app.timeout" "30" "int" "Connection timeout in seconds" "^[0-9]+$"
```

**Arguments:**
- `$1` - Configuration key
- `$2` - Default value
- `$3` - Type: `string`, `int`, `bool`, `path`
- `$4` - Description
- `$5` - Validation pattern (regex or `|`-separated list)

**Returns:** `PASS` always

### Getting Values

#### config::get

Get a configuration value.

```bash
value=$(config::get "app.timeout")
value=$(config::get "app.timeout" "60")  # With fallback default
```

**Arguments:**
- `$1` - Configuration key
- `$2` - Default value if not set (optional)

**Returns:** `PASS` if found, `FAIL` if not found

**Outputs:** Configuration value

#### config::get_int

Get a configuration value as integer.

```bash
timeout=$(config::get_int "app.timeout" 30)
```

**Arguments:**
- `$1` - Configuration key
- `$2` - Default value (optional, default: 0)

**Returns:** `PASS` always

**Outputs:** Integer value

#### config::get_bool

Check if a boolean configuration is true.

```bash
if config::get_bool "app.debug"; then
    echo "Debug mode enabled"
fi
```

**Arguments:**
- `$1` - Configuration key

**Returns:** `PASS` if true/1/yes, `FAIL` otherwise

#### config::get_path

Get a configuration value as a validated path.

```bash
log_dir=$(config::get_path "log.dir" "/var/log/myapp")
```

**Arguments:**
- `$1` - Configuration key
- `$2` - Default value (optional)

**Returns:** `PASS` if valid path, `FAIL` otherwise

**Outputs:** Path value

### Setting Values

#### config::set

Set a configuration value.

```bash
config::set "app.timeout" "60"
```

**Arguments:**
- `$1` - Configuration key
- `$2` - Value to set

**Returns:** `PASS` on success, `FAIL` if validation fails or locked

#### config::unset

Remove a configuration value.

```bash
config::unset "app.timeout"
```

**Arguments:**
- `$1` - Configuration key

**Returns:** `PASS` always

#### config::reset

Reset a configuration key to its default value.

```bash
config::reset "app.timeout"
```

**Arguments:**
- `$1` - Configuration key

**Returns:** `PASS` on success, `FAIL` if no default exists

### Locking

#### config::lock

Lock a configuration key to prevent changes.

```bash
config::lock "app.mode"
```

**Arguments:**
- `$1` - Configuration key

**Returns:** `PASS` always

#### config::unlock

Unlock a configuration key.

```bash
config::unlock "app.mode"
```

**Arguments:**
- `$1` - Configuration key

**Returns:** `PASS` always

#### config::is_locked

Check if a key is locked.

```bash
if config::is_locked "app.mode"; then
    echo "Cannot modify app.mode"
fi
```

**Arguments:**
- `$1` - Configuration key

**Returns:** `PASS` if locked, `FAIL` otherwise

### Inspection

#### config::list

List all configuration keys and values.

```bash
config::list          # All keys
config::list "log."   # Keys matching pattern
```

**Arguments:**
- `$1` - Filter pattern (optional)

**Output:**
```
KEY                            VALUE                SOURCE          LOCKED
================================================================================
app.timeout                    30                   default         false
log.level                      info                 file            false
```

#### config::show

Show detailed information about a key.

```bash
config::show "app.timeout"
```

**Output:**
```
Configuration: app.timeout
  Value:       30
  Default:     30
  Type:        int
  Source:      default
  Locked:      false
  Description: Connection timeout in seconds
  Validation:  ^[0-9]+$
```

#### config::count

Count number of configuration keys.

```bash
count=$(config::count)
echo "Total keys: ${count}"
```

**Outputs:** Number of keys

### Persistence

#### config::save

Save configuration to a file.

```bash
config::save "/path/to/config"
```

**Arguments:**
- `$1` - File path (optional, uses default path)

**Returns:** `PASS` on success, `FAIL` on error

### Export

#### config::export_env

Export configuration as environment variables.

```bash
eval "$(config::export_env)"
# Now UTIL_CONFIG_APP_TIMEOUT etc. are set
```

**Outputs:** Export statements

#### config::export_json

Export configuration as JSON.

```bash
config::export_json > config.json
```

**Outputs:** JSON object

### Environment Integration

#### config::from_env

Load configuration from environment variables.

```bash
export UTIL_CONFIG_APP_TIMEOUT=60
config::from_env
# Now config::get "app.timeout" returns 60
```

**Returns:** `PASS` always

## Built-in Configuration Keys

### Logging

| Key | Default | Description |
|-----|---------|-------------|
| `log.level` | `info` | Logging level |
| `log.color` | `auto` | Enable colored output |
| `log.timestamp` | `false` | Include timestamps |
| `log.file` | `` | Log file path |
| `log.format` | `text` | Format: text, json |

### Temporary Files

| Key | Default | Description |
|-----|---------|-------------|
| `tmp.dir` | `/tmp` | Temp directory |
| `tmp.mode` | `0700` | Temp file permissions |
| `tmp.cleanup` | `true` | Auto-cleanup on exit |
| `tmp.prefix` | `util` | Temp file prefix |

### Network

| Key | Default | Description |
|-----|---------|-------------|
| `net.timeout` | `30` | Network timeout (seconds) |
| `net.retries` | `3` | Retry attempts |
| `net.retry_delay` | `2` | Delay between retries |
| `net.user_agent` | `util-bash/1.0` | HTTP User-Agent |
| `net.proxy` | `` | Proxy URL |

### File Operations

| Key | Default | Description |
|-----|---------|-------------|
| `file.backup_suffix` | `.bak` | Backup file suffix |
| `file.safe_mode` | `true` | Safety checks enabled |
| `file.checksum_algo` | `sha256` | Default checksum algorithm |

### Package Managers

| Key | Default | Description |
|-----|---------|-------------|
| `apt.auto_update` | `false` | Auto-update before install |
| `apt.auto_repair` | `true` | Auto-repair dependencies |
| `brew.auto_update` | `false` | Auto-update Homebrew |

## Examples

### Application Configuration

```bash
#!/usr/bin/env bash
source util.sh

# Register application-specific configs
config::register "myapp.port" "8080" "int" "Server port" "^[0-9]+$"
config::register "myapp.debug" "false" "bool" "Debug mode"
config::register "myapp.data_dir" "/var/lib/myapp" "path" "Data directory"

# Load user config
config::load "${HOME}/.myapprc"

# Use configuration
port=$(config::get_int "myapp.port")
data_dir=$(config::get_path "myapp.data_dir")

if config::get_bool "myapp.debug"; then
    config::set "log.level" "debug"
fi

echo "Starting on port ${port}..."
```

### Configuration File Format

```ini
# /etc/myapp/config
app.timeout=60
app.debug=true
log.level=debug
log.file=/var/log/myapp.log
```

### Validation Examples

```bash
# Pattern validation (regex)
config::register "port" "8080" "int" "Port number" "^[0-9]{1,5}$"

# List validation (pipe-separated)
config::register "level" "info" "string" "Log level" "debug|info|warn|error"

# Boolean (accepts true/false/yes/no/1/0)
config::register "enabled" "true" "bool" "Feature enabled" "true|false"
```

### Immutable Configuration

```bash
#!/usr/bin/env bash
source util.sh

# Set production values and lock them
config::set "app.mode" "production"
config::lock "app.mode"

# This will fail
config::set "app.mode" "development"  # Returns FAIL
```

## Self-Test

```bash
source util.sh
config::self_test
```

Tests:
- Initialization
- Get/Set operations
- Validation
- Lock/Unlock
- Boolean getter

## Notes

- Configuration keys use dot notation for hierarchy
- Environment variables use uppercase with underscores: `log.level` → `UTIL_CONFIG_LOG_LEVEL`
- Locked keys cannot be modified until unlocked
- Configuration is validated on set, not on get
- The module auto-initializes with defaults when sourced
