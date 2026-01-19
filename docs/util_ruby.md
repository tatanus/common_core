# util_ruby.sh - Ruby Environment and Gem Management

Ruby environment, gem, and bundler management utilities with proxy support and batch operations.

## Overview

This module provides:
- Ruby and gem detection
- Version-specific gem installation
- Batch gem installation from arrays
- Proxy support for corporate environments
- rbenv and RVM detection
- Bundler project management
- Environment information reporting

## Dependencies

None (standalone module)

## Global Variables

| Variable | Type | Description |
|----------|------|-------------|
| `RUBY_GEMS` | Array | Default array for batch gem operations |
| `PROXY` | String | Optional proxy URL or `VAR=value` format |

## Functions

### Ruby Detection and Environment

#### ruby::is_available

Check if Ruby is installed.

```bash
if ruby::is_available; then
    echo "Ruby detected"
fi
```

**Returns:** `PASS` (0) if installed, `FAIL` (1) otherwise

---

#### ruby::gem_available

Check if gem command is available.

```bash
if ruby::gem_available; then
    echo "gem command available"
fi
```

**Returns:** `PASS` (0) if available, `FAIL` (1) otherwise

---

#### ruby::get_version

Get the current Ruby version.

```bash
version=$(ruby::get_version)
echo "Ruby ${version}"
```

**Returns:** `PASS` (0) on success, `FAIL` (1) if Ruby not installed

**Outputs:** Ruby version string (e.g., `3.2.0`)

---

#### ruby::get_path

Get the path to the Ruby executable.

```bash
path=$(ruby::get_path)
echo "Ruby at: ${path}"
```

**Returns:** `PASS` (0) always

**Outputs:** Path to Ruby executable

---

#### ruby::rbenv_available

Check if rbenv is installed.

```bash
if ruby::rbenv_available; then
    echo "Using rbenv for version management"
fi
```

**Returns:** `PASS` (0) if installed, `FAIL` (1) otherwise

---

#### ruby::rvm_available

Check if RVM is installed.

```bash
if ruby::rvm_available; then
    echo "Using RVM for version management"
fi
```

**Returns:** `PASS` (0) if installed, `FAIL` (1) otherwise

---

### Gem Management - Core Functions

#### ruby::gem_install

Install one or more gems globally (simple names only).

```bash
ruby::gem_install "bundler" "rake" "pry"
```

**Arguments:**
- `$@` - Gem names to install

**Returns:** `PASS` (0) if all successful, `FAIL` (1) if any failed

**Notes:** For version-specific installs, use `ruby::gem_install_spec`

---

#### ruby::gem_install_spec

Install a gem with version specification.

```bash
ruby::gem_install_spec "nori -v 2.6.0"
ruby::gem_install_spec "rails --version=7.0.0"
ruby::gem_install_spec "evil-winrm"
```

**Arguments:**
- `$1` - Gem specification string (name + optional version flags)

**Supported Version Formats:**
- `-v 2.6.0`
- `-v2.6.0`
- `--version 2.6.0`
- `--version=2.6.0`

**Returns:** `PASS` (0) if successful, `FAIL` (1) otherwise

---

#### ruby::gem_install_batch

Install gems from an array of specifications.

```bash
declare -a RUBY_GEMS=(
    "bundler"
    "nori -v 2.6.0"
    "evil-winrm"
    "rails --version=7.0.0"
)

ruby::gem_install_batch "RUBY_GEMS"

# Or use the default RUBY_GEMS array
ruby::gem_install_batch
```

**Arguments:**
- `$1` - Array name containing gem specs (optional, defaults to `RUBY_GEMS`)

**Exit Codes:**
- `0` - All gems installed successfully
- `1` - One or more install/verify failures
- `2` - gem binary not found
- `3` - Gem array not defined or empty

---

#### ruby::gem_install_with_version

Install a specific version of a gem.

```bash
ruby::gem_install_with_version "rails" "7.0.0"
```

**Arguments:**
- `$1` - Gem name (required)
- `$2` - Version (required)

**Returns:** `PASS` (0) if successful, `FAIL` (1) otherwise

---

#### ruby::gem_update

Update all installed gems.

```bash
ruby::gem_update
```

**Returns:** `PASS` (0) if successful, `FAIL` (1) otherwise

---

#### ruby::gem_uninstall

Uninstall a gem.

```bash
# Uninstall all versions
ruby::gem_uninstall "outdated-gem"

# Uninstall specific version
ruby::gem_uninstall "rails" "6.1.0"
```

**Arguments:**
- `$1` - Gem name (required)
- `$2` - Version (optional, uninstalls all versions if omitted)

**Returns:** `PASS` (0) if successful, `FAIL` (1) otherwise

---

#### ruby::gem_cleanup

Remove old gem versions.

```bash
ruby::gem_cleanup
```

**Returns:** `PASS` (0) if successful, `FAIL` (1) otherwise

---

#### ruby::is_gem_installed

Check if a specific gem is installed.

```bash
if ruby::is_gem_installed "bundler"; then
    echo "Bundler available"
fi

# Check for specific version
if ruby::is_gem_installed "nori" "2.6.0"; then
    echo "nori 2.6.0 installed"
fi
```

**Arguments:**
- `$1` - Gem name (required)
- `$2` - Version (optional)

**Returns:** `PASS` (0) if installed, `FAIL` (1) otherwise

---

#### ruby::get_gem_version

Get the version of a specific installed gem.

```bash
version=$(ruby::get_gem_version "bundler")
echo "Bundler version: ${version}"
```

**Arguments:**
- `$1` - Gem name

**Returns:** `PASS` (0) if found, `FAIL` (1) otherwise

**Outputs:** Version string or `unknown`

---

### Version Management

#### ruby::install_rbenv

Install rbenv for Ruby version management.

```bash
ruby::install_rbenv
```

**Returns:** `PASS` (0) if successful, `FAIL` (1) otherwise

**Notes:** Also installs ruby-build plugin

---

#### ruby::rbenv_install_version

Install a specific Ruby version via rbenv.

```bash
ruby::rbenv_install_version "3.2.0"
```

**Arguments:**
- `$1` - Ruby version to install

**Returns:** `PASS` (0) if successful, `FAIL` (1) otherwise

---

### Bundler and Project Tools

#### ruby::bundler_install

Install Bundler if not already installed.

```bash
ruby::bundler_install
```

**Returns:** `PASS` (0) if installed, `FAIL` (1) otherwise

---

#### ruby::get_bundler_version

Get Bundler major version (1 or 2).

```bash
major=$(ruby::get_bundler_version)
echo "Bundler major version: ${major}"
```

**Returns:** `PASS` (0) on success, `FAIL` (1) if Bundler not installed

**Outputs:** Major version number

---

#### ruby::bundle_install

Install project dependencies via Bundler.

```bash
cd /path/to/project
ruby::bundle_install
```

**Returns:** `PASS` (0) if successful, `FAIL` (1) otherwise

---

#### ruby::bundle_exec

Execute a command in bundle context.

```bash
ruby::bundle_exec rake db:migrate
ruby::bundle_exec rspec spec/
```

**Arguments:**
- `$@` - Command and arguments to execute

**Returns:** Exit code of the executed command

---

#### ruby::run_script

Execute a Ruby script.

```bash
ruby::run_script "./script.rb"
```

**Arguments:**
- `$1` - Script path

**Returns:** `PASS` (0) if successful, `FAIL` (1) otherwise

---

### Utility Functions

#### ruby::list_gems

List all installed gems.

```bash
ruby::list_gems
```

**Returns:** `PASS` (0) on success

**Outputs:** Gem list

---

#### ruby::gem_outdated

List outdated gems.

```bash
ruby::gem_outdated
```

**Returns:** `PASS` (0) always

**Outputs:** List of outdated gems

---

#### ruby::env_info

Display Ruby environment information.

```bash
ruby::env_info
```

**Output Example:**
```
Ruby Environment Information:
=============================
Ruby version: 3.2.0
Ruby path:    /usr/bin/ruby
Gem path:     /usr/bin/gem
Gem version:  3.4.1
Bundler:      v2.4.0
rbenv:        AVAILABLE
```

**Returns:** `PASS` (0) always

---

## Examples

### Basic Gem Installation

```bash
#!/usr/bin/env bash
source util.sh

# Install individual gems
ruby::gem_install "bundler" "rake"

# Install with version
ruby::gem_install_spec "rails -v 7.0.0"
```

### Batch Installation with Proxy

```bash
#!/usr/bin/env bash
source util.sh

# Set proxy for corporate environment
export PROXY="http://proxy.example.com:8080"

# Define gems to install
declare -a MY_GEMS=(
    "bundler"
    "nori -v 2.6.0"
    "rubocop"
    "rspec"
)

# Install all gems
ruby::gem_install_batch "MY_GEMS"
```

### Project Setup

```bash
#!/usr/bin/env bash
source util.sh

setup_ruby_project() {
    # Ensure Ruby is available
    if ! ruby::is_available; then
        error "Ruby not installed"
        return 1
    fi

    # Install bundler
    ruby::bundler_install

    # Install project dependencies
    ruby::bundle_install

    # Run tests
    ruby::bundle_exec rspec spec/
}

setup_ruby_project
```

### Version Management with rbenv

```bash
#!/usr/bin/env bash
source util.sh

# Install rbenv if needed
if ! ruby::rbenv_available; then
    ruby::install_rbenv
    # Note: Need to restart shell or source rbenv init
fi

# Install specific Ruby version
ruby::rbenv_install_version "3.2.0"
```

### Checking Environment

```bash
#!/usr/bin/env bash
source util.sh

# Display full environment info
ruby::env_info

# Check for specific gems
if ruby::is_gem_installed "rails"; then
    version=$(ruby::get_gem_version "rails")
    echo "Rails ${version} is installed"
fi

# List outdated gems
ruby::gem_outdated
```

## Self-Test

```bash
source util.sh
ruby::self_test
```

## Proxy Support

The module supports proxies through the `PROXY` environment variable:

```bash
# URL format
export PROXY="http://proxy.example.com:8080"

# VAR=value format
export PROXY="http_proxy=http://proxy.example.com:8080"
```

When set, all gem operations will use the proxy automatically.

## Notes

- Uses `--no-document` flag for faster gem installation
- Proxy support for corporate environments
- Verification after each gem installation
- Compatible with rbenv and RVM
- Supports multiple version specification formats
