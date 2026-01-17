#!/usr/bin/env bash
###############################################################################
# NAME         : util_apt.sh
# DESCRIPTION  : APT (Debian/Ubuntu) package manager utilities.
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-10-27
###############################################################################
# EDIT HISTORY:
# DATE       | EDITED BY      | DESCRIPTION
# -----------|----------------|------------------------------------------------
# 2025-10-27 | Adam Compton   | Initial generation (style-guide compliant)
# 2025-10-29 | Adam Compton   | Added full proxy + spinner integration
# 2025-11-20 | Adam Compton   | Merged utils_apt.sh behavior, added
#            |                | self-test and compatibility wrappers
# 2025-12-27 | Adam Compton   | Refactored to use array-based tui::show_spinner
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Library Guard
#===============================================================================
if [[ -n "${UTIL_APT_SH_LOADED:-}" ]]; then
    # If we're in a sourced context, just return
    if (return 0 2> /dev/null); then
        return 0
    fi
else
    UTIL_APT_SH_LOADED=1
fi

#===============================================================================
# Module Dependencies
#===============================================================================

if [[ "${UTIL_CONFIG_SH_LOADED:-0}" -eq 0 ]]; then
    echo "ERROR: util_config.sh must be loaded before util_apt.sh" >&2
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

#===============================================================================
# Globals
#===============================================================================
# none

# NOTE: This library assumes the following helpers exist and are loaded first:
#   - Logging:  info, pass, fail, warn, error, debug
#   - OS/command: os::is_linux, cmd::exists
#   - TUI: tui::show_spinner
#   - Env: PROXY (may be empty, e.g., "")

#===============================================================================
# Internal Helpers
#===============================================================================

###############################################################################
# _apt_run
#------------------------------------------------------------------------------
# Purpose  : Execute APT commands with spinner and logging.
# Usage    : _apt_run "Updating package lists" apt-get update -y
# Arguments:
#   $1 : Description for logging (required)
#   $@ : Command and arguments to execute (required)
# Returns  : PASS (0) on success, FAIL (1) on failure
# Requires:
#   Functions: tui::show_spinner, info, debug
#   Environment: PROXY (optional prefix for commands)
###############################################################################
function _apt_run() {
    local description="${1:-APT operation}"
    shift

    if [[ $# -eq 0 ]]; then
        error "_apt_run: no command provided"
        return "${FAIL}"
    fi

    info "${description}..."

    # Build command array with optional PROXY
    local -a cmd=()
    if [[ -n "${PROXY:-}" ]]; then
        # Split PROXY into array elements
        read -ra cmd <<< "${PROXY}"
    fi
    cmd+=("$@")

    # Run with spinner, redirecting output to /dev/null
    if tui::show_spinner -- "${cmd[@]}" > /dev/null 2>&1; then
        debug "APT command succeeded: ${cmd[*]}"
        return "${PASS}"
    fi

    debug "APT command failed: ${cmd[*]}"
    return "${FAIL}"
}

###############################################################################
# _apt_package_exists
#------------------------------------------------------------------------------
# Verify a package exists in the APT cache and has an installable candidate.

# Usage:
#   _apt_package_exists "curl"
#
# Return Values:
#   PASS (0) if package exists and has an installable candidate
#   FAIL (1) otherwise

# Requirements:
#   Functions:
#     - _apt_run
#     - warn, debug, error
#
#   Environment:
#     - PROXY
###############################################################################
function _apt_package_exists() {
    local pkg="${1:-}"

    if [[ -z "${pkg}" ]]; then
        error "_apt_package_exists requires a package name"
        return "${FAIL}"
    fi

    # Try local cache lookup first
    if ! ${PROXY} apt-cache show "${pkg}" > /dev/null 2>&1; then
        warn "Package '${pkg}' not found in cache - attempting to refresh..."
        _apt_run "Refreshing package cache" apt-get update -qq -y || return "${FAIL}"

        # Retry lookup after refresh
        if ! ${PROXY} apt-cache show "${pkg}" > /dev/null 2>&1; then
            debug "Package '${pkg}' still not found after refresh."
            return "${FAIL}"
        fi
    fi

    local candidate
    candidate=$(${PROXY} apt-cache policy "${pkg}" | awk '/Candidate:/ {print $2}')
    if [[ -z "${candidate}" || "${candidate}" == "(none)" ]]; then
        debug "Package exists but has no installable candidate: ${pkg}"
        return "${FAIL}"
    fi

    debug "Valid APT candidate: ${pkg} (${candidate})"
    return "${PASS}"
}

#===============================================================================
# Core Operations (Public API)
#===============================================================================

###############################################################################
# apt::is_available
#------------------------------------------------------------------------------
# Purpose  : Check if APT is available and usable on this system
# Usage    : if apt::is_available; then ...
# Returns  : PASS if APT is available, FAIL otherwise
# Globals  : None
###############################################################################
function apt::is_available() {
    # Must be Linux
    if ! os::is_linux; then
        debug "APT not available: not Linux"
        return "${FAIL}"
    fi

    # Must have apt-get and dpkg
    if ! cmd::exists apt-get || ! cmd::exists dpkg; then
        debug "APT not available: missing apt-get or dpkg"
        return "${FAIL}"
    fi

    # Check if this is actually a Debian-based system
    if [[ ! -f /etc/debian_version ]]; then
        debug "APT available but not a Debian-based system"
    fi

    debug "APT available"
    return "${PASS}"
}

###############################################################################
# apt::_wait_for_lock
#------------------------------------------------------------------------------
# Purpose  : Wait for apt lock to be released (max 5 minutes)
# Usage    : apt::_wait_for_lock
# Returns  : PASS when lock available, FAIL on timeout
###############################################################################
function apt::_wait_for_lock() {
    local lock_file="/var/lib/dpkg/lock-frontend"
    local timeout=300 # 5 minutes
    local elapsed=0

    while fuser "${lock_file}" > /dev/null 2>&1; do
        if [[ ${elapsed} -ge ${timeout} ]]; then
            fail "Timeout waiting for apt lock to be released"
            return "${FAIL}"
        fi

        if [[ $((elapsed % 10)) -eq 0 ]]; then
            info "Waiting for apt lock to be released... (${elapsed}s)"
        fi

        sleep 2
        ((elapsed += 2))
    done

    return "${PASS}"
}

###############################################################################
# apt::add_repository
#------------------------------------------------------------------------------
# Purpose  : Add a repository to APT sources
# Usage    : apt::add_repository "ppa:user/repo" || apt::add_repository "deb ..."
# Arguments:
#   $1 : Repository specification (PPA format or raw deb line)
# Returns  : PASS (0) if repository added, FAIL (1) otherwise
# Globals  : None
###############################################################################
function apt::add_repository() {
    local repo="${1:-}"

    if [[ -z "${repo}" ]]; then
        error "apt::add_repository requires a repository specification"
        return "${FAIL}"
    fi

    # PPA format
    if [[ "${repo}" =~ ^ppa: ]]; then
        if cmd::exists add-apt-repository; then
            if cmd::elevate add-apt-repository -y "${repo}"; then
                pass "Repository added: ${repo}"
                return "${PASS}"
            fi
        else
            error "add-apt-repository not available (install software-properties-common)"
            return "${FAIL}"
        fi
    else
        # Manual repository addition (Ubuntu 22.04+ style)
        local list_file="/etc/apt/sources.list.d/custom-repo.list"

        if printf '%s\n' "${repo}" | cmd::elevate tee "${list_file}" > /dev/null; then
            pass "Repository added to ${list_file}"
            return "${PASS}"
        fi
    fi

    fail "Failed to add repository: ${repo}"
    return "${FAIL}"
}

###############################################################################
# apt::update
#------------------------------------------------------------------------------
# Purpose  : Update the APT package lists
# Usage    : apt::update
# Returns  : PASS on success, FAIL on failure
# Globals  : None
###############################################################################
function apt::update() {
    if ! apt::is_available; then
        error "APT not available"
        return "${FAIL}"
    fi

    apt::_wait_for_lock || return "${FAIL}"

    info "Updating APT package lists..."
    if _apt_run "Updating packages" apt-get update -y; then
        pass "APT package lists updated"
        return "${PASS}"
    fi

    fail "APT update failed"
    return "${FAIL}"
}

###############################################################################
# apt::upgrade
#------------------------------------------------------------------------------
# Purpose  : Upgrade all installed APT packages
# Usage    : apt::upgrade
# Returns  : PASS on success, FAIL on failure
# Globals  : None
###############################################################################
function apt::upgrade() {
    if ! apt::is_available; then
        error "APT not available"
        return "${FAIL}"
    fi

    info "Upgrading APT packages..."
    if _apt_run "Upgrading packages" apt-get upgrade -y; then
        pass "APT packages upgraded"
        return "${PASS}"
    fi

    fail "APT upgrade failed"
    return "${FAIL}"
}

###############################################################################
# apt::repair
#------------------------------------------------------------------------------
# Purpose  : Attempt to fix broken or missing APT dependencies
# Usage    : apt::repair
# Returns  : PASS if repair succeeds, FAIL otherwise
# Globals  : None
###############################################################################
function apt::repair() {
    info "Repairing broken dependencies..."
    if _apt_run "Repairing dependencies" apt-get -y -f install; then
        pass "APT repair successful"
        return "${PASS}"
    fi

    fail "APT repair failed"
    return "${FAIL}"
}

###############################################################################
# apt::is_installed
#------------------------------------------------------------------------------
# Purpose  : Check if a package is installed
# Usage    : if apt::is_installed "curl"; then ...
# Arguments:
#   $1 : Package name (required)
# Returns  : PASS if installed, FAIL otherwise
# Globals  : None
###############################################################################
function apt::is_installed() {
    local pkg="${1:-}"

    if [[ -z "${pkg}" ]]; then
        debug "apt::is_installed called without package name"
        return "${FAIL}"
    fi

    if dpkg -s "${pkg}" > /dev/null 2>&1; then
        debug "Package installed: ${pkg}"
        return "${PASS}"
    fi

    debug "Package not installed: ${pkg}"
    return "${FAIL}"
}

###############################################################################
# apt::install
#------------------------------------------------------------------------------
# Purpose  : Install one or more packages with validation, spinner, and repair
# Usage    : apt::install curl git
# Arguments:
#   $@ : Package names (required, one or more)
# Returns  : PASS if all valid packages install successfully, FAIL otherwise
# Globals  : None
###############################################################################
function apt::install() {
    if ! apt::is_available; then
        error "APT not available"
        return "${FAIL}"
    fi

    if [[ $# -eq 0 ]]; then
        error "apt::install requires at least one package name"
        return "${FAIL}"
    fi

    # Auto-update if configured
    if config::get_bool "apt.auto_update"; then
        info "Auto-update enabled, updating package lists..."
        apt::update || warn "Auto-update failed"
    fi

    local pkg
    local -a valid_pkgs=()
    local -a skipped_pkgs=()

    # Validate all requested packages first (utils_apt.sh-style behavior)
    for pkg in "$@"; do
        if _apt_package_exists "${pkg}"; then
            valid_pkgs+=("${pkg}")
        else
            skipped_pkgs+=("${pkg}")
        fi
    done

    # Summarize skipped packages (merged from old utils_apt.sh)
    if [[ "${#skipped_pkgs[@]}" -gt 0 ]]; then
        # shellcheck disable=SC2145  # We intentionally join with spaces for log.
        warn "Skipping invalid or unavailable packages: ${skipped_pkgs[*]}"
    fi

    if [[ "${#valid_pkgs[@]}" -eq 0 ]]; then
        fail "No valid packages to install"
        return "${FAIL}"
    fi

    info "Installing package(s): ${valid_pkgs[*]}"
    if _apt_run "Installing ${valid_pkgs[*]}" apt-get install -y "${valid_pkgs[@]}"; then
        pass "Installed: ${valid_pkgs[*]}"
        return "${PASS}"
    fi

    # Auto-repair if configured
    if config::get_bool "apt.auto_repair"; then
        warn "APT install failed - attempting auto-repair"
        if apt::repair && _apt_run "Reinstalling after repair" apt-get install -y "${valid_pkgs[@]}"; then
            pass "Installation succeeded after repair"
            return "${PASS}"
        fi
    fi

    warn "APT install failed - attempting repair"
    if apt::repair && _apt_run "Reinstalling after repair" apt-get install -y "${valid_pkgs[@]}"; then
        pass "Installation succeeded after repair"
        return "${PASS}"
    fi

    fail "Installation failed: ${valid_pkgs[*]}"
    return "${FAIL}"
}

###############################################################################
# apt::ensure_installed
#------------------------------------------------------------------------------
# Purpose  : Ensure packages are installed; install only if missing
# Usage    : apt::ensure_installed curl git
# Arguments:
#   $@ : Package names (required, one or more)
# Returns  : PASS if all packages installed successfully, FAIL if any fail
# Globals  : None
###############################################################################
function apt::ensure_installed() {
    local pkg
    local overall_status="${PASS}"

    for pkg in "$@"; do
        if apt::is_installed "${pkg}"; then
            debug "Already installed: ${pkg}"
            continue
        fi

        if ! apt::install "${pkg}"; then
            overall_status="${FAIL}"
        fi
    done

    return "${overall_status}"
}

###############################################################################
# apt::install_from_array
#------------------------------------------------------------------------------
# Purpose  : Install all valid packages from an array by name
# Usage    : apt::install_from_array "APT_PACKAGES"
# Arguments:
#   $1 : Array variable name (required)
# Returns  : PASS if all valid packages installed, FAIL on error
# Globals  : None
###############################################################################
#     - fail, warn, error
###############################################################################
function apt::install_from_array() {
    local array_name="${1:-}"

    if [[ -z "${array_name}" ]]; then
        error "apt::install_from_array requires an array name"
        return "${FAIL}"
    fi

    # Name reference to the array
    # shellcheck disable=SC2178  # declare -n is intentional
    declare -n pkg_array="${array_name}" || {
        fail "Array not found: ${array_name}"
        return "${FAIL}"
    }

    if [[ "${#pkg_array[@]}" -eq 0 ]]; then
        warn "Array '${array_name}' is empty - nothing to install"
        return "${PASS}"
    fi

    apt::install "${pkg_array[@]}"
}

###############################################################################
# apt::clean
#------------------------------------------------------------------------------
# Purpose  : Clean APT cache
# Usage    : apt::clean
# Returns  : PASS on success, FAIL on failure
# Globals  : None
###############################################################################
function apt::clean() {
    info "Cleaning APT cache..."
    if _apt_run "Cleaning cache" apt-get clean; then
        pass "APT cache cleaned"
        return "${PASS}"
    fi

    fail "APT clean failed"
    return "${FAIL}"
}

###############################################################################
# apt::autoremove
#------------------------------------------------------------------------------
# Purpose  : Remove unused packages and dependencies
# Usage    : apt::autoremove
# Returns  : PASS on success, FAIL on failure
# Globals  : None
###############################################################################
function apt::autoremove() {
    info "Removing unused packages..."
    if _apt_run "Removing unused packages" apt-get autoremove -y; then
        pass "Unused packages removed"
        return "${PASS}"
    fi

    fail "APT autoremove failed"
    return "${FAIL}"
}

###############################################################################
# apt::maintain
#------------------------------------------------------------------------------
# Purpose  : Perform full APT maintenance cycle (update, upgrade, autoremove, clean)
# Usage    : apt::maintain
# Returns  : PASS on success, FAIL if any step fails
# Globals  : None
###############################################################################
function apt::maintain() {
    info "Running full APT maintenance cycle..."

    apt::update || return "${FAIL}"
    apt::upgrade || return "${FAIL}"
    apt::autoremove || return "${FAIL}"
    apt::clean || return "${FAIL}"

    pass "APT maintenance completed successfully."
    return "${PASS}"
}

###############################################################################
# apt::get_version
#------------------------------------------------------------------------------
# Purpose  : Get the installed version of a package
# Usage    : ver=$(apt::get_version "curl") || echo "not installed"
# Arguments:
#   $1 : Package name (required)
# Returns  : PASS if version printed, FAIL if not installed or missing name
# Outputs  : Version string
# Globals  : None
###############################################################################
function apt::get_version() {
    local pkg="${1:-}"

    if [[ -z "${pkg}" ]]; then
        error "apt::get_version requires a package name"
        return "${FAIL}"
    fi

    if ! apt::is_installed "${pkg}"; then
        warn "Package not installed: ${pkg}"
        return "${FAIL}"
    fi

    dpkg-query -W -f='${Version}\n' "${pkg}" 2> /dev/null || echo "unknown"
    return "${PASS}"
}

###############################################################################
# apt::self_test
#------------------------------------------------------------------------------
# Lightweight self-test for util_apt.sh. Does NOT perform updates or installs.

# Usage:
#   apt::self_test
#
# Return Values:
#   PASS (0) if basic checks succeed
#   FAIL (1) if any check fails

# Requirements:
#   Functions:
#     - apt::is_available
#     - apt::is_installed
#     - apt::get_version
#     - info, pass, fail, warn
###############################################################################
function apt::self_test() {
    info "Running util_apt.sh self-test..."

    local status="${PASS}"

    if ! apt::is_available; then
        info "APT is not available on this system (non-Linux). Skipping self-test."
        return "${PASS}"
    fi

    # Check for a very common package: bash
    if ! apt::is_installed "bash"; then
        warn "Expected 'bash' to be installed, but apt::is_installed reported otherwise."
        status="${FAIL}"
    else
        # Exercise apt::get_version but ignore the actual version string
        if ! apt::get_version "bash" > /dev/null 2>&1; then
            warn "apt::get_version failed for 'bash'."
            status="${FAIL}"
        fi
    fi

    if [[ "${status}" -eq "${PASS}" ]]; then
        pass "util_apt.sh self-test passed."
    else
        fail "util_apt.sh self-test failed. See log for details."
    fi

    return "${status}"
}
