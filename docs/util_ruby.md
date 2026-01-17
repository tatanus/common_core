# util_ruby.sh - Ruby Environment Management

Ruby environment, gem, and bundler management utilities.

## Overview

This module provides:
- Ruby availability and version detection
- Gem installation and management
- Bundler operations
- RVM/rbenv support

## Dependencies

- `util_cmd.sh`
- `util_tui.sh`

## Functions

### Availability

#### ruby::is_available

Check if Ruby is available.

```bash
if ruby::is_available; then
    ruby::get_version
fi
```

**Returns:** `PASS` (0) if available, `FAIL` (1) otherwise

#### ruby::get_version

Get the Ruby version.

```bash
version=$(ruby::get_version)
echo "Ruby ${version}"
```

**Outputs:** Version string

### Gem Management

#### ruby::gem_install

Install one or more gems.

```bash
ruby::gem_install "bundler"
ruby::gem_install "rails" "puma" "pg"
```

**Arguments:**
- `$@` - Gem names to install

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### ruby::gem_update

Update all installed gems.

```bash
ruby::gem_update
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### ruby::is_gem_installed

Check if a gem is installed.

```bash
if ruby::is_gem_installed "rails"; then
    echo "Rails is installed"
fi
```

**Arguments:**
- `$1` - Gem name

**Returns:** `PASS` (0) if installed, `FAIL` (1) otherwise

### Bundler Operations

#### ruby::bundler_install

Run bundle install.

```bash
ruby::bundler_install
ruby::bundler_install "--deployment"
```

**Arguments:**
- `$@` - Additional bundler arguments

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### ruby::bundler_exec

Execute a command via bundler.

```bash
ruby::bundler_exec rails server
ruby::bundler_exec rake db:migrate
```

**Arguments:**
- `$@` - Command to execute

**Returns:** Exit code of command

## Examples

### Rails Project Setup

```bash
#!/usr/bin/env bash
source util.sh

setup_rails() {
    local project_dir="$1"
    cd "${project_dir}" || return "${FAIL}"
    
    # Install bundler if needed
    if ! ruby::is_gem_installed "bundler"; then
        ruby::gem_install "bundler"
    fi
    
    # Install dependencies
    ruby::bundler_install
    
    # Setup database
    ruby::bundler_exec rake db:setup
    
    pass "Rails project ready"
}
```

## Self-Test

```bash
source util.sh
ruby::self_test
```
