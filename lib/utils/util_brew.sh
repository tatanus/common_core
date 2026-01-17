#!/usr/bin/env bash
###############################################################################
# NAME         : util_brew.sh
# DESCRIPTION  : Homebrew package manager utilities (macOS/Linux).
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-10-27
###############################################################################
# EDIT HISTORY:
# DATE       | EDITED BY      | DESCRIPTION
# -----------|----------------|------------------------------------------------
# 2025-10-27 | Adam Compton   | Initial generation
# 2025-10-29 | Adam Compton   | Added proxy + spinner integration
# 2025-11-20 | Adam Compton   | Merged utils_brew.sh, added summaries,
#            |                | compatibility wrappers, and self-test
# 2025-12-27 | Adam Compton   | Refactored to use array-based tui::show_spinner
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Library Guard
#===============================================================================
if [[ -n "${UTIL_BREW_SH_LOADED:-}" ]]; then
    if (return 0 2> /dev/null); then return 0; fi
else
    UTIL_BREW_SH_LOADED=1
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

#===============================================================================
# Internal Helpers
#===============================================================================

###############################################################################
# _brew_run
#------------------------------------------------------------------------------
# Purpose  : Execute a Homebrew command with proxy support and spinner.
# Usage    : _brew_run "Updating Homebrew" update
# Arguments:
#   $1 : Description for logging (required)
#   $@ : Homebrew subcommand and arguments (required)
# Returns  : PASS (0) if command succeeds, FAIL (1) on failure
# Requires:
#   Functions: tui::show_spinner, info, debug
#   Environment: PROXY (optional)
###############################################################################
function _brew_run() {
    local description="${1:-Brew operation}"
    shift

    if [[ $# -eq 0 ]]; then
        error "_brew_run: no command provided"
        return "${FAIL}"
    fi

    info "${description}..."

    # Build command array with optional PROXY
    local -a cmd=()
    if [[ -n "${PROXY:-}" ]]; then
        read -ra cmd <<< "${PROXY}"
    fi
    cmd+=(brew "$@")

    # Run with spinner, redirecting output to /dev/null
    if tui::show_spinner -- "${cmd[@]}" > /dev/null 2>&1; then
        debug "brew command succeeded: ${cmd[*]}"
        return "${PASS}"
    fi

    debug "brew command failed: ${cmd[*]}"
    return "${FAIL}"
}

###############################################################################
# _brew_package_exists
#------------------------------------------------------------------------------
# Determine if a Homebrew formula or cask exists in the repositories.

# Usage:
#   _brew_package_exists "wget"
#
# Return Values:
#   PASS (0) if package exists
#   FAIL (1) if not found

# Requirements:
#   Functions:
#     - warn, debug, error
#     - _brew_run
#
#   Environment:
#     - PROXY
###############################################################################
function _brew_package_exists() {
    local pkg="${1:-}"
    [[ -z "${pkg}" ]] && {
        error "_brew_package_exists requires a package name"
        return "${FAIL}"
    }

    # Quick local search
    if ${PROXY} brew search --formula "${pkg}" | grep -qx "${pkg}"; then
        debug "Formula exists: ${pkg}"
        return "${PASS}"
    fi
    if ${PROXY} brew search --cask "${pkg}" | grep -qx "${pkg}"; then
        debug "Cask exists: ${pkg}"
        return "${PASS}"
    fi

    warn "Package '${pkg}' not found, refreshing Homebrew repository metadata..."
    _brew_run "Refreshing brew metadata" update || return "${FAIL}"

    # Re-check after update
    if ${PROXY} brew search "${pkg}" | grep -q -w "${pkg}"; then
        debug "Package '${pkg}' found after metadata refresh"
        return "${PASS}"
    fi

    debug "Package '${pkg}' not found in Homebrew repositories"
    return "${FAIL}"
}

#===============================================================================
# Availability / Bootstrap
#===============================================================================

###############################################################################
# brew::is_available
#------------------------------------------------------------------------------
# Purpose  : Check whether Homebrew is installed and usable
# Usage    : if brew::is_available; then ...
# Returns  : PASS if brew is available, FAIL otherwise
# Globals  : None
###############################################################################
function brew::is_available() {
    if cmd::exists brew; then
        debug "Homebrew available at $(command -v brew)"
        return "${PASS}"
    fi

    debug "Homebrew not installed"
    return "${FAIL}"
}

###############################################################################
# brew::install_self
#------------------------------------------------------------------------------
# Purpose  : Install Homebrew on a system where it is missing
# Usage    : brew::install_self
# Returns  : PASS if brew is installed or successfully installed, FAIL otherwise
# Globals  : None
###############################################################################
function brew::install_self() {
    if brew::is_available; then
        info "Homebrew already installed"
        return "${PASS}"
    fi

    info "Installing Homebrew..."

    # Determine architecture-specific install path
    local install_url="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"

    # On Apple Silicon, warn about path
    if os::is_macos && [[ "$(os::get_arch)" == "arm64" ]]; then
        info "Installing for Apple Silicon (ARM64)"
        info "Homebrew will be installed to /opt/homebrew"
    fi

    # Download install script first, then execute
    local install_script
    install_script=$(curl -fsSL "${install_url}") || {
        fail "Failed to download Homebrew installer"
        return "${FAIL}"
    }

    # Build command array with optional PROXY
    local -a cmd=()
    if [[ -n "${PROXY:-}" ]]; then
        read -ra cmd <<< "${PROXY}"
    fi
    cmd+=(/bin/bash -c "${install_script}")

    if ! tui::show_spinner -- "${cmd[@]}"; then
        fail "Homebrew installation failed"
        return "${FAIL}"
    fi

    # Source Homebrew on Apple Silicon
    if os::is_macos && [[ "$(os::get_arch)" == "arm64" ]] && [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    brew::is_available || {
        fail "brew missing after install"
        return "${FAIL}"
    }
    pass "Homebrew installed successfully"
    return "${PASS}"
}

#===============================================================================
# Core Package Operations
#===============================================================================

###############################################################################
# brew::tap
#------------------------------------------------------------------------------
# Purpose  : Add a Homebrew tap (third-party repository)
# Usage    : brew::tap "homebrew/cask-fonts"
# Returns  : PASS on success, FAIL otherwise
###############################################################################
function brew::tap() {
    local tap="${1:-}"

    if [[ -z "${tap}" ]]; then
        error "brew::tap requires a tap name"
        return "${FAIL}"
    fi

    brew::is_available || {
        error "Homebrew not available"
        return "${FAIL}"
    }

    # Check if already tapped
    if brew tap | grep -q "^${tap}$"; then
        debug "Tap already added: ${tap}"
        return "${PASS}"
    fi

    info "Adding Homebrew tap: ${tap}"
    if _brew_run "Adding tap" tap "${tap}"; then
        pass "Tap added: ${tap}"
        return "${PASS}"
    fi

    fail "Failed to add tap: ${tap}"
    return "${FAIL}"
}

###############################################################################
# brew::install_cask
#------------------------------------------------------------------------------
# Purpose  : Install a Homebrew cask (macOS app)
# Usage    : brew::install_cask "firefox"
# Returns  : PASS on success, FAIL otherwise
###############################################################################
function brew::install_cask() {
    brew::is_available || {
        error "Homebrew not available"
        return "${FAIL}"
    }
    [[ $# -eq 0 ]] && {
        error "brew::install_cask requires cask names"
        return "${FAIL}"
    }

    local cask
    local -a valid_casks=()
    local -a skipped_casks=()

    # Validate casks
    for cask in "$@"; do
        if ${PROXY} brew search --cask "${cask}" | grep -qx "${cask}"; then
            valid_casks+=("${cask}")
        else
            skipped_casks+=("${cask}")
        fi
    done

    if [[ ${#skipped_casks[@]} -gt 0 ]]; then
        warn "Skipping unavailable casks: ${skipped_casks[*]}"
    fi

    if [[ ${#valid_casks[@]} -eq 0 ]]; then
        fail "No valid casks to install"
        return "${FAIL}"
    fi

    info "Installing casks: ${valid_casks[*]}"
    if _brew_run "Installing casks" install --cask "${valid_casks[@]}"; then
        pass "Installed casks: ${valid_casks[*]}"
        return "${PASS}"
    fi

    fail "Failed to install casks: ${valid_casks[*]}"
    return "${FAIL}"
}

###############################################################################
# brew::rosetta_available
#------------------------------------------------------------------------------
# Purpose  : Check if Rosetta 2 is installed (ARM Macs only)
# Usage    : brew::rosetta_available || install_rosetta
# Returns  : PASS if Rosetta installed or not needed, FAIL if needed but missing
###############################################################################
function brew::rosetta_available() {
    # Only relevant on ARM Macs
    if ! os::is_macos || [[ "$(os::get_arch)" != "arm64" ]]; then
        return "${PASS}"
    fi

    if /usr/bin/pgrep -q oahd; then
        debug "Rosetta 2 is installed and running"
        return "${PASS}"
    fi

    # Check if installed but not running
    if [[ -f /Library/Apple/usr/share/rosetta/rosetta ]]; then
        debug "Rosetta 2 is installed"
        return "${PASS}"
    fi

    debug "Rosetta 2 not installed"
    return "${FAIL}"
}

###############################################################################
# brew::update
#------------------------------------------------------------------------------
# Purpose  : Update Homebrew metadata (brew update)
# Usage    : brew::update
# Returns  : PASS on success, FAIL on failure
# Globals  : None
###############################################################################
function brew::update() {
    brew::is_available || {
        error "Homebrew not available"
        return "${FAIL}"
    }

    if _brew_run "Updating Homebrew repositories" update; then
        pass "Homebrew updated successfully"
        return "${PASS}"
    fi

    fail "Homebrew update failed"
    return "${FAIL}"
}

###############################################################################
# brew::upgrade
#------------------------------------------------------------------------------
# Purpose  : Upgrade all installed Homebrew formulae
# Usage    : brew::upgrade
# Returns  : PASS on success, FAIL on failure
# Globals  : None
###############################################################################
function brew::upgrade() {
    brew::is_available || {
        error "Homebrew not available"
        return "${FAIL}"
    }

    if _brew_run "Upgrading installed packages" upgrade; then
        pass "Homebrew packages upgraded"
        return "${PASS}"
    fi

    fail "Homebrew upgrade failed"
    return "${FAIL}"
}

###############################################################################
# brew::is_installed
#------------------------------------------------------------------------------
# Purpose  : Determine if a formula or cask is currently installed
# Usage    : if brew::is_installed "git"; then ...
# Arguments:
#   $1 : Package name (required)
# Returns  : PASS if installed, FAIL otherwise
# Globals  : None
###############################################################################
function brew::is_installed() {
    local pkg="${1:-}"
    [[ -z "${pkg}" ]] && {
        error "brew::is_installed requires a package name"
        return "${FAIL}"
    }

    if brew list --formula | grep -qx "${pkg}"; then
        debug "Formula installed: ${pkg}"
        return "${PASS}"
    fi
    if brew list --cask | grep -qx "${pkg}"; then
        debug "Cask installed: ${pkg}"
        return "${PASS}"
    fi

    debug "Package not installed: ${pkg}"
    return "${FAIL}"
}

###############################################################################
# brew::install
#------------------------------------------------------------------------------
# Purpose  : Install one or more Homebrew packages with validation and retry
# Usage    : brew::install git wget
# Arguments:
#   $@ : Package names (required, one or more)
# Returns  : PASS if all valid packages install successfully, FAIL otherwise
# Globals  : None
###############################################################################
function brew::install() {
    brew::is_available || {
        error "Homebrew not available"
        return "${FAIL}"
    }
    [[ $# -eq 0 ]] && {
        error "brew::install requires packages"
        return "${FAIL}"
    }

    local pkg
    local -a valid_pkgs=()
    local -a skipped_pkgs=()

    # Validate packages
    for pkg in "$@"; do
        if _brew_package_exists "${pkg}"; then
            valid_pkgs+=("${pkg}")
        else
            skipped_pkgs+=("${pkg}")
        fi
    done

    if [[ ${#skipped_pkgs[@]} -gt 0 ]]; then
        warn "Skipping unavailable packages: ${skipped_pkgs[*]}"
    fi

    if [[ ${#valid_pkgs[@]} -eq 0 ]]; then
        fail "No valid packages to install"
        return "${FAIL}"
    fi

    info "Installing: ${valid_pkgs[*]}"
    if _brew_run "Installing packages" install "${valid_pkgs[@]}"; then
        pass "Installed: ${valid_pkgs[*]}"
        return "${PASS}"
    fi

    warn "Install failed - retrying after brew update..."
    brew::update

    if _brew_run "Retrying installation" install "${valid_pkgs[@]}"; then
        pass "Installed successfully after retry"
        return "${PASS}"
    fi

    fail "Failed to install: ${valid_pkgs[*]}"
    return "${FAIL}"
}

###############################################################################
# brew::ensure_installed
#------------------------------------------------------------------------------
# Purpose  : Install packages only if missing
# Usage    : brew::ensure_installed git htop
# Arguments:
#   $@ : Package names (required, one or more)
# Returns  : PASS if all installed, FAIL if any installation fails
# Globals  : None
###############################################################################
function brew::ensure_installed() {
    local pkg overall="${PASS}"

    for pkg in "$@"; do
        if brew::is_installed "${pkg}"; then
            debug "Already installed: ${pkg}"
            continue
        fi

        brew::install "${pkg}" || overall="${FAIL}"
    done

    return "${overall}"
}

###############################################################################
# brew::install_from_array
#------------------------------------------------------------------------------
# Purpose  : Install all packages defined in a named array
# Usage    : brew::install_from_array "BREW_PACKAGES"
# Arguments:
#   $1 : Array variable name (required)
# Returns  : PASS if installation succeeds, FAIL on error
# Globals  : None
###############################################################################
function brew::install_from_array() {
    local array_name="${1:-}"
    [[ -z "${array_name}" ]] && {
        error "Array name required"
        return "${FAIL}"
    }

    # shellcheck disable=SC2178
    declare -n PKG_ARR="${array_name}" || {
        fail "Array not found: ${array_name}"
        return "${FAIL}"
    }

    brew::install "${PKG_ARR[@]}"
}

###############################################################################
# brew::uninstall
#------------------------------------------------------------------------------
# Purpose  : Uninstall one or more Homebrew packages
# Usage    : brew::uninstall pkg1 pkg2
# Arguments:
#   $@ : Package names (required, one or more)
# Returns  : PASS if uninstall succeeds, FAIL otherwise
# Globals  : None
###############################################################################
function brew::uninstall() {
    brew::is_available || return "${FAIL}"
    [[ $# -eq 0 ]] && {
        error "brew::uninstall requires packages"
        return "${FAIL}"
    }

    if _brew_run "Uninstalling packages" uninstall "$@"; then
        pass "Uninstalled: $*"
        return "${PASS}"
    fi

    fail "Failed to uninstall: $*"
    return "${FAIL}"
}

###############################################################################
# brew::cleanup
#------------------------------------------------------------------------------
# Purpose  : Remove old versions of installed Homebrew packages
# Usage    : brew::cleanup
# Returns  : PASS if cleanup successful, FAIL on failure
# Globals  : None
###############################################################################
function brew::cleanup() {
    brew::is_available || return "${FAIL}"

    if _brew_run "Cleaning old brew packages" cleanup -s; then
        pass "Homebrew cleanup completed"
        return "${PASS}"
    fi

    fail "Cleanup failed"
    return "${FAIL}"
}

###############################################################################
# brew::get_version
#------------------------------------------------------------------------------
# Purpose  : Get the installed version of a Homebrew package
# Usage    : ver=$(brew::get_version git)
# Arguments:
#   $1 : Package name (required)
# Returns  : PASS if successful, FAIL otherwise
# Outputs  : Version string
# Globals  : None
###############################################################################
function brew::get_version() {
    local pkg="${1:-}"
    [[ -z "${pkg}" ]] && {
        error "brew::get_version requires a package name"
        return "${FAIL}"
    }

    brew::is_installed "${pkg}" || {
        warn "${pkg} not installed"
        return "${FAIL}"
    }

    local version
    version=$(brew info --json=v1 "${pkg}" 2> /dev/null | grep -Eo '"version":"[^"]+' | cut -d'"' -f4)

    printf '%s\n' "${version:-unknown}"
    return "${PASS}"
}

###############################################################################
# brew::list
#------------------------------------------------------------------------------
# Purpose  : List all installed Homebrew formulae
# Usage    : brew::list
# Returns  : PASS always
# Outputs  : List of installed formulae
# Globals  : None
###############################################################################
function brew::list() {
    brew::is_available || return "${FAIL}"
    brew list --formula
    return "${PASS}"
}

#===============================================================================
# Self-Test
#===============================================================================

###############################################################################
# brew::self_test
#------------------------------------------------------------------------------
# Run basic self-tests for util_brew.sh.

# Usage:
#   brew::self_test
#
# Return Values:
#   PASS (0) if all basic tests pass
#   FAIL (1) otherwise

# Requirements:
#   Functions:
#     - brew::is_available
#     - brew::is_installed
#     - brew::get_version
#     - info, warn, pass, fail
###############################################################################
function brew::self_test() {
    info "Running util_brew.sh self-test..."

    brew::is_available || {
        fail "Homebrew not available"
        return "${FAIL}"
    }

    # Check a package that should exist
    brew::is_installed "bash" || warn "bash not installed, but expected on macOS/Linux"

    brew::get_version "bash" > /dev/null 2>&1 || warn "Version lookup failed"

    pass "util_brew.sh self-test passed."
    return "${PASS}"
}
