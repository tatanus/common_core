#!/usr/bin/env bash
###############################################################################
# NAME         : util_py_multi.sh
# DESCRIPTION  : Multi-version Python management utilities. Extends util_py.sh
#                to handle installation and package management across multiple
#                Python versions simultaneously.
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-12-26
###############################################################################
# EDIT HISTORY:
# DATE        | EDITED BY      | DESCRIPTION
# ------------|----------------|-----------------------------------------------
# 2025-12-26  | Adam Compton   | Initial creation - multi-version support
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Library Guard
#===============================================================================
if [[ -n "${UTIL_PY_MULTI_SH_LOADED:-}" ]]; then
    if (return 0 2> /dev/null); then
        return 0
    fi
else
    UTIL_PY_MULTI_SH_LOADED=1
fi

#===============================================================================
# Module Dependencies
#===============================================================================
if [[ "${UTIL_PY_SH_LOADED:-0}" -eq 0 ]]; then
    echo "ERROR: util_py.sh must be loaded before util_py_multi.sh" >&2
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

# Array to hold configured Python versions for multi-version operations
declare -ga PY_MULTI_VERSIONS=()

# Default Python version (set after installation)
declare -g PY_MULTI_DEFAULT=""

# Installation results tracking
declare -gA PY_MULTI_INSTALL_STATUS=()

#===============================================================================
# Version Management
#===============================================================================

###############################################################################
# py_multi::set_versions
#------------------------------------------------------------------------------
# Purpose  : Set the list of Python versions to manage
# Usage    : py_multi::set_versions "3.10" "3.11" "3.12"
# Arguments:
#   $@ : Version strings
# Returns  : PASS always
###############################################################################
function py_multi::set_versions() {
    PY_MULTI_VERSIONS=("$@")
    debug "Configured Python versions: ${PY_MULTI_VERSIONS[*]}"
    return "${PASS}"
}

###############################################################################
# py_multi::get_versions
#------------------------------------------------------------------------------
# Purpose  : Get the list of configured Python versions
# Usage    : versions=($(py_multi::get_versions))
# Returns  : Prints versions, one per line
###############################################################################
function py_multi::get_versions() {
    printf '%s\n' "${PY_MULTI_VERSIONS[@]}"
    return "${PASS}"
}

###############################################################################
# py_multi::add_version
#------------------------------------------------------------------------------
# Purpose  : Add a version to the managed list
# Usage    : py_multi::add_version "3.13"
# Arguments:
#   $1 : Version to add
# Returns  : PASS if added, FAIL if already present
###############################################################################
function py_multi::add_version() {
    local version="${1:-}"

    if [[ -z "${version}" ]]; then
        error "py_multi::add_version requires a version"
        return "${FAIL}"
    fi

    # Check if already in list
    local v
    for v in "${PY_MULTI_VERSIONS[@]}"; do
        if [[ "${v}" == "${version}" ]]; then
            debug "Version ${version} already in list"
            return "${PASS}"
        fi
    done

    PY_MULTI_VERSIONS+=("${version}")
    debug "Added Python ${version} to managed versions"
    return "${PASS}"
}

###############################################################################
# py_multi::remove_version
#------------------------------------------------------------------------------
# Purpose  : Remove a version from the managed list
# Usage    : py_multi::remove_version "3.10"
# Arguments:
#   $1 : Version to remove
# Returns  : PASS if removed, FAIL if not found
###############################################################################
function py_multi::remove_version() {
    local version="${1:-}"

    if [[ -z "${version}" ]]; then
        error "py_multi::remove_version requires a version"
        return "${FAIL}"
    fi

    local -a new_versions=()
    local found=0

    local v
    for v in "${PY_MULTI_VERSIONS[@]}"; do
        if [[ "${v}" == "${version}" ]]; then
            found=1
        else
            new_versions+=("${v}")
        fi
    done

    if [[ ${found} -eq 0 ]]; then
        warn "Version ${version} not found in managed list"
        return "${FAIL}"
    fi

    PY_MULTI_VERSIONS=("${new_versions[@]}")
    debug "Removed Python ${version} from managed versions"
    return "${PASS}"
}

###############################################################################
# py_multi::find_latest
#------------------------------------------------------------------------------
# Purpose  : Find the highest version in the managed list
# Usage    : latest=$(py_multi::find_latest)
# Returns  : Prints the highest version string
###############################################################################
function py_multi::find_latest() {
    if [[ ${#PY_MULTI_VERSIONS[@]} -eq 0 ]]; then
        error "No Python versions configured"
        return "${FAIL}"
    fi

    local latest
    latest=$(printf '%s\n' "${PY_MULTI_VERSIONS[@]}" | sort -V | tail -n 1)

    printf '%s\n' "${latest}"
    return "${PASS}"
}

###############################################################################
# py_multi::set_default
#------------------------------------------------------------------------------
# Purpose  : Set the default Python version
# Usage    : py_multi::set_default "3.12"
# Arguments:
#   $1 : Version to set as default (optional, uses latest if omitted)
# Returns  : PASS if set, FAIL otherwise
###############################################################################
function py_multi::set_default() {
    local version="${1:-}"

    if [[ -z "${version}" ]]; then
        version=$(py_multi::find_latest) || return "${FAIL}"
    fi

    PY_MULTI_DEFAULT="${version}"
    export PYTHON_VERSION="${version}"
    export PYTHON="python${version}"

    pass "Default Python set to ${version}"
    return "${PASS}"
}

###############################################################################
# py_multi::get_default
#------------------------------------------------------------------------------
# Purpose  : Get the default Python version
# Usage    : default=$(py_multi::get_default)
# Returns  : Prints the default version
###############################################################################
function py_multi::get_default() {
    if [[ -z "${PY_MULTI_DEFAULT}" ]]; then
        # Try to determine from environment
        if [[ -n "${PYTHON_VERSION:-}" ]]; then
            PY_MULTI_DEFAULT="${PYTHON_VERSION}"
        else
            PY_MULTI_DEFAULT=$(py_multi::find_latest 2> /dev/null || echo "3")
        fi
    fi

    printf '%s\n' "${PY_MULTI_DEFAULT}"
    return "${PASS}"
}

#===============================================================================
# Multi-Version Installation
#===============================================================================

###############################################################################
# py_multi::install_all
#------------------------------------------------------------------------------
# Purpose  : Install all configured Python versions
# Usage    : py_multi::install_all [--compile]
# Arguments:
#   $1 : --compile to force compilation from source (optional)
# Returns  : PASS if all installed, FAIL if any failed
###############################################################################
function py_multi::install_all() {
    local compile_flag="${1:-}"

    if [[ ${#PY_MULTI_VERSIONS[@]} -eq 0 ]]; then
        error "No Python versions configured. Use py_multi::set_versions first."
        return "${FAIL}"
    fi

    info "Installing ${#PY_MULTI_VERSIONS[@]} Python version(s)..."

    local version
    local overall_status="${PASS}"

    # Clear previous status
    PY_MULTI_INSTALL_STATUS=()

    for version in "${PY_MULTI_VERSIONS[@]}"; do
        info "Installing Python ${version}..."

        if py::install_python "${version}" "${compile_flag}"; then
            PY_MULTI_INSTALL_STATUS[${version}]="success"
            pass "Python ${version} installed successfully"
        else
            PY_MULTI_INSTALL_STATUS[${version}]="failed"
            fail "Python ${version} installation failed"
            overall_status="${FAIL}"
        fi
    done

    # Set default to latest installed version
    local latest
    latest=$(py_multi::find_latest)
    if py::is_version_available "${latest}"; then
        py_multi::set_default "${latest}"
    fi

    # Summary
    info "Installation Summary:"
    for version in "${PY_MULTI_VERSIONS[@]}"; do
        local status="${PY_MULTI_INSTALL_STATUS[${version}]:-unknown}"
        if [[ "${status}" == "success" ]]; then
            pass "  Python ${version}: ${status}"
        else
            fail "  Python ${version}: ${status}"
        fi
    done

    return "${overall_status}"
}

###############################################################################
# py_multi::install_pip_all
#------------------------------------------------------------------------------
# Purpose  : Install pip for all configured Python versions
# Usage    : py_multi::install_pip_all
# Returns  : PASS if all successful, FAIL if any failed
###############################################################################
function py_multi::install_pip_all() {
    if [[ ${#PY_MULTI_VERSIONS[@]} -eq 0 ]]; then
        error "No Python versions configured"
        return "${FAIL}"
    fi

    info "Installing pip for all Python versions..."

    local version
    local overall_status="${PASS}"

    for version in "${PY_MULTI_VERSIONS[@]}"; do
        if ! py::is_version_available "${version}"; then
            warn "Python ${version} not installed, skipping pip"
            continue
        fi

        if py::install_pip "${version}"; then
            pass "pip installed for Python ${version}"
        else
            fail "pip installation failed for Python ${version}"
            overall_status="${FAIL}"
        fi
    done

    return "${overall_status}"
}

###############################################################################
# py_multi::upgrade_pip_all
#------------------------------------------------------------------------------
# Purpose  : Upgrade pip for all configured Python versions
# Usage    : py_multi::upgrade_pip_all
# Returns  : PASS if all successful, FAIL if any failed
###############################################################################
function py_multi::upgrade_pip_all() {
    if [[ ${#PY_MULTI_VERSIONS[@]} -eq 0 ]]; then
        error "No Python versions configured"
        return "${FAIL}"
    fi

    info "Upgrading pip for all Python versions..."

    local version
    local overall_status="${PASS}"

    for version in "${PY_MULTI_VERSIONS[@]}"; do
        if ! py::is_version_available "${version}"; then
            warn "Python ${version} not installed, skipping"
            continue
        fi

        if py::pip_upgrade "${version}"; then
            pass "pip upgraded for Python ${version}"
        else
            fail "pip upgrade failed for Python ${version}"
            overall_status="${FAIL}"
        fi
    done

    return "${overall_status}"
}

#===============================================================================
# Multi-Version Package Management
#===============================================================================

###############################################################################
# py_multi::pip_install_all
#------------------------------------------------------------------------------
# Purpose  : Install packages for all configured Python versions
# Usage    : py_multi::pip_install_all "requests" "flask"
# Arguments:
#   $@ : Packages to install
# Returns  : PASS if all successful, FAIL if any failed
###############################################################################
function py_multi::pip_install_all() {
    if [[ $# -eq 0 ]]; then
        error "py_multi::pip_install_all requires at least one package"
        return "${FAIL}"
    fi

    if [[ ${#PY_MULTI_VERSIONS[@]} -eq 0 ]]; then
        error "No Python versions configured"
        return "${FAIL}"
    fi

    local -a packages=("$@")
    info "Installing packages for all Python versions: ${packages[*]}"

    local version
    local overall_status="${PASS}"

    for version in "${PY_MULTI_VERSIONS[@]}"; do
        if ! py::is_version_available "${version}"; then
            warn "Python ${version} not installed, skipping"
            continue
        fi

        info "Installing packages for Python ${version}..."
        if py::pip_install_for_version "${version}" "${packages[@]}"; then
            pass "Packages installed for Python ${version}"
        else
            fail "Package installation failed for Python ${version}"
            overall_status="${FAIL}"
        fi
    done

    return "${overall_status}"
}

###############################################################################
# py_multi::requirements_install_all
#------------------------------------------------------------------------------
# Purpose  : Install from requirements.txt for all Python versions
# Usage    : py_multi::requirements_install_all "requirements.txt"
# Arguments:
#   $1 : Requirements file (optional, default: requirements.txt)
# Returns  : PASS if all successful, FAIL if any failed
###############################################################################
function py_multi::requirements_install_all() {
    local file="${1:-requirements.txt}"

    if [[ ! -f "${file}" ]]; then
        error "Requirements file not found: ${file}"
        return "${FAIL}"
    fi

    if [[ ${#PY_MULTI_VERSIONS[@]} -eq 0 ]]; then
        error "No Python versions configured"
        return "${FAIL}"
    fi

    info "Installing requirements for all Python versions from ${file}..."

    local version
    local overall_status="${PASS}"

    for version in "${PY_MULTI_VERSIONS[@]}"; do
        if ! py::is_version_available "${version}"; then
            warn "Python ${version} not installed, skipping"
            continue
        fi

        info "Installing requirements for Python ${version}..."
        if py::requirements_install "${file}" "${version}"; then
            pass "Requirements installed for Python ${version}"
        else
            fail "Requirements installation failed for Python ${version}"
            overall_status="${FAIL}"
        fi
    done

    return "${overall_status}"
}

###############################################################################
# py_multi::verify_package_all
#------------------------------------------------------------------------------
# Purpose  : Verify a package is installed for all Python versions
# Usage    : py_multi::verify_package_all "requests"
# Arguments:
#   $1 : Package name
# Returns  : PASS if installed for all, FAIL if missing for any
###############################################################################
function py_multi::verify_package_all() {
    local package="${1:-}"

    if [[ -z "${package}" ]]; then
        error "py_multi::verify_package_all requires a package name"
        return "${FAIL}"
    fi

    if [[ ${#PY_MULTI_VERSIONS[@]} -eq 0 ]]; then
        error "No Python versions configured"
        return "${FAIL}"
    fi

    info "Verifying package '${package}' across all Python versions..."

    local version
    local overall_status="${PASS}"

    for version in "${PY_MULTI_VERSIONS[@]}"; do
        if ! py::is_version_available "${version}"; then
            warn "Python ${version} not installed, skipping"
            continue
        fi

        if py::is_package_installed "${package}" "${version}"; then
            local pkg_ver
            pkg_ver=$(py::get_package_version "${package}" "${version}")
            pass "Python ${version}: ${package} v${pkg_ver}"
        else
            fail "Python ${version}: ${package} NOT INSTALLED"
            overall_status="${FAIL}"
        fi
    done

    return "${overall_status}"
}

#===============================================================================
# Pipx Multi-Version Support
#===============================================================================

###############################################################################
# py_multi::pipx_install_batch
#------------------------------------------------------------------------------
# Purpose  : Install multiple pipx packages with optional version overrides
# Usage    : py_multi::pipx_install_batch "PACKAGES_ARRAY_NAME"
#            Array format: "package_name|python_version" or just "package_name"
# Arguments:
#   $1 : Name of array containing package specs
# Returns  : PASS if all successful, FAIL if any failed
###############################################################################
function py_multi::pipx_install_batch() {
    local array_name="${1:-}"

    if [[ -z "${array_name}" ]]; then
        error "py_multi::pipx_install_batch requires an array name"
        return "${FAIL}"
    fi

    # Use nameref for array access
    declare -n packages_ref="${array_name}" || {
        error "Array not defined: ${array_name}"
        return "${FAIL}"
    }

    if [[ ${#packages_ref[@]} -eq 0 ]]; then
        warn "No packages in ${array_name}"
        return "${PASS}"
    fi

    info "Installing ${#packages_ref[@]} pipx package(s)..."

    local overall_status="${PASS}"
    local item package_spec python_version

    for item in "${packages_ref[@]}"; do
        # Parse "package|version" format
        package_spec="${item%%|*}"
        python_version="${item#*|}"

        # If no |, python_version equals the whole string
        if [[ "${package_spec}" == "${python_version}" ]]; then
            python_version=""
        fi

        if py::pipx_install "${package_spec}" "${python_version}"; then
            pass "Installed: ${package_spec}"
        else
            fail "Failed: ${package_spec}"
            overall_status="${FAIL}"
        fi
    done

    return "${overall_status}"
}

#===============================================================================
# Status and Reporting
#===============================================================================

###############################################################################
# py_multi::status
#------------------------------------------------------------------------------
# Purpose  : Display status of all configured Python versions
# Usage    : py_multi::status
# Returns  : PASS always
###############################################################################
function py_multi::status() {
    info "Python Multi-Version Status:"
    printf "\n"

    if [[ ${#PY_MULTI_VERSIONS[@]} -eq 0 ]]; then
        warn "No Python versions configured"
        return "${PASS}"
    fi

    local default
    default=$(py_multi::get_default)

    printf "%-12s %-12s %-10s %s\n" "VERSION" "STATUS" "PIP" "PATH"
    printf "%s\n" "------------------------------------------------------------"

    local version
    for version in "${PY_MULTI_VERSIONS[@]}"; do
        local status="NOT FOUND"
        local pip_status="N/A"
        local path="-"
        local marker=""

        if py::is_version_available "${version}"; then
            status="INSTALLED"
            local python_cmd
            python_cmd=$(py::_get_python_cmd "${version}")
            path="${python_cmd}"

            if "${python_cmd}" -m pip --version > /dev/null 2>&1; then
                pip_status="OK"
            else
                pip_status="MISSING"
            fi
        fi

        if [[ "${version}" == "${default}" ]]; then
            marker=" [DEFAULT]"
        fi

        printf "%-12s %-12s %-10s %s%s\n" "${version}" "${status}" "${pip_status}" "${path}" "${marker}"
    done

    printf "\n"
    return "${PASS}"
}

###############################################################################
# py_multi::list_installed
#------------------------------------------------------------------------------
# Purpose  : List all Python versions currently installed on the system
# Usage    : py_multi::list_installed
# Returns  : Prints installed versions
###############################################################################
function py_multi::list_installed() {
    info "Scanning for installed Python versions..."

    local -a found_versions=()

    # Check common version patterns
    local minor
    for minor in 3.8 3.9 3.10 3.11 3.12 3.13 3.14; do
        if cmd::exists "python${minor}"; then
            local full_ver
            full_ver=$("python${minor}" --version 2>&1 | awk '{print $2}')
            found_versions+=("${minor} (${full_ver})")
        fi
    done

    # Check for generic python3
    if cmd::exists python3; then
        local py3_ver
        py3_ver=$(python3 --version 2>&1 | awk '{print $2}')
        info "System python3: ${py3_ver}"
    fi

    if [[ ${#found_versions[@]} -eq 0 ]]; then
        warn "No specific Python versions found"
        return "${PASS}"
    fi

    printf "Installed Python versions:\n"
    local v
    for v in "${found_versions[@]}"; do
        printf "  - %s\n" "${v}"
    done

    return "${PASS}"
}

#===============================================================================
# Cleanup and Maintenance
#===============================================================================

###############################################################################
# py_multi::cleanup_cache
#------------------------------------------------------------------------------
# Purpose  : Clear pip caches for all Python versions
# Usage    : py_multi::cleanup_cache
# Returns  : PASS if successful, FAIL otherwise
###############################################################################
function py_multi::cleanup_cache() {
    info "Cleaning pip cache for all Python versions..."

    local version
    local overall_status="${PASS}"

    for version in "${PY_MULTI_VERSIONS[@]}"; do
        if ! py::is_version_available "${version}"; then
            continue
        fi

        local python_cmd
        python_cmd=$(py::_get_python_cmd "${version}")

        if "${python_cmd}" -m pip cache purge > /dev/null 2>&1; then
            debug "Cache cleared for Python ${version}"
        else
            debug "Could not clear cache for Python ${version}"
        fi
    done

    pass "Cache cleanup complete"
    return "${overall_status}"
}

#===============================================================================
# Self-Test
#===============================================================================

###############################################################################
# py_multi::self_test
#------------------------------------------------------------------------------
# Purpose  : Self-test for util_py_multi.sh functionality
# Usage    : py_multi::self_test
# Returns  : PASS (0) if all tests pass, FAIL (1) otherwise
###############################################################################
function py_multi::self_test() {
    info "Running util_py_multi.sh self-test..."

    local status="${PASS}"

    # Test 1: Version management
    py_multi::set_versions "3.10" "3.11" "3.12"

    local versions
    versions=$(py_multi::get_versions | wc -l)
    if [[ "${versions}" -ne 3 ]]; then
        fail "py_multi::set_versions failed"
        status="${FAIL}"
    fi

    # Test 2: Add/remove version
    py_multi::add_version "3.13"
    versions=$(py_multi::get_versions | wc -l)
    if [[ "${versions}" -ne 4 ]]; then
        fail "py_multi::add_version failed"
        status="${FAIL}"
    fi

    py_multi::remove_version "3.13"
    versions=$(py_multi::get_versions | wc -l)
    if [[ "${versions}" -ne 3 ]]; then
        fail "py_multi::remove_version failed"
        status="${FAIL}"
    fi

    # Test 3: Find latest
    local latest
    latest=$(py_multi::find_latest)
    if [[ "${latest}" != "3.12" ]]; then
        fail "py_multi::find_latest failed: expected 3.12, got ${latest}"
        status="${FAIL}"
    fi

    # Test 4: Status display (should not error)
    if ! py_multi::status > /dev/null 2>&1; then
        fail "py_multi::status failed"
        status="${FAIL}"
    fi

    # Cleanup test state
    PY_MULTI_VERSIONS=()

    if [[ "${status}" -eq "${PASS}" ]]; then
        pass "util_py_multi.sh self-test passed"
    else
        fail "util_py_multi.sh self-test failed"
    fi

    return "${status}"
}
