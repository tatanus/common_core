# util_py_multi.sh - Multi-Version Python Management

Multi-version Python management utilities. Extends util_py.sh to handle installation and package management across multiple Python versions simultaneously.

## Overview

This module provides:
- Version list management (set, add, remove)
- Multi-version Python installation
- Batch pip operations across versions
- Package verification across versions
- Pipx batch installation with version overrides
- Status reporting and cache management

## Dependencies

- `util_py.sh` - Must be loaded before this module

## Global Variables

| Variable | Type | Description |
|----------|------|-------------|
| `PY_MULTI_VERSIONS` | Array | List of Python versions to manage |
| `PY_MULTI_DEFAULT` | String | Default Python version |
| `PY_MULTI_INSTALL_STATUS` | Assoc Array | Tracks installation results per version |

## Functions

### Version Management

#### py_multi::set_versions

Set the list of Python versions to manage.

```bash
py_multi::set_versions "3.10" "3.11" "3.12"
```

**Arguments:**
- `$@` - Version strings (e.g., "3.10", "3.11", "3.12")

**Returns:** `PASS` (0) always

---

#### py_multi::get_versions

Get the list of configured Python versions.

```bash
versions=($(py_multi::get_versions))
```

**Returns:** `PASS` (0) always

**Outputs:** Version strings, one per line

---

#### py_multi::add_version

Add a version to the managed list.

```bash
py_multi::add_version "3.13"
```

**Arguments:**
- `$1` - Version to add

**Returns:** `PASS` (0) if added or already present, `FAIL` (1) if no version provided

---

#### py_multi::remove_version

Remove a version from the managed list.

```bash
py_multi::remove_version "3.10"
```

**Arguments:**
- `$1` - Version to remove

**Returns:** `PASS` (0) if removed, `FAIL` (1) if not found or no version provided

---

#### py_multi::find_latest

Find the highest version in the managed list.

```bash
latest=$(py_multi::find_latest)
echo "${latest}"  # 3.12
```

**Returns:** `PASS` (0) if found, `FAIL` (1) if no versions configured

**Outputs:** The highest version string (by semantic version sorting)

---

#### py_multi::set_default

Set the default Python version. Also exports `PYTHON_VERSION` and `PYTHON` environment variables.

```bash
py_multi::set_default "3.12"

# Or use latest automatically
py_multi::set_default
```

**Arguments:**
- `$1` - Version to set as default (optional, uses latest if omitted)

**Returns:** `PASS` (0) if set, `FAIL` (1) if version not found

---

#### py_multi::get_default

Get the default Python version.

```bash
default=$(py_multi::get_default)
```

**Returns:** `PASS` (0) always

**Outputs:** The default version string

---

### Multi-Version Installation

#### py_multi::install_all

Install all configured Python versions.

```bash
py_multi::set_versions "3.10" "3.11" "3.12"
py_multi::install_all

# Or force compilation from source
py_multi::install_all --compile
```

**Arguments:**
- `$1` - `--compile` to force compilation from source (optional)

**Returns:** `PASS` (0) if all installed, `FAIL` (1) if any failed

**Side Effects:**
- Populates `PY_MULTI_INSTALL_STATUS` with results
- Sets default to latest installed version

---

#### py_multi::install_pip_all

Install pip for all configured Python versions.

```bash
py_multi::install_pip_all
```

**Returns:** `PASS` (0) if all successful, `FAIL` (1) if any failed

---

#### py_multi::upgrade_pip_all

Upgrade pip for all configured Python versions.

```bash
py_multi::upgrade_pip_all
```

**Returns:** `PASS` (0) if all successful, `FAIL` (1) if any failed

---

### Multi-Version Package Management

#### py_multi::pip_install_all

Install packages for all configured Python versions.

```bash
py_multi::pip_install_all "requests" "flask" "pytest"
```

**Arguments:**
- `$@` - Packages to install

**Returns:** `PASS` (0) if all successful, `FAIL` (1) if any failed

---

#### py_multi::requirements_install_all

Install from requirements.txt for all Python versions.

```bash
py_multi::requirements_install_all "requirements.txt"

# Or use default filename
py_multi::requirements_install_all
```

**Arguments:**
- `$1` - Requirements file (optional, default: `requirements.txt`)

**Returns:** `PASS` (0) if all successful, `FAIL` (1) if any failed

---

#### py_multi::verify_package_all

Verify a package is installed for all Python versions.

```bash
py_multi::verify_package_all "requests"
```

**Arguments:**
- `$1` - Package name

**Returns:** `PASS` (0) if installed for all, `FAIL` (1) if missing for any

**Outputs:** Status and version information for each Python version

---

### Pipx Multi-Version Support

#### py_multi::pipx_install_batch

Install multiple pipx packages with optional version overrides.

```bash
# Define packages array with optional Python version override
declare -a PIPX_PACKAGES=(
    "black"              # Uses default Python
    "mypy|3.11"          # Forces Python 3.11
    "ruff|3.12"          # Forces Python 3.12
    "poetry"             # Uses default Python
)

py_multi::pipx_install_batch "PIPX_PACKAGES"
```

**Arguments:**
- `$1` - Name of array containing package specs (format: `"package"` or `"package|version"`)

**Returns:** `PASS` (0) if all successful, `FAIL` (1) if any failed

---

### Status and Reporting

#### py_multi::status

Display status of all configured Python versions.

```bash
py_multi::status
```

**Output Example:**
```
Python Multi-Version Status:

VERSION      STATUS       PIP        PATH
------------------------------------------------------------
3.10         INSTALLED    OK         /usr/bin/python3.10
3.11         INSTALLED    OK         /usr/bin/python3.11
3.12         INSTALLED    OK         /usr/bin/python3.12 [DEFAULT]
```

**Returns:** `PASS` (0) always

---

#### py_multi::list_installed

List all Python versions currently installed on the system.

```bash
py_multi::list_installed
```

**Output Example:**
```
Installed Python versions:
  - 3.10 (3.10.12)
  - 3.11 (3.11.6)
  - 3.12 (3.12.1)
```

**Returns:** `PASS` (0) always

---

### Cleanup and Maintenance

#### py_multi::cleanup_cache

Clear pip caches for all configured Python versions.

```bash
py_multi::cleanup_cache
```

**Returns:** `PASS` (0) always

---

## Examples

### Basic Multi-Version Setup

```bash
#!/usr/bin/env bash
source util.sh

# Configure versions to manage
py_multi::set_versions "3.10" "3.11" "3.12"

# Install all versions
py_multi::install_all

# Install pip for all
py_multi::install_pip_all

# Set default to latest
py_multi::set_default

# Check status
py_multi::status
```

### Installing Packages Across All Versions

```bash
#!/usr/bin/env bash
source util.sh

py_multi::set_versions "3.10" "3.11" "3.12"

# Install common packages across all versions
py_multi::pip_install_all "requests" "pytest" "black"

# Verify installation
py_multi::verify_package_all "requests"
```

### Using Requirements File

```bash
#!/usr/bin/env bash
source util.sh

py_multi::set_versions "3.11" "3.12"

# Install from requirements.txt for all versions
py_multi::requirements_install_all "requirements.txt"
```

### Pipx Batch Installation

```bash
#!/usr/bin/env bash
source util.sh

py_multi::set_versions "3.11" "3.12"

# Define packages with optional Python version pinning
declare -a DEV_TOOLS=(
    "black"
    "mypy|3.12"
    "ruff"
    "poetry|3.11"
    "pipx"
)

py_multi::pipx_install_batch "DEV_TOOLS"
```

### Dynamic Version Management

```bash
#!/usr/bin/env bash
source util.sh

# Start with base versions
py_multi::set_versions "3.10" "3.11"

# Add experimental version
py_multi::add_version "3.13"

# Install all including experimental
py_multi::install_all

# If 3.13 has issues, remove it
py_multi::remove_version "3.13"

# Check what's still configured
py_multi::get_versions
```

## Self-Test

```bash
source util.sh
py_multi::self_test
```

## Notes

- Requires `util_py.sh` to be loaded first
- Version sorting uses semantic versioning (`sort -V`)
- Skips operations for versions that aren't installed (logs warning)
- The `--compile` flag forces compilation from source (useful for custom builds)
- `PY_MULTI_INSTALL_STATUS` can be inspected for detailed per-version results
