# util_apt.sh - APT Package Manager

Debian/Ubuntu package management utilities with proxy support, spinner integration, and automatic dependency handling.

## Overview

This module provides:
- Package installation and removal
- Package search and information
- Repository management
- System updates and upgrades
- Dependency handling

## Dependencies

- `util_cmd.sh`
- `util_tui.sh`

## Functions

### Availability

#### apt::is_available

Check if APT is available.

```bash
if apt::is_available; then
    apt::install "curl"
fi
```

**Returns:** `PASS` (0) if available, `FAIL` (1) otherwise

### Package Operations

#### apt::install

Install one or more packages.

```bash
apt::install "curl"
apt::install "vim" "git" "htop"
```

**Arguments:**
- `$@` - Package names to install

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### apt::remove

Remove one or more packages.

```bash
apt::remove "package-name"
```

**Arguments:**
- `$@` - Package names to remove

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### apt::purge

Remove packages and their configuration.

```bash
apt::purge "package-name"
```

**Arguments:**
- `$@` - Package names to purge

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

### Updates

#### apt::update

Update package lists.

```bash
apt::update
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### apt::upgrade

Upgrade installed packages.

```bash
apt::upgrade
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### apt::full_upgrade

Perform full system upgrade.

```bash
apt::full_upgrade
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

### Package Information

#### apt::is_installed

Check if a package is installed.

```bash
if apt::is_installed "curl"; then
    echo "curl is installed"
fi
```

**Arguments:**
- `$1` - Package name

**Returns:** `PASS` (0) if installed, `FAIL` (1) otherwise

#### apt::get_version

Get installed package version.

```bash
version=$(apt::get_version "curl")
echo "curl version: ${version}"
```

**Arguments:**
- `$1` - Package name

**Outputs:** Version string

#### apt::search

Search for packages.

```bash
apt::search "python"
```

**Arguments:**
- `$1` - Search pattern

**Outputs:** Matching packages

### Cleanup

#### apt::autoremove

Remove unused packages.

```bash
apt::autoremove
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### apt::clean

Clean package cache.

```bash
apt::clean
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

### Repository Management

#### apt::add_repo

Add a PPA repository.

```bash
apt::add_repo "ppa:deadsnakes/ppa"
```

**Arguments:**
- `$1` - Repository PPA string

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

## Examples

### Install Development Tools

```bash
#!/usr/bin/env bash
source util.sh

if apt::is_available; then
    apt::update
    apt::install "build-essential" "git" "curl" "wget"
    pass "Development tools installed"
fi
```

### Conditional Installation

```bash
#!/usr/bin/env bash
source util.sh

ensure_package() {
    local pkg="$1"
    if ! apt::is_installed "${pkg}"; then
        apt::install "${pkg}"
    fi
}

ensure_package "curl"
ensure_package "jq"
```

## Self-Test

```bash
source util.sh
apt::self_test
```
