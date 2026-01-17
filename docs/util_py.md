# util_py.sh - Python Environment Management

Python environment, package, and virtual environment management utilities.

## Overview

This module provides:
- Python availability and version detection
- Virtual environment management
- Package installation (pip, uv, pipx)
- Requirements file handling
- Python version management

## Dependencies

- `util_cmd.sh`
- `util_platform.sh`

## Functions

### Availability

#### py::is_available

Check if Python is available.

```bash
if py::is_available; then
    py::get_version
fi
```

**Returns:** `PASS` (0) if available, `FAIL` (1) otherwise

#### py::is_version_available

Check if a specific Python version is available.

```bash
if py::is_version_available "3.11"; then
    echo "Python 3.11 is available"
fi
```

**Arguments:**
- `$1` - Version (e.g., "3.11", "3.10")

**Returns:** `PASS` (0) if available, `FAIL` (1) otherwise

### Version Information

#### py::get_version

Get the Python version.

```bash
version=$(py::get_version)
echo "Python ${version}"
```

**Outputs:** Version string (e.g., "3.11.4")

#### py::get_major_version

Get the major Python version.

```bash
major=$(py::get_major_version)
echo "Python ${major}"  # e.g., "3"
```

**Outputs:** Major version number

#### py::get_path

Get the path to the Python executable.

```bash
python_path=$(py::get_path)
echo "Python at: ${python_path}"
```

**Outputs:** Path to Python executable

### Virtual Environments

#### py::create_venv

Create a virtual environment.

```bash
py::create_venv "/path/to/venv"
py::create_venv "./venv" "3.11"  # Specific Python version
```

**Arguments:**
- `$1` - Path for virtual environment
- `$2` - Python version (optional)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### py::activate_venv

Activate a virtual environment.

```bash
py::activate_venv "/path/to/venv"
```

**Arguments:**
- `$1` - Path to virtual environment

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Notes:** Sources the activate script

### Package Installation

#### py::pip_install

Install packages using pip.

```bash
py::pip_install "requests"
py::pip_install "flask" "sqlalchemy" "redis"
```

**Arguments:**
- `$@` - Package names to install

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### py::pip_install_for_version

Install packages for a specific Python version.

```bash
py::pip_install_for_version "3.11" "requests" "flask"
```

**Arguments:**
- `$1` - Python version
- `$@` - Package names

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### py::requirements_install

Install packages from requirements file.

```bash
py::requirements_install "requirements.txt"
```

**Arguments:**
- `$1` - Path to requirements file

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### py::pip_upgrade

Upgrade a package.

```bash
py::pip_upgrade "pip"
py::pip_upgrade "requests"
```

**Arguments:**
- `$1` - Package name to upgrade

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

### Modern Tools

#### py::install_uv

Install uv (fast pip replacement).

```bash
py::install_uv
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### py::uv_install

Install packages using uv.

```bash
py::uv_install "requests"
```

**Arguments:**
- `$@` - Package names

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### py::install_pipx

Install pipx for isolated tool installation.

```bash
py::install_pipx
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### py::pipx_install

Install a tool using pipx.

```bash
py::pipx_install "black"
py::pipx_install "ruff"
```

**Arguments:**
- `$1` - Package name

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

### Package Information

#### py::is_package_installed

Check if a package is installed.

```bash
if py::is_package_installed "requests"; then
    echo "requests is installed"
fi
```

**Arguments:**
- `$1` - Package name

**Returns:** `PASS` (0) if installed, `FAIL` (1) otherwise

#### py::get_package_version

Get installed package version.

```bash
version=$(py::get_package_version "requests")
echo "requests ${version}"
```

**Arguments:**
- `$1` - Package name

**Outputs:** Version string

#### py::get_site_packages

Get the site-packages directory.

```bash
site=$(py::get_site_packages)
echo "Site packages: ${site}"
```

**Outputs:** Path to site-packages

#### py::freeze_requirements

Generate requirements.txt from installed packages.

```bash
py::freeze_requirements > requirements.txt
```

**Outputs:** Requirements in pip freeze format

### Script Execution

#### py::run_script

Run a Python script.

```bash
py::run_script "script.py"
py::run_script "script.py" arg1 arg2
```

**Arguments:**
- `$1` - Script path
- `$@` - Script arguments

**Returns:** Exit code of the script

## Examples

### Project Setup

```bash
#!/usr/bin/env bash
source util.sh

setup_python_project() {
    local project_dir="$1"
    
    cd "${project_dir}" || return "${FAIL}"
    
    # Create virtual environment
    py::create_venv ".venv"
    py::activate_venv ".venv"
    
    # Install dependencies
    if [[ -f "requirements.txt" ]]; then
        py::requirements_install "requirements.txt"
    fi
    
    pass "Project ready"
}
```

### Install Development Tools

```bash
#!/usr/bin/env bash
source util.sh

# Install pipx first
py::install_pipx

# Install development tools globally
py::pipx_install "black"
py::pipx_install "ruff"
py::pipx_install "mypy"
py::pipx_install "pre-commit"
```

## Self-Test

```bash
source util.sh
py::self_test
```
