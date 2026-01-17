# util_brew.sh - Homebrew Package Manager

Homebrew package management utilities for macOS and Linux with proxy support and spinner integration.

## Overview

This module provides:
- Homebrew installation
- Package (formula) management
- Cask management (GUI apps)
- Tap management
- Updates and cleanup

## Dependencies

- `util_cmd.sh`
- `util_tui.sh`
- `util_os.sh`

## Functions

### Availability

#### brew::is_available

Check if Homebrew is installed.

```bash
if brew::is_available; then
    brew::install "curl"
fi
```

**Returns:** `PASS` (0) if available, `FAIL` (1) otherwise

#### brew::install_self

Install Homebrew on the system.

```bash
brew::install_self
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

### Package Operations

#### brew::install

Install one or more formulas.

```bash
brew::install "curl"
brew::install "vim" "git" "htop"
```

**Arguments:**
- `$@` - Formula names to install

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### brew::uninstall

Uninstall formulas.

```bash
brew::uninstall "package-name"
```

**Arguments:**
- `$@` - Formula names to remove

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### brew::reinstall

Reinstall a formula.

```bash
brew::reinstall "package-name"
```

**Arguments:**
- `$1` - Formula name

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

### Cask Operations

#### brew::cask_install

Install GUI applications via Cask.

```bash
brew::cask_install "visual-studio-code"
brew::cask_install "firefox" "slack"
```

**Arguments:**
- `$@` - Cask names to install

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### brew::cask_uninstall

Uninstall Cask applications.

```bash
brew::cask_uninstall "application-name"
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

### Updates

#### brew::update

Update Homebrew itself.

```bash
brew::update
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### brew::upgrade

Upgrade all installed formulas.

```bash
brew::upgrade
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

### Package Information

#### brew::is_installed

Check if a formula is installed.

```bash
if brew::is_installed "curl"; then
    echo "curl is installed"
fi
```

**Arguments:**
- `$1` - Formula name

**Returns:** `PASS` (0) if installed, `FAIL` (1) otherwise

#### brew::search

Search for formulas.

```bash
brew::search "python"
```

**Arguments:**
- `$1` - Search pattern

**Outputs:** Matching formulas

### Tap Management

#### brew::tap

Add a tap (third-party repository).

```bash
brew::tap "homebrew/cask-fonts"
```

**Arguments:**
- `$1` - Tap name

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### brew::untap

Remove a tap.

```bash
brew::untap "tap-name"
```

**Arguments:**
- `$1` - Tap name

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

### Cleanup

#### brew::cleanup

Remove old versions and clear cache.

```bash
brew::cleanup
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

## Examples

### Install Development Environment

```bash
#!/usr/bin/env bash
source util.sh

if ! brew::is_available; then
    brew::install_self
fi

brew::update

# CLI tools
brew::install "git" "gh" "jq" "fzf"

# GNU tools for macOS
brew::install "coreutils" "findutils" "gnu-sed" "gnu-tar"

# Applications
brew::cask_install "iterm2" "visual-studio-code"

pass "Development environment ready"
```

### Ensure Formula Installed

```bash
#!/usr/bin/env bash
source util.sh

ensure_formula() {
    local formula="$1"
    if ! brew::is_installed "${formula}"; then
        brew::install "${formula}"
    fi
}

ensure_formula "ripgrep"
ensure_formula "fd"
```

## Self-Test

```bash
source util.sh
brew::self_test
```

## Notes

- Homebrew on Apple Silicon installs to `/opt/homebrew`
- Homebrew on Intel/Linux installs to `/usr/local`
- Cask is for GUI applications only
- Some formulas require Xcode Command Line Tools
