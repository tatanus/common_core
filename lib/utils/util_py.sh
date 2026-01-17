#!/usr/bin/env bash
###############################################################################
# NAME         : util_py.sh
# DESCRIPTION  : Python installation, virtual environment, and package utilities.
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-10-27
###############################################################################
# EDIT HISTORY:
# DATE        | EDITED BY      | DESCRIPTION
# ------------|----------------|-----------------------------------------------
# 2025-10-27  | Adam Compton   | Initial generation (style-guide compliant)
# 2025-12-26  | Adam Compton   | Added --break-system-packages auto-detection,
#             |                | compile-from-source support, version-specific
#             |                | pip operations, and build dependency helpers
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Library Guard
#===============================================================================
if [[ -n "${UTIL_PY_SH_LOADED:-}" ]]; then
    if (return 0 2> /dev/null); then
        return 0
    fi
else
    UTIL_PY_SH_LOADED=1
fi

#===============================================================================
# Module Dependencies
#===============================================================================
if [[ "${UTIL_PLATFORM_SH_LOADED:-0}" -eq 0 ]]; then
    echo "ERROR: util_platform.sh must be loaded before util_py.sh" >&2
    return 1
fi

#===============================================================================
# Logging Fallbacks
#===============================================================================
if ! declare -F info > /dev/null 2>&1; then
    function info() { printf '[INFO ] %s\n' "${*}" >&2; }
fi
if ! declare -F warn > /dev/null 2>&1; then
    function warn() { printf '[WARN ] %s\n' "${*}" >&2; }
fi
if ! declare -F error > /dev/null 2>&1; then
    function error() { printf '[ERROR] %s\n' "${*}" >&2; }
fi
if ! declare -F debug > /dev/null 2>&1; then
    function debug() { printf '[DEBUG] %s\n' "${*}" >&2; }
fi
if ! declare -F pass > /dev/null 2>&1; then
    function pass() { printf '[PASS ] %s\n' "${*}" >&2; }
fi
if ! declare -F fail > /dev/null 2>&1; then
    function fail() { printf '[FAIL ] %s\n' "${*}" >&2; }
fi

#===============================================================================
# Globals
#===============================================================================
: "${PASS:=0}"
: "${FAIL:=1}"

# Cache for --break-system-packages detection (per Python version)
declare -gA _PY_BREAK_SYSTEM_PACKAGES_CACHE

# Python source download URL base
readonly PY_SOURCE_URL_BASE="https://www.python.org/ftp/python"

# Default installation prefix for compiled Python
: "${PY_INSTALL_PREFIX:=/usr/local}"

#===============================================================================
# Internal Helpers
#===============================================================================

###############################################################################
# py::_get_python_cmd
#------------------------------------------------------------------------------
# Purpose  : Get the python command for a specific version
# Usage    : cmd=$(py::_get_python_cmd "3.12")
# Arguments:
#   $1 : Version string (e.g., "3.12" or "3.12.5")
# Returns  : Prints python command path or empty string
###############################################################################
function py::_get_python_cmd() {
    local version="${1:-}"

    if [[ -z "${version}" ]]; then
        command -v python3 2> /dev/null || command -v python 2> /dev/null || true
        return "${PASS}"
    fi

    # Try exact version first (e.g., python3.12)
    local minor_ver="${version%.*}"
    if [[ "${minor_ver}" == "${version}" ]]; then
        # No patch version, use as-is
        minor_ver="${version}"
    fi

    # Remove leading 3. if present for the command
    local cmd_ver="${minor_ver}"

    if cmd::exists "python${cmd_ver}"; then
        command -v "python${cmd_ver}"
        return "${PASS}"
    fi

    # Try just python3
    if cmd::exists python3; then
        command -v python3
        return "${PASS}"
    fi

    return "${FAIL}"
}

#===============================================================================
# Python Availability and Info
#===============================================================================

###############################################################################
# py::is_available
#------------------------------------------------------------------------------
# Purpose  : Check if Python is installed (python3 preferred).
# Usage    : py::is_available && info "Python detected"
# Returns  : PASS if installed, FAIL otherwise.
###############################################################################
function py::is_available() {
    if cmd::exists python3 || cmd::exists python; then
        debug "Python is available"
        return "${PASS}"
    fi
    debug "Python not found"
    return "${FAIL}"
}

###############################################################################
# py::is_version_available
#------------------------------------------------------------------------------
# Purpose  : Check if a specific Python version is installed.
# Usage    : py::is_version_available "3.12"
# Arguments:
#   $1 : Version string (e.g., "3.12")
# Returns  : PASS if installed, FAIL otherwise.
###############################################################################
function py::is_version_available() {
    local version="${1:-}"

    if [[ -z "${version}" ]]; then
        error "py::is_version_available requires a version"
        return "${FAIL}"
    fi

    local python_cmd
    python_cmd=$(py::_get_python_cmd "${version}")

    if [[ -n "${python_cmd}" ]]; then
        # Verify the version matches
        local installed_ver
        installed_ver=$("${python_cmd}" --version 2>&1 | awk '{print $2}')
        if [[ "${installed_ver}" == "${version}"* ]]; then
            debug "Python ${version} available: ${python_cmd}"
            return "${PASS}"
        fi
    fi

    debug "Python ${version} not available"
    return "${FAIL}"
}

###############################################################################
# py::get_major_version
#------------------------------------------------------------------------------
# Purpose  : Get major Python version (2 or 3)
# Usage    : major=$(py::get_major_version)
# Returns  : Prints major version (2 or 3)
###############################################################################
function py::get_major_version() {
    if ! py::is_available; then
        error "Python not installed"
        return "${FAIL}"
    fi

    local version
    version=$(py::get_version)
    printf '%s\n' "${version%%.*}"
    return "${PASS}"
}

###############################################################################
# py::pyenv_available
#------------------------------------------------------------------------------
# Purpose  : Check if pyenv is installed
# Usage    : py::pyenv_available && use_pyenv=true
# Returns  : PASS if available, FAIL otherwise
###############################################################################
function py::pyenv_available() {
    if cmd::exists pyenv; then
        debug "pyenv available at $(command -v pyenv)"
        return "${PASS}"
    fi
    debug "pyenv not available"
    return "${FAIL}"
}

###############################################################################
# py::pyenv_install_version
#------------------------------------------------------------------------------
# Purpose  : Install specific Python version via pyenv
# Usage    : py::pyenv_install_version "3.11.5"
# Returns  : PASS if successful, FAIL otherwise
###############################################################################
function py::pyenv_install_version() {
    local version="${1:-}"

    if [[ -z "${version}" ]]; then
        error "py::pyenv_install_version requires a version"
        return "${FAIL}"
    fi

    if ! py::pyenv_available; then
        error "pyenv not installed"
        return "${FAIL}"
    fi

    # Check if already installed
    if pyenv versions --bare | grep -qx "${version}"; then
        info "Python ${version} already installed via pyenv"
        return "${PASS}"
    fi

    info "Installing Python ${version} via pyenv..."
    if cmd::run pyenv install "${version}"; then
        pass "Python ${version} installed"
        return "${PASS}"
    fi

    fail "Failed to install Python ${version}"
    return "${FAIL}"
}

###############################################################################
# py::get_path
#------------------------------------------------------------------------------
# Purpose  : Get the path to the active Python binary.
# Usage    : py::get_path
# Returns  : Prints path to Python binary.
###############################################################################
function py::get_path() {
    local path
    path="$(command -v python3 2> /dev/null || command -v python 2> /dev/null || true)"
    printf '%s\n' "${path:-/usr/bin/python3}"
    return "${PASS}"
}

###############################################################################
# py::get_version
#------------------------------------------------------------------------------
# Purpose  : Get current Python version.
# Usage    : py::get_version
# Returns  : Prints version or FAIL if not available.
###############################################################################
function py::get_version() {
    if ! py::is_available; then
        error "Python not installed"
        return "${FAIL}"
    fi
    local version
    version="$(python3 --version 2> /dev/null || python --version 2> /dev/null | awk '{print $2}')"
    printf '%s\n' "${version:-unknown}"
    return "${PASS}"
}

#===============================================================================
# --break-system-packages Support
#===============================================================================

###############################################################################
# py::pip_supports_break_system_packages
#------------------------------------------------------------------------------
# Purpose  : Check if pip supports --break-system-packages flag
# Usage    : py::pip_supports_break_system_packages ["3.12"]
# Arguments:
#   $1 : Python version (optional, defaults to system python3)
# Returns  : PASS if supported, FAIL otherwise
# Outputs  : Prints "--break-system-packages" if supported, empty otherwise
###############################################################################
function py::pip_supports_break_system_packages() {
    local version="${1:-}"
    local python_cmd

    python_cmd=$(py::_get_python_cmd "${version}")
    if [[ -z "${python_cmd}" ]]; then
        return "${FAIL}"
    fi

    # Check cache first
    local cache_key="${python_cmd}"
    if [[ -n "${_PY_BREAK_SYSTEM_PACKAGES_CACHE[${cache_key}]+x}" ]]; then
        local cached="${_PY_BREAK_SYSTEM_PACKAGES_CACHE[${cache_key}]}"
        [[ -n "${cached}" ]] && printf '%s\n' "${cached}"
        [[ -n "${cached}" ]] && return "${PASS}" || return "${FAIL}"
    fi

    # Check if pip help mentions --break-system-packages
    if "${python_cmd}" -m pip help install 2>&1 | grep -q "break-system-packages"; then
        _PY_BREAK_SYSTEM_PACKAGES_CACHE[${cache_key}]="--break-system-packages"
        printf '%s\n' "--break-system-packages"
        return "${PASS}"
    fi

    _PY_BREAK_SYSTEM_PACKAGES_CACHE[${cache_key}]=""
    return "${FAIL}"
}

###############################################################################
# py::get_pip_args
#------------------------------------------------------------------------------
# Purpose  : Build pip arguments array with auto-detected flags
# Usage    : local -a args=($(py::get_pip_args "3.12"))
# Arguments:
#   $1 : Python version (optional)
#   $2 : Base operation (optional, default: "install")
# Returns  : Prints space-separated pip arguments
###############################################################################
function py::get_pip_args() {
    local version="${1:-}"
    local operation="${2:-install}"

    local -a args=("${operation}")

    # Add --break-system-packages if supported
    local break_flag
    if break_flag=$(py::pip_supports_break_system_packages "${version}"); then
        args+=("${break_flag}")
    fi

    printf '%s\n' "${args[*]}"
    return "${PASS}"
}

#===============================================================================
# Python Compilation from Source
#===============================================================================

###############################################################################
# py::install_build_dependencies
#------------------------------------------------------------------------------
# Purpose  : Install dependencies required for compiling Python from source
# Usage    : py::install_build_dependencies
# Returns  : PASS if successful, FAIL otherwise
###############################################################################
function py::install_build_dependencies() {
    info "Installing Python build dependencies..."

    if os::is_linux && apt::is_available; then
        local -a deps=(
            build-essential
            zlib1g-dev
            libncurses5-dev
            libgdbm-dev
            libnss3-dev
            libssl-dev
            libreadline-dev
            libffi-dev
            libsqlite3-dev
            libbz2-dev
            liblzma-dev
            tk-dev
            uuid-dev
            wget
            curl
        )

        if cmd::elevate apt-get update && cmd::elevate apt-get install -y "${deps[@]}"; then
            pass "Build dependencies installed"
            return "${PASS}"
        fi

        fail "Failed to install build dependencies"
        return "${FAIL}"

    elif os::is_macos && brew::is_available; then
        local -a deps=(
            openssl
            readline
            sqlite3
            xz
            zlib
            tcl-tk
        )

        if brew install "${deps[@]}"; then
            pass "Build dependencies installed"
            return "${PASS}"
        fi

        fail "Failed to install build dependencies"
        return "${FAIL}"
    fi

    warn "Unsupported platform for automatic dependency installation"
    return "${FAIL}"
}

###############################################################################
# py::get_latest_patch_version
#------------------------------------------------------------------------------
# Purpose  : Get the latest patch version for a minor Python version
# Usage    : patch=$(py::get_latest_patch_version "3.12")
# Arguments:
#   $1 : Minor version (e.g., "3.12")
# Returns  : Prints full version string (e.g., "3.12.5")
###############################################################################
function py::get_latest_patch_version() {
    local minor_version="${1:-}"

    if [[ -z "${minor_version}" ]]; then
        error "py::get_latest_patch_version requires a minor version"
        return "${FAIL}"
    fi

    info "Fetching latest patch version for Python ${minor_version}..."

    local html
    if ! html=$(curl -fsSL "${PY_SOURCE_URL_BASE}/" 2> /dev/null); then
        fail "Failed to fetch Python versions list"
        return "${FAIL}"
    fi

    # Parse the version listing - look for directories matching minor_version.X
    local latest
    latest=$(printf '%s\n' "${html}" |
        grep -oE "href=\"${minor_version}\.[0-9]+/\"" |
        grep -oE "${minor_version}\.[0-9]+" |
        sort -V |
        tail -n 1)

    if [[ -z "${latest}" ]]; then
        fail "No patch versions found for Python ${minor_version}"
        return "${FAIL}"
    fi

    debug "Latest patch version: ${latest}"
    printf '%s\n' "${latest}"
    return "${PASS}"
}

###############################################################################
# py::download_source
#------------------------------------------------------------------------------
# Purpose  : Download Python source tarball
# Usage    : py::download_source "3.12.5" "/tmp"
# Arguments:
#   $1 : Full version (e.g., "3.12.5")
#   $2 : Download directory (optional, default: /tmp)
# Returns  : PASS if successful; prints tarball path
###############################################################################
function py::download_source() {
    local version="${1:-}"
    local dest_dir="${2:-/tmp}"

    if [[ -z "${version}" ]]; then
        error "py::download_source requires a version"
        return "${FAIL}"
    fi

    local tarball="Python-${version}.tgz"
    local url="${PY_SOURCE_URL_BASE}/${version}/${tarball}"
    local dest="${dest_dir}/${tarball}"

    info "Downloading Python ${version} source from ${url}..."

    if curl::is_available; then
        if curl::download "${url}" "${dest}"; then
            pass "Downloaded ${tarball}"
            printf '%s\n' "${dest}"
            return "${PASS}"
        fi
    elif cmd::exists wget; then
        if wget -q -O "${dest}" "${url}"; then
            pass "Downloaded ${tarball}"
            printf '%s\n' "${dest}"
            return "${PASS}"
        fi
    elif cmd::exists curl; then
        if curl -fsSL -o "${dest}" "${url}"; then
            pass "Downloaded ${tarball}"
            printf '%s\n' "${dest}"
            return "${PASS}"
        fi
    fi

    fail "Failed to download Python ${version} source"
    return "${FAIL}"
}

###############################################################################
# py::compile_from_source
#------------------------------------------------------------------------------
# Purpose  : Compile and install Python from source
# Usage    : py::compile_from_source "3.12.5" ["/usr/local"]
# Arguments:
#   $1 : Full version (e.g., "3.12.5")
#   $2 : Installation prefix (optional, default: /usr/local)
# Returns  : PASS if successful, FAIL otherwise
###############################################################################
function py::compile_from_source() {
    local version="${1:-}"
    local prefix="${2:-${PY_INSTALL_PREFIX}}"

    if [[ -z "${version}" ]]; then
        error "py::compile_from_source requires a version"
        return "${FAIL}"
    fi

    # If only minor version provided, get latest patch
    if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        local full_version
        if ! full_version=$(py::get_latest_patch_version "${version}"); then
            fail "Could not determine patch version for ${version}"
            return "${FAIL}"
        fi
        version="${full_version}"
    fi

    info "Compiling Python ${version} from source..."

    # Install build dependencies
    py::install_build_dependencies || warn "Dependency installation incomplete"

    # Create temp build directory
    local build_dir
    if ! build_dir=$(platform::mktemp -d "/tmp/python_build.XXXXXX"); then
        fail "Failed to create build directory"
        return "${FAIL}"
    fi

    # Download source
    local tarball
    if ! tarball=$(py::download_source "${version}" "${build_dir}"); then
        rm -rf "${build_dir}"
        return "${FAIL}"
    fi

    # Extract
    info "Extracting source..."
    if ! tar -xzf "${tarball}" -C "${build_dir}"; then
        fail "Failed to extract source tarball"
        rm -rf "${build_dir}"
        return "${FAIL}"
    fi

    local src_dir="${build_dir}/Python-${version}"
    if [[ ! -d "${src_dir}" ]]; then
        fail "Source directory not found: ${src_dir}"
        rm -rf "${build_dir}"
        return "${FAIL}"
    fi

    # Configure
    info "Configuring Python ${version}..."
    local -a configure_opts=(
        "--prefix=${prefix}"
        "--enable-optimizations"
        "--with-lto"
        "--with-system-ffi"
        "--with-ensurepip=install"
    )

    # Add SSL paths for macOS
    if os::is_macos && brew::is_available; then
        local openssl_prefix
        openssl_prefix=$(brew --prefix openssl 2> /dev/null || true)
        if [[ -n "${openssl_prefix}" ]]; then
            configure_opts+=("--with-openssl=${openssl_prefix}")
        fi
    fi

    if ! (cd "${src_dir}" && ./configure "${configure_opts[@]}"); then
        fail "Configure failed"
        rm -rf "${build_dir}"
        return "${FAIL}"
    fi

    # Build
    local nproc
    nproc=$(nproc 2> /dev/null || sysctl -n hw.ncpu 2> /dev/null || echo 2)
    info "Building Python ${version} with ${nproc} parallel jobs..."

    if ! (cd "${src_dir}" && make -j"${nproc}"); then
        fail "Build failed"
        rm -rf "${build_dir}"
        return "${FAIL}"
    fi

    # Install
    info "Installing Python ${version} to ${prefix}..."
    if ! (cd "${src_dir}" && cmd::elevate make altinstall); then
        fail "Installation failed"
        rm -rf "${build_dir}"
        return "${FAIL}"
    fi

    # Cleanup
    rm -rf "${build_dir}"

    # Verify installation
    local minor_ver="${version%.*}"
    if cmd::exists "python${minor_ver}"; then
        pass "Python ${version} compiled and installed successfully"
        info "Binary: $(command -v "python${minor_ver}")"
        return "${PASS}"
    fi

    fail "Python ${version} installation verification failed"
    return "${FAIL}"
}

#===============================================================================
# Python Installation Management
#===============================================================================

###############################################################################
# py::install_python
#------------------------------------------------------------------------------
# Purpose  : Install a specific version of Python (package manager or source).
# Usage    : py::install_python "3.12" [--compile]
# Arguments:
#   $1 : Version (e.g., "3.12" or "3.12.5")
#   $2 : --compile to force compilation from source (optional)
# Returns  : PASS if installed successfully, FAIL otherwise.
###############################################################################
function py::install_python() {
    local version="${1:-}"
    local compile_flag="${2:-}"

    if [[ -z "${version}" ]]; then
        error "Usage: py::install_python <version> [--compile]"
        return "${FAIL}"
    fi

    # Check if already installed
    if py::is_version_available "${version}"; then
        info "Python ${version} is already installed"
        return "${PASS}"
    fi

    # Force compile if requested
    if [[ "${compile_flag}" == "--compile" ]]; then
        py::compile_from_source "${version}"
        return $?
    fi

    info "Installing Python ${version}..."

    # Try package manager first
    local pkg_install_failed=0

    if os::is_macos && brew::is_available; then
        local minor_ver="${version%.*}"
        [[ "${minor_ver}" == "${version}" ]] && minor_ver="${version}"

        if cmd::run brew install "python@${minor_ver}"; then
            pass "Python ${version} installed via Homebrew"
            return "${PASS}"
        fi
        pkg_install_failed=1

    elif os::is_linux && apt::is_available; then
        local minor_ver="${version%.*}"
        [[ "${minor_ver}" == "${version}" ]] && minor_ver="${version}"

        if cmd::elevate apt-get update && cmd::elevate apt-get install -y "python${minor_ver}"; then
            pass "Python ${version} installed via apt"
            return "${PASS}"
        fi
        pkg_install_failed=1
    fi

    # Fall back to compiling from source
    if [[ ${pkg_install_failed} -eq 1 ]]; then
        warn "Package manager installation failed, attempting compilation from source..."
        py::compile_from_source "${version}"
        return $?
    fi

    fail "Unsupported platform or no package manager available"
    return "${FAIL}"
}

###############################################################################
# py::install_pip
#------------------------------------------------------------------------------
# Purpose  : Install pip if missing.
# Usage    : py::install_pip ["3.12"]
# Arguments:
#   $1 : Python version (optional)
# Returns  : PASS if pip installed, FAIL otherwise.
###############################################################################
function py::install_pip() {
    local version="${1:-}"
    local python_cmd

    python_cmd=$(py::_get_python_cmd "${version}")
    if [[ -z "${python_cmd}" ]]; then
        error "Python not found"
        return "${FAIL}"
    fi

    # Check if pip already available
    if "${python_cmd}" -m pip --version > /dev/null 2>&1; then
        debug "pip already installed for ${python_cmd}"
        return "${PASS}"
    fi

    info "Installing pip for ${python_cmd}..."
    if "${python_cmd}" -m ensurepip --upgrade 2> /dev/null; then
        pass "pip installed successfully"
        return "${PASS}"
    fi

    # Fallback: download get-pip.py
    info "Trying get-pip.py fallback..."
    local get_pip="/tmp/get-pip.py"
    if curl -fsSL -o "${get_pip}" "https://bootstrap.pypa.io/get-pip.py"; then
        if "${python_cmd}" "${get_pip}"; then
            rm -f "${get_pip}"
            pass "pip installed via get-pip.py"
            return "${PASS}"
        fi
        rm -f "${get_pip}"
    fi

    fail "pip installation failed"
    return "${FAIL}"
}

###############################################################################
# py::install_uv
#------------------------------------------------------------------------------
# Purpose  : Install uv package manager for Python.
# Usage    : py::install_uv
# Returns  : PASS if installed successfully, FAIL otherwise.
###############################################################################
function py::install_uv() {
    info "Installing uv package manager..."

    local -a pip_args
    read -ra pip_args <<< "$(py::get_pip_args "" "install")"
    pip_args+=("-U" "uv")

    if cmd::run python3 -m pip "${pip_args[@]}"; then
        pass "uv installed successfully"
        return "${PASS}"
    fi
    fail "uv installation failed"
    return "${FAIL}"
}

###############################################################################
# py::install_pipx
#------------------------------------------------------------------------------
# Purpose  : Install pipx globally for isolated package installs.
# Usage    : py::install_pipx
# Returns  : PASS if installed successfully, FAIL otherwise.
###############################################################################
function py::install_pipx() {
    if cmd::exists pipx; then
        debug "pipx already installed"
        return "${PASS}"
    fi

    info "Installing pipx..."

    local -a pip_args
    read -ra pip_args <<< "$(py::get_pip_args "" "install")"
    pip_args+=("-U" "pipx")

    if cmd::run python3 -m pip "${pip_args[@]}"; then
        # Ensure pipx is in PATH
        python3 -m pipx ensurepath 2> /dev/null || true
        pass "pipx installed successfully"
        return "${PASS}"
    fi
    fail "pipx installation failed"
    return "${FAIL}"
}

###############################################################################
# py::uv_install
#------------------------------------------------------------------------------
# Purpose  : Install packages using uv.
# Usage    : py::uv_install "requests" "flask"
# Returns  : PASS if successful, FAIL otherwise.
###############################################################################
function py::uv_install() {
    if ! cmd::exists uv; then
        error "uv not installed"
        return "${FAIL}"
    fi
    if [[ $# -eq 0 ]]; then
        error "py::uv_install requires at least one package"
        return "${FAIL}"
    fi
    info "Installing packages via uv: $*"
    if cmd::run uv pip install "$@"; then
        pass "uv package installation complete"
        return "${PASS}"
    fi
    fail "uv package installation failed"
    return "${FAIL}"
}

###############################################################################
# py::pipx_install
#------------------------------------------------------------------------------
# Purpose  : Install pipx-managed package.
# Usage    : py::pipx_install "black" ["3.12"]
# Arguments:
#   $1 : Package name (required)
#   $2 : Python version to use (optional)
# Returns  : PASS if successful, FAIL otherwise.
###############################################################################
function py::pipx_install() {
    local package="${1:-}"
    local python_version="${2:-}"

    if [[ -z "${package}" ]]; then
        error "py::pipx_install requires a package name"
        return "${FAIL}"
    fi

    if ! cmd::exists pipx; then
        py::install_pipx || return "${FAIL}"
    fi

    local -a args=(install "${package}" --force)

    if [[ -n "${python_version}" ]]; then
        local python_cmd
        python_cmd=$(py::_get_python_cmd "${python_version}")
        if [[ -n "${python_cmd}" ]]; then
            args+=(--python "${python_cmd}")
        fi
    fi

    info "Installing pipx package: ${package}"
    if cmd::run pipx "${args[@]}"; then
        pass "pipx installation successful: ${package}"
        return "${PASS}"
    fi
    fail "pipx installation failed: ${package}"
    return "${FAIL}"
}

#===============================================================================
# Virtual Environment Management
#===============================================================================

###############################################################################
# py::create_venv
#------------------------------------------------------------------------------
# Purpose  : Create a Python virtual environment.
# Usage    : py::create_venv "./venv" ["3.12"]
# Arguments:
#   $1 : Path for venv (optional, default: "venv")
#   $2 : Python version to use (optional)
# Returns  : PASS if successful, FAIL otherwise.
###############################################################################
function py::create_venv() {
    local path="${1:-venv}"
    local version="${2:-}"

    local python_cmd
    python_cmd=$(py::_get_python_cmd "${version}")

    if [[ -z "${python_cmd}" ]]; then
        error "Python not found"
        return "${FAIL}"
    fi

    info "Creating Python virtual environment: ${path} (using ${python_cmd})"
    if "${python_cmd}" -m venv "${path}"; then
        pass "Virtual environment created at ${path}"
        return "${PASS}"
    fi
    fail "Failed to create virtual environment"
    return "${FAIL}"
}

###############################################################################
# py::activate_venv
#------------------------------------------------------------------------------
# Purpose  : Activate an existing virtual environment.
# Usage    : py::activate_venv "./venv"
# Returns  : PASS if activated, FAIL otherwise.
###############################################################################
function py::activate_venv() {
    local path="${1:-venv}"
    local activate="${path}/bin/activate"

    if [[ ! -f "${activate}" ]]; then
        error "Virtual environment not found at ${path}"
        return "${FAIL}"
    fi

    # Check if we're being sourced
    if ! (return 0 2> /dev/null); then
        warn "py::activate_venv must be sourced to work: source <(py::activate_venv ${path})"
        warn "Printing activation command instead..."
        printf 'source "%s"\n' "${activate}"
        return "${FAIL}"
    fi

    # shellcheck source=/dev/null
    source "${activate}"
    pass "Activated virtual environment: ${path}"
    return "${PASS}"
}

###############################################################################
# py::freeze_requirements
#------------------------------------------------------------------------------
# Purpose  : Export current environment to requirements.txt with versions pinned
# Usage    : py::freeze_requirements "requirements.txt"
# Returns  : PASS if successful, FAIL otherwise
###############################################################################
function py::freeze_requirements() {
    local file="${1:-requirements.txt}"

    if ! py::is_available; then
        error "Python not installed"
        return "${FAIL}"
    fi

    info "Freezing requirements to ${file}..."
    if pip freeze > "${file}"; then
        pass "Requirements frozen to ${file}"
        return "${PASS}"
    fi

    fail "Failed to freeze requirements"
    return "${FAIL}"
}

#===============================================================================
# Package Management
#===============================================================================

###############################################################################
# py::pip_install
#------------------------------------------------------------------------------
# Purpose  : Install packages using pip (with auto --break-system-packages).
# Usage    : py::pip_install "requests" "flask"
# Returns  : PASS if successful, FAIL otherwise.
###############################################################################
function py::pip_install() {
    if [[ $# -eq 0 ]]; then
        error "py::pip_install requires at least one package"
        return "${FAIL}"
    fi

    local -a pip_args
    read -ra pip_args <<< "$(py::get_pip_args "" "install")"
    pip_args+=("-U" "$@")

    info "Installing packages via pip: $*"
    if PIP_ROOT_USER_ACTION=ignore cmd::run python3 -m pip "${pip_args[@]}"; then
        pass "Package installation complete"
        return "${PASS}"
    fi
    fail "Package installation failed"
    return "${FAIL}"
}

###############################################################################
# py::pip_install_for_version
#------------------------------------------------------------------------------
# Purpose  : Install packages for a specific Python version
# Usage    : py::pip_install_for_version "3.12" "requests" "flask"
# Arguments:
#   $1 : Python version (required)
#   $@ : Packages to install
# Returns  : PASS if successful, FAIL otherwise.
###############################################################################
function py::pip_install_for_version() {
    local version="${1:-}"
    shift

    if [[ -z "${version}" || $# -eq 0 ]]; then
        error "Usage: py::pip_install_for_version <version> <packages...>"
        return "${FAIL}"
    fi

    local python_cmd
    python_cmd=$(py::_get_python_cmd "${version}")

    if [[ -z "${python_cmd}" ]]; then
        error "Python ${version} not found"
        return "${FAIL}"
    fi

    local -a pip_args
    read -ra pip_args <<< "$(py::get_pip_args "${version}" "install")"
    pip_args+=("-U" "$@")

    info "Installing packages for Python ${version}: $*"
    if PIP_ROOT_USER_ACTION=ignore "${python_cmd}" -m pip "${pip_args[@]}"; then
        pass "Package installation complete for Python ${version}"
        return "${PASS}"
    fi
    fail "Package installation failed for Python ${version}"
    return "${FAIL}"
}

###############################################################################
# py::pip_upgrade
#------------------------------------------------------------------------------
# Purpose  : Upgrade pip itself.
# Usage    : py::pip_upgrade ["3.12"]
# Arguments:
#   $1 : Python version (optional)
# Returns  : PASS if upgraded, FAIL otherwise.
###############################################################################
function py::pip_upgrade() {
    local version="${1:-}"
    local python_cmd

    python_cmd=$(py::_get_python_cmd "${version}")
    if [[ -z "${python_cmd}" ]]; then
        error "Python not found"
        return "${FAIL}"
    fi

    local -a pip_args
    read -ra pip_args <<< "$(py::get_pip_args "${version}" "install")"
    pip_args+=("--upgrade" "pip")

    info "Upgrading pip for ${python_cmd}..."
    if PIP_ROOT_USER_ACTION=ignore "${python_cmd}" -m pip "${pip_args[@]}"; then
        pass "pip upgraded"
        return "${PASS}"
    fi
    fail "pip upgrade failed"
    return "${FAIL}"
}

###############################################################################
# py::requirements_install
#------------------------------------------------------------------------------
# Purpose  : Install from requirements.txt.
# Usage    : py::requirements_install "requirements.txt" ["3.12"]
# Arguments:
#   $1 : Requirements file (optional, default: requirements.txt)
#   $2 : Python version (optional)
# Returns  : PASS if successful, FAIL otherwise.
###############################################################################
function py::requirements_install() {
    local file="${1:-requirements.txt}"
    local version="${2:-}"

    if [[ ! -f "${file}" ]]; then
        error "Requirements file not found: ${file}"
        return "${FAIL}"
    fi

    local python_cmd
    python_cmd=$(py::_get_python_cmd "${version}")

    if [[ -z "${python_cmd}" ]]; then
        error "Python not found"
        return "${FAIL}"
    fi

    local -a pip_args
    read -ra pip_args <<< "$(py::get_pip_args "${version}" "install")"
    pip_args+=("-r" "${file}")

    info "Installing dependencies from ${file} using ${python_cmd}"
    if PIP_ROOT_USER_ACTION=ignore "${python_cmd}" -m pip "${pip_args[@]}"; then
        pass "Dependencies installed"
        return "${PASS}"
    fi
    fail "Failed to install dependencies"
    return "${FAIL}"
}

###############################################################################
# py::is_package_installed
#------------------------------------------------------------------------------
# Purpose  : Check if a Python package is installed.
# Usage    : py::is_package_installed "requests" ["3.12"]
# Arguments:
#   $1 : Package name (required)
#   $2 : Python version (optional)
# Returns  : PASS if installed, FAIL otherwise.
###############################################################################
function py::is_package_installed() {
    local pkg="${1:-}"
    local version="${2:-}"

    if [[ -z "${pkg}" ]]; then
        error "py::is_package_installed requires a package name"
        return "${FAIL}"
    fi

    local python_cmd
    python_cmd=$(py::_get_python_cmd "${version}")

    if [[ -z "${python_cmd}" ]]; then
        error "Python not found"
        return "${FAIL}"
    fi

    if "${python_cmd}" -m pip show "${pkg}" > /dev/null 2>&1; then
        debug "Package installed: ${pkg}"
        return "${PASS}"
    fi
    debug "Package not installed: ${pkg}"
    return "${FAIL}"
}

###############################################################################
# py::get_package_version
#------------------------------------------------------------------------------
# Purpose  : Get version of an installed Python package.
# Usage    : ver=$(py::get_package_version "requests" ["3.12"])
# Arguments:
#   $1 : Package name (required)
#   $2 : Python version (optional)
# Returns  : Prints version or FAIL if not installed.
###############################################################################
function py::get_package_version() {
    local pkg="${1:-}"
    local version="${2:-}"

    if [[ -z "${pkg}" ]]; then
        error "py::get_package_version requires a package name"
        return "${FAIL}"
    fi

    local python_cmd
    python_cmd=$(py::_get_python_cmd "${version}")

    if [[ -z "${python_cmd}" ]]; then
        error "Python not found"
        return "${FAIL}"
    fi

    local ver
    ver=$("${python_cmd}" -m pip show "${pkg}" 2> /dev/null | awk '/Version/ {print $2}')
    printf '%s\n' "${ver:-unknown}"
    [[ -n "${ver}" ]] && return "${PASS}" || return "${FAIL}"
}

###############################################################################
# py::get_site_packages
#------------------------------------------------------------------------------
# Purpose  : Get Python site-packages directory path.
# Usage    : py::get_site_packages ["3.12"]
# Arguments:
#   $1 : Python version (optional)
# Returns  : Prints site-packages path.
###############################################################################
function py::get_site_packages() {
    local version="${1:-}"
    local python_cmd

    python_cmd=$(py::_get_python_cmd "${version}")
    if [[ -z "${python_cmd}" ]]; then
        error "Python not found"
        return "${FAIL}"
    fi

    local path
    path=$("${python_cmd}" -c 'import site; print(site.getsitepackages()[0])' 2> /dev/null)
    printf '%s\n' "${path:-unknown}"
    return "${PASS}"
}

###############################################################################
# py::run_script
#------------------------------------------------------------------------------
# Purpose  : Execute a Python script.
# Usage    : py::run_script "./script.py" ["3.12"]
# Arguments:
#   $1 : Script path (required)
#   $2 : Python version (optional)
# Returns  : PASS if successful, FAIL otherwise.
###############################################################################
function py::run_script() {
    local script="${1:-}"
    local version="${2:-}"

    if [[ ! -f "${script}" ]]; then
        error "Script not found: ${script}"
        return "${FAIL}"
    fi

    local python_cmd
    python_cmd=$(py::_get_python_cmd "${version}")

    if [[ -z "${python_cmd}" ]]; then
        error "Python not found"
        return "${FAIL}"
    fi

    info "Executing Python script: ${script}"
    if "${python_cmd}" "${script}"; then
        pass "Python script executed successfully"
        return "${PASS}"
    fi
    fail "Python script execution failed"
    return "${FAIL}"
}

#===============================================================================
# Self-Test
#===============================================================================

###############################################################################
# py::self_test
#------------------------------------------------------------------------------
# Purpose  : Self-test for util_py.sh functionality
# Usage    : py::self_test
# Returns  : PASS (0) if all tests pass, FAIL (1) otherwise
###############################################################################
function py::self_test() {
    info "Running util_py.sh self-test..."

    local status="${PASS}"

    # Test 1: Check if Python detection works
    if ! declare -F py::is_available > /dev/null 2>&1; then
        fail "py::is_available function not available"
        status="${FAIL}"
    fi

    # Test 2: If Python is available, test version retrieval
    if py::is_available; then
        if ! py::get_version > /dev/null 2>&1; then
            fail "py::get_version failed"
            status="${FAIL}"
        fi

        if ! py::get_path > /dev/null 2>&1; then
            fail "py::get_path failed"
            status="${FAIL}"
        fi

        if ! py::get_major_version > /dev/null 2>&1; then
            fail "py::get_major_version failed"
            status="${FAIL}"
        fi

        # Test 3: Check --break-system-packages detection
        if py::pip_supports_break_system_packages > /dev/null 2>&1; then
            debug "pip supports --break-system-packages"
        else
            debug "pip does not support --break-system-packages"
        fi

        # Test 4: Test pip args generation
        local pip_args
        if ! pip_args=$(py::get_pip_args); then
            fail "py::get_pip_args failed"
            status="${FAIL}"
        else
            debug "Generated pip args: ${pip_args}"
        fi
    else
        warn "Python not available - skipping version tests"
        status="${FAIL}"
    fi

    if [[ "${status}" -eq "${PASS}" ]]; then
        pass "util_py.sh self-test passed"
    else
        fail "util_py.sh self-test failed"
    fi

    return "${status}"
}
