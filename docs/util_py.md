# util_py.sh - Python Environment Management

Python environment, package, and virtual environment management utilities.

## Overview

This module provides:
- Python availability and version detection
- pyenv integration for version management
- Virtual environment management
- Package installation (pip, uv, pipx)
- Requirements file handling
- Python compilation from source
- Automatic `--break-system-packages` detection for modern pip

## Dependencies

- `util_platform.sh` (required, must be loaded first)
- `util_cmd.sh` (for command execution helpers)

## Global Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PY_SOURCE_URL_BASE` | `https://www.python.org/ftp/python` | Base URL for Python source downloads |
| `PY_INSTALL_PREFIX` | `/usr/local` | Default installation prefix for compiled Python |

## Functions

### Availability

#### py::is_available

Check if Python is available on the system.

```bash
if py::is_available; then
    py::get_version
fi
```

**Returns:** `PASS` (0) if available, `FAIL` (1) otherwise

---

#### py::is_version_available

Check if a specific Python version is available.

```bash
if py::is_version_available "3.11"; then
    echo "Python 3.11 is available"
fi
```

**Arguments:**
- `$1` - Version string (e.g., "3.11", "3.12.5")

**Returns:** `PASS` (0) if available, `FAIL` (1) otherwise

---

#### py::pyenv_available

Check if pyenv is installed and available.

```bash
if py::pyenv_available; then
    echo "pyenv is available"
fi
```

**Returns:** `PASS` (0) if pyenv is available, `FAIL` (1) otherwise

---

#### py::pyenv_install_version

Install a specific Python version using pyenv.

```bash
py::pyenv_install_version "3.11.5"
```

**Arguments:**
- `$1` - Full Python version to install (e.g., "3.11.5")

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Notes:**
- Requires pyenv to be installed
- Skips installation if version is already installed

---

### Version Information

#### py::get_version

Get the current Python version.

```bash
version=$(py::get_version)
echo "Python ${version}"
```

**Outputs:** Version string (e.g., "3.11.4")

**Returns:** `PASS` (0) on success, `FAIL` (1) if Python not installed

---

#### py::get_major_version

Get the major Python version number.

```bash
major=$(py::get_major_version)
echo "Python ${major}"  # e.g., "3"
```

**Outputs:** Major version number (2 or 3)

**Returns:** `PASS` (0) on success, `FAIL` (1) if Python not installed

---

#### py::get_path

Get the path to the Python executable.

```bash
python_path=$(py::get_path)
echo "Python at: ${python_path}"
```

**Outputs:** Path to Python executable (defaults to `/usr/bin/python3` if not found)

**Returns:** `PASS` (0)

---

### Pip Arguments and System Packages

#### py::pip_supports_break_system_packages

Check if pip supports the `--break-system-packages` flag (introduced in pip 23.0.1 / Python 3.11+).

```bash
if py::pip_supports_break_system_packages; then
    echo "Modern pip detected"
fi

# Check for specific Python version
if py::pip_supports_break_system_packages "3.12"; then
    echo "Python 3.12 pip supports --break-system-packages"
fi
```

**Arguments:**
- `$1` - Python version (optional, defaults to system python3)

**Outputs:** Prints `--break-system-packages` if supported, empty string otherwise

**Returns:** `PASS` (0) if supported, `FAIL` (1) otherwise

**Notes:** Results are cached per Python version for performance

---

#### py::get_pip_args

Build pip arguments array with auto-detected flags.

```bash
# Get install args with auto-detected flags
local -a args=($(py::get_pip_args "3.12"))
python3 -m pip "${args[@]}" requests

# Custom operation
local -a args=($(py::get_pip_args "" "uninstall"))
```

**Arguments:**
- `$1` - Python version (optional)
- `$2` - Base operation (optional, default: "install")

**Outputs:** Space-separated pip arguments (e.g., "install --break-system-packages")

**Returns:** `PASS` (0)

---

### Python Compilation from Source

#### py::install_build_dependencies

Install system dependencies required for compiling Python from source.

```bash
py::install_build_dependencies
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Notes:**
- On Debian/Ubuntu: installs build-essential, zlib1g-dev, libssl-dev, etc.
- On macOS with Homebrew: installs openssl, readline, sqlite3, etc.

---

#### py::get_latest_patch_version

Get the latest patch version for a Python minor version from python.org.

```bash
latest=$(py::get_latest_patch_version "3.12")
echo "Latest: ${latest}"  # e.g., "3.12.5"
```

**Arguments:**
- `$1` - Minor version (e.g., "3.12")

**Outputs:** Full version string (e.g., "3.12.5")

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

---

#### py::download_source

Download Python source tarball from python.org.

```bash
tarball=$(py::download_source "3.12.5" "/tmp")
echo "Downloaded to: ${tarball}"
```

**Arguments:**
- `$1` - Full Python version (e.g., "3.12.5")
- `$2` - Download directory (optional, default: `/tmp`)

**Outputs:** Path to downloaded tarball

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

---

#### py::compile_from_source

Compile and install Python from source with optimizations.

```bash
# Install specific version
py::compile_from_source "3.12.5"

# Install with custom prefix
py::compile_from_source "3.12.5" "/opt/python"

# Auto-detect latest patch for minor version
py::compile_from_source "3.12"
```

**Arguments:**
- `$1` - Python version (e.g., "3.12" or "3.12.5")
- `$2` - Installation prefix (optional, default: `/usr/local`)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Notes:**
- Automatically installs build dependencies
- Enables optimizations (`--enable-optimizations`, `--with-lto`)
- Uses `make altinstall` to avoid overwriting system Python
- On macOS, automatically configures OpenSSL paths from Homebrew

---

### Python Installation

#### py::install_python

Install a specific version of Python using package manager or source compilation.

```bash
# Install via package manager
py::install_python "3.12"

# Force compilation from source
py::install_python "3.12.5" --compile
```

**Arguments:**
- `$1` - Version (e.g., "3.12" or "3.12.5")
- `$2` - `--compile` to force compilation from source (optional)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Notes:**
- Tries package manager first (Homebrew on macOS, apt on Debian/Ubuntu)
- Falls back to source compilation if package manager fails

---

#### py::install_pip

Install pip for a Python version if not already present.

```bash
py::install_pip
py::install_pip "3.12"  # For specific version
```

**Arguments:**
- `$1` - Python version (optional)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Notes:** Falls back to get-pip.py if ensurepip fails

---

#### py::install_uv

Install uv (fast pip replacement).

```bash
py::install_uv
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

---

#### py::install_pipx

Install pipx for isolated tool installation.

```bash
py::install_pipx
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Notes:** Automatically runs `pipx ensurepath` after installation

---

### Virtual Environments

#### py::create_venv

Create a Python virtual environment.

```bash
py::create_venv "/path/to/venv"
py::create_venv "./venv" "3.11"  # With specific Python version
```

**Arguments:**
- `$1` - Path for virtual environment (optional, default: "venv")
- `$2` - Python version to use (optional)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

---

#### py::activate_venv

Activate an existing virtual environment.

```bash
py::activate_venv "/path/to/venv"
```

**Arguments:**
- `$1` - Path to virtual environment (optional, default: "venv")

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Notes:**
- Must be sourced to work properly
- Prints activation command if not sourced

---

#### py::freeze_requirements

Export current environment to requirements.txt with pinned versions.

```bash
py::freeze_requirements "requirements.txt"
py::freeze_requirements  # Defaults to "requirements.txt"
```

**Arguments:**
- `$1` - Output file path (optional, default: "requirements.txt")

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

---

### Package Installation

#### py::pip_install

Install packages using pip with automatic `--break-system-packages` detection.

```bash
py::pip_install "requests"
py::pip_install "flask" "sqlalchemy" "redis"
```

**Arguments:**
- `$@` - Package names to install

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Notes:** Automatically adds `--break-system-packages` if supported by pip

---

#### py::pip_install_for_version

Install packages for a specific Python version.

```bash
py::pip_install_for_version "3.11" "requests" "flask"
py::pip_install_for_version "3.12" "numpy" "pandas"
```

**Arguments:**
- `$1` - Python version
- `$@` - Package names to install

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

---

#### py::requirements_install

Install packages from a requirements file.

```bash
py::requirements_install "requirements.txt"
py::requirements_install "requirements-dev.txt" "3.12"
```

**Arguments:**
- `$1` - Path to requirements file (optional, default: "requirements.txt")
- `$2` - Python version (optional)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

---

#### py::pip_upgrade

Upgrade pip itself to the latest version.

```bash
py::pip_upgrade
py::pip_upgrade "3.12"  # For specific Python version
```

**Arguments:**
- `$1` - Python version (optional)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

---

#### py::uv_install

Install packages using uv (fast pip replacement).

```bash
py::uv_install "requests"
py::uv_install "flask" "sqlalchemy"
```

**Arguments:**
- `$@` - Package names to install

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Notes:** Requires uv to be installed first

---

#### py::pipx_install

Install a tool using pipx for isolated installation.

```bash
py::pipx_install "black"
py::pipx_install "ruff" "3.12"  # With specific Python version
```

**Arguments:**
- `$1` - Package name
- `$2` - Python version to use (optional)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Notes:** Automatically installs pipx if not present

---

### Package Information

#### py::is_package_installed

Check if a Python package is installed.

```bash
if py::is_package_installed "requests"; then
    echo "requests is installed"
fi

# Check for specific Python version
if py::is_package_installed "numpy" "3.12"; then
    echo "numpy installed for Python 3.12"
fi
```

**Arguments:**
- `$1` - Package name
- `$2` - Python version (optional)

**Returns:** `PASS` (0) if installed, `FAIL` (1) otherwise

---

#### py::get_package_version

Get the version of an installed Python package.

```bash
version=$(py::get_package_version "requests")
echo "requests ${version}"

# For specific Python version
version=$(py::get_package_version "numpy" "3.12")
```

**Arguments:**
- `$1` - Package name
- `$2` - Python version (optional)

**Outputs:** Version string (or "unknown" if not found)

**Returns:** `PASS` (0) if found, `FAIL` (1) otherwise

---

#### py::get_site_packages

Get the path to Python's site-packages directory.

```bash
site=$(py::get_site_packages)
echo "Site packages: ${site}"

# For specific Python version
site=$(py::get_site_packages "3.12")
```

**Arguments:**
- `$1` - Python version (optional)

**Outputs:** Path to site-packages directory

**Returns:** `PASS` (0)

---

### Script Execution

#### py::run_script

Execute a Python script.

```bash
py::run_script "script.py"
py::run_script "script.py" "3.12"  # With specific Python version
```

**Arguments:**
- `$1` - Script path
- `$2` - Python version (optional)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

---

### Self-Test

#### py::self_test

Run self-test for util_py.sh functionality.

```bash
py::self_test
```

**Returns:** `PASS` (0) if all tests pass, `FAIL` (1) otherwise

---

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

### Compile Python from Source

```bash
#!/usr/bin/env bash
source util.sh

# Install latest Python 3.12 patch version from source
py::compile_from_source "3.12"

# Or install a specific version
py::compile_from_source "3.11.8" "/opt/python311"
```

### Version-Specific Package Installation

```bash
#!/usr/bin/env bash
source util.sh

# Install different packages for different Python versions
if py::is_version_available "3.11"; then
    py::pip_install_for_version "3.11" "legacy-package"
fi

if py::is_version_available "3.12"; then
    py::pip_install_for_version "3.12" "modern-package"
fi
```

### Using pyenv

```bash
#!/usr/bin/env bash
source util.sh

# Check if pyenv is available and install Python
if py::pyenv_available; then
    py::pyenv_install_version "3.12.3"
else
    # Fall back to package manager or source compilation
    py::install_python "3.12"
fi
```

## Self-Test

```bash
source util.sh
py::self_test
```
