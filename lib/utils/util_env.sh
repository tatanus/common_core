#!/usr/bin/env bash
###############################################################################
# NAME         : util_env.sh
# DESCRIPTION  : Environment variable management, PATH manipulation, detection,
#                and environment file helpers.
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-10-27
###############################################################################
# EDIT HISTORY:
# DATE        | EDITED BY      | DESCRIPTION
# ------------|----------------|-----------------------------------------------
# 2025-10-27  | Adam Compton   | Initial generation (style-guide compliant)
# 2025-11-20  | Adam Compton   | Full audit & rewriting
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Library Guard
#===============================================================================
if [[ -n "${UTIL_ENV_SH_LOADED:-}" ]]; then
    if (return 0 2> /dev/null); then return 0; fi
else
    UTIL_ENV_SH_LOADED=1
fi

#===============================================================================
# Module Dependencies
#===============================================================================
if [[ "${UTIL_PLATFORM_SH_LOADED:-0}" -eq 0 ]]; then
    echo "ERROR: util_platform.sh must be loaded before util_env.sh" >&2
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
# none

#===============================================================================
# Environment Variable Access Functions
#===============================================================================

###############################################################################
# env::get_xdg_config_home
#------------------------------------------------------------------------------
# Purpose  : Get XDG config directory (with fallback)
# Usage    : config_dir=$(env::get_xdg_config_home)
# Returns  : Prints config directory path
###############################################################################
function env::get_xdg_config_home() {
    printf '%s\n' "${XDG_CONFIG_HOME:-${HOME}/.config}"
    return "${PASS}"
}

###############################################################################
# env::get_xdg_data_home
#------------------------------------------------------------------------------
# Purpose  : Get XDG data directory (with fallback)
# Usage    : data_dir=$(env::get_xdg_data_home)
# Returns  : Prints data directory path
###############################################################################
function env::get_xdg_data_home() {
    printf '%s\n' "${XDG_DATA_HOME:-${HOME}/.local/share}"
    return "${PASS}"
}

###############################################################################
# env::get_xdg_cache_home
#------------------------------------------------------------------------------
# Purpose  : Get XDG cache directory (with fallback)
# Usage    : cache_dir=$(env::get_xdg_cache_home)
# Returns  : Prints cache directory path
###############################################################################
function env::get_xdg_cache_home() {
    printf '%s\n' "${XDG_CACHE_HOME:-${HOME}/.cache}"
    return "${PASS}"
}

###############################################################################
# env::get_xdg_state_home
#------------------------------------------------------------------------------
# Purpose  : Get XDG state directory (with fallback)
# Usage    : state_dir=$(env::get_xdg_state_home)
# Returns  : Prints state directory path
###############################################################################
function env::get_xdg_state_home() {
    printf '%s\n' "${XDG_STATE_HOME:-${HOME}/.local/state}"
    return "${PASS}"
}

###############################################################################
# env::exists
#------------------------------------------------------------------------------
# Purpose  : Check if an environment variable is defined (set or empty)
# Usage    : env::exists VAR_NAME
# Arguments:
#   $1 : Variable name to check (required)
# Returns  : PASS if defined, FAIL if not defined
# Globals  : None
###############################################################################
function env::exists() {
    local var="${1:-}"

    if [[ -z "${var}" ]]; then
        error "env::exists requires a variable name."
        return "${FAIL}"
    fi

    if [[ -v "${var}" ]]; then
        debug "Environment variable exists: ${var}"
        return "${PASS}"
    fi

    debug "Environment variable not found: ${var}"
    return "${FAIL}"
}

###############################################################################
# env::check
#------------------------------------------------------------------------------
# Purpose  : Check that an environment variable exists and is non-empty
# Usage    : env::check VAR_NAME
# Arguments:
#   $1 : Variable name to check (required)
# Returns  : PASS if defined and non-empty, FAIL otherwise
# Globals  : None
###############################################################################
function env::check() {
    local var="${1:-}"

    if [[ -z "${var}" ]]; then
        fail "env::check requires a variable name."
        return "${FAIL}"
    fi

    if ! env::exists "${var}"; then
        fail "Variable '${var}' is not defined."
        return "${FAIL}"
    fi

    local value
    value="$(env::get "${var}" "")"

    if [[ -z "${value}" ]]; then
        warn "Variable '${var}' exists but is empty."
        return "${FAIL}"
    fi

    pass "Environment variable '${var}' is set: ${value}"
    return "${PASS}"
}

###############################################################################
# env::get
#------------------------------------------------------------------------------
# Purpose  : Retrieve an env variable's value, with optional default fallback
# Usage    : env::get VAR_NAME [default]
# Arguments:
#   $1 : Variable name (required)
#   $2 : Default value if not found (optional)
# Returns  : PASS always
# Outputs  : Variable value or default
# Globals  : None
###############################################################################
function env::get() {
    local var="${1:-}" default="${2:-}"

    if [[ -z "${var}" ]]; then
        error "env::get requires a variable name."
        return "${FAIL}"
    fi

    printf '%s\n' "${!var:-${default}}"
    return "${PASS}"
}

###############################################################################
# env::set
#------------------------------------------------------------------------------
# Purpose  : Set an environment variable to a value
# Usage    : env::set VAR_NAME VALUE
# Arguments:
#   $1 : Variable name (required)
#   $2 : Value to set (required)
# Returns  : PASS on success, FAIL on missing argument
# Globals  : None
###############################################################################
function env::set() {
    local var="${1:-}" value="${2:-}"

    if [[ -z "${var}" ]]; then
        error "env::set requires a variable name."
        return "${FAIL}"
    fi

    export "${var}=${value}"
    pass "Set ${var}=${value}"
    return "${PASS}"
}

###############################################################################
# env::unset
#------------------------------------------------------------------------------
# Purpose  : Remove an environment variable
# Usage    : env::unset VAR_NAME
# Arguments:
#   $1 : Variable name (required)
# Returns  : PASS on success, FAIL on missing argument
# Globals  : None
###############################################################################
function env::unset() {
    local var="${1:-}"

    if [[ -z "${var}" ]]; then
        error "env::unset requires a variable name."
        return "${FAIL}"
    fi

    unset "${var}"
    pass "Unset ${var}"
    return "${PASS}"
}

###############################################################################
# env::require
#------------------------------------------------------------------------------
# Purpose  : Require an environment variable to be set; exit if missing
# Usage    : env::require VAR_NAME ["custom error"]
# Arguments:
#   $1 : Variable name (required)
#   $2 : Custom error message (optional)
# Returns  : PASS if defined, exits 1 if missing
# Globals  : None
###############################################################################
function env::require() {
    local var="${1:-}"
    local msg="${2:-Required environment variable missing: ${var}}"

    if ! env::exists "${var}"; then
        error "${msg}"
        exit 1
    fi

    pass "Required variable present: ${var}"
    return "${PASS}"
}

#===============================================================================
# PATH Manipulation
#===============================================================================

###############################################################################
# env::remove_from_path
#------------------------------------------------------------------------------
# Purpose  : Remove a directory from PATH safely
# Usage    : env::remove_from_path "/usr/local/bin"
# Arguments:
#   $1 : Path to remove (required)
# Returns  : PASS on success (even if no-op), FAIL on bad input
# Globals  : PATH
###############################################################################
function env::remove_from_path() {
    local target="${1:-}"

    if [[ -z "${target}" ]]; then
        fail "No path provided to env::remove_from_path."
        return "${FAIL}"
    fi

    # Build new PATH by filtering out target
    local new_path="" entry
    local IFS=':'

    for entry in ${PATH}; do
        # Skip if matches target (exact match)
        [[ "${entry}" == "${target}" ]] && continue

        # Add to new path
        if [[ -z "${new_path}" ]]; then
            new_path="${entry}"
        else
            new_path="${new_path}:${entry}"
        fi
    done

    if [[ "${new_path}" == "${PATH}" ]]; then
        info "Path not in \$PATH: ${target}"
        return "${PASS}"
    fi

    export PATH="${new_path}"
    pass "Removed '${target}' from PATH."
    return "${PASS}"
}

###############################################################################
# env::validate_env_file
#------------------------------------------------------------------------------
# Purpose  : Validate .env file format
# Usage    : env::validate_env_file "/path/to/.env"
# Returns  : PASS if valid, FAIL if errors found
###############################################################################
function env::validate_env_file() {
    local file="${1:-}"

    if [[ -z "${file}" ]]; then
        error "env::validate_env_file requires a file path"
        return "${FAIL}"
    fi

    if ! file::exists "${file}"; then
        error "File not found: ${file}"
        return "${FAIL}"
    fi

    local line_num=0 errors=0
    while IFS= read -r line; do
        ((line_num++))

        # Skip empty lines and comments
        [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]] && continue

        # Check format: KEY=VALUE
        if ! [[ "${line}" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
            warn "Line ${line_num}: Invalid format: ${line}"
            ((errors++))
        fi
    done < "${file}"

    if [[ ${errors} -eq 0 ]]; then
        pass "Environment file validation passed: ${file}"
        return "${PASS}"
    fi

    fail "Environment file has ${errors} error(s): ${file}"
    return "${FAIL}"
}

#===============================================================================
# Environment File Helpers
#===============================================================================

###############################################################################
# env::diff_files
#------------------------------------------------------------------------------
# Purpose  : Show differences between two .env files
# Usage    : env::diff_files ".env" ".env.production"
# Returns  : PASS if successful, FAIL otherwise
###############################################################################
function env::diff_files() {
    local file1="${1:-}"
    local file2="${2:-}"

    if [[ -z "${file1}" || -z "${file2}" ]]; then
        error "Usage: env::diff_files <file1> <file2>"
        return "${FAIL}"
    fi

    if ! file::exists "${file1}" || ! file::exists "${file2}"; then
        error "One or both files not found"
        return "${FAIL}"
    fi

    if cmd::exists diff; then
        diff -u "${file1}" "${file2}" || true
        return "${PASS}"
    fi

    warn "diff command not available"
    return "${FAIL}"
}

###############################################################################
# env::export_file
#------------------------------------------------------------------------------
# Purpose  : Load environment variables from a .env file (KEY=VALUE)
# Usage    : env::export_file "/path/to/.env"
# Arguments:
#   $1 : Path to .env file (required)
# Returns  : PASS on success, FAIL if file not found
# Globals  : Exports variables from file
###############################################################################
function env::export_file() {
    local file="${1:-}"

    if ! file::exists "${file}"; then
        error "Env file not found: ${file}"
        return "${FAIL}"
    fi

    while IFS='=' read -r key val; do
        [[ -z "${key}" || "${key}" == \#* ]] && continue
        export "${key}=${val}"
        debug "Loaded: ${key}=${val}"
    done < "${file}"

    pass "Loaded environment from ${file}"
    return "${PASS}"
}

###############################################################################
# env::save_to_file
#------------------------------------------------------------------------------
# Purpose  : Save selected environment variables to a file
# Usage    : env::save_to_file "/tmp/env" VAR1 VAR2 VAR3
# Arguments:
#   $1 : Output file path (required)
#   $@ : Variable names to save (required)
# Returns  : PASS on success, FAIL on invalid usage
# Globals  : None
###############################################################################
function env::save_to_file() {
    local file="${1:-}"
    shift || true

    if [[ -z "${file}" || $# -eq 0 ]]; then
        error "Usage: env::save_to_file <file> VAR1 VAR2 ..."
        return "${FAIL}"
    fi

    : > "${file}"

    local var
    for var in "$@"; do
        if env::exists "${var}"; then
            printf '%s=%q\n' "${var}" "${!var}" >> "${file}"
        fi
    done

    pass "Saved environment variables to ${file}"
    return "${PASS}"
}

#===============================================================================
# Environment Detection Helpers
#===============================================================================

###############################################################################
# env::is_ci
#------------------------------------------------------------------------------
# Purpose  : Detect continuous integration environments
# Usage    : env::is_ci && info "CI detected"
# Returns  : PASS if CI detected, FAIL otherwise
# Globals  : Checks CI, GITHUB_ACTIONS, GITLAB_CI, JENKINS_HOME, CIRCLECI, TRAVIS
###############################################################################
function env::is_ci() {
    local ci_vars=(
        "CI" "GITHUB_ACTIONS" "GITLAB_CI"
        "JENKINS_HOME" "CIRCLECI" "TRAVIS"
    )

    local v
    for v in "${ci_vars[@]}"; do
        if env::exists "${v}"; then
            debug "CI detected via ${v}"
            return "${PASS}"
        fi
    done

    return "${FAIL}"
}

###############################################################################
# env::is_container
#------------------------------------------------------------------------------
# Purpose  : Detect Docker/Podman/container environments
# Usage    : env::is_container && info "Container detected"
# Returns  : PASS if container detected, FAIL otherwise
# Globals  : None
###############################################################################
function env::is_container() {
    if file::is_readable "/.dockerenv" ||
        grep -q "docker" /proc/1/cgroup 2> /dev/null; then
        debug "Container detected"
        return "${PASS}"
    fi
    return "${FAIL}"
}

#===============================================================================
# User/System Context Helpers
#===============================================================================

###############################################################################
# env::get_user
#------------------------------------------------------------------------------
# Purpose  : Print current username
# Usage    : user=$(env::get_user)
# Returns  : PASS always
# Outputs  : Current username
# Globals  : None
###############################################################################
function env::get_user() {
    local u
    u="$(id -un 2> /dev/null || whoami 2> /dev/null || echo "unknown")"
    printf '%s\n' "${u}"
    return "${PASS}"
}

###############################################################################
# env::get_home
#------------------------------------------------------------------------------
# Purpose  : Print user home directory
# Usage    : home=$(env::get_home)
# Returns  : PASS always
# Outputs  : Home directory path
# Globals  : HOME
###############################################################################
function env::get_home() {
    printf '%s\n' "${HOME:-/tmp}"
    return "${PASS}"
}

###############################################################################
# env::get_temp_dir
#------------------------------------------------------------------------------
# Purpose  : Print temp directory
# Usage    : tmp=$(env::get_temp_dir)
# Returns  : PASS always
# Outputs  : Temp directory path
# Globals  : TMPDIR
###############################################################################
function env::get_temp_dir() {
    printf '%s\n' "${TMPDIR:-/tmp}"
    return "${PASS}"
}

###############################################################################
# env::is_tmux
#------------------------------------------------------------------------------
# Purpose  : Detect if inside tmux session
# Usage    : env::is_tmux && info "In tmux"
# Returns  : PASS if in tmux, FAIL otherwise
# Globals  : TMUX
###############################################################################
function env::is_tmux() {
    [[ -n "${TMUX:-}" ]] && {
        debug "tmux detected"
        return "${PASS}"
    }
    return "${FAIL}"
}

###############################################################################
# env::is_screen
#------------------------------------------------------------------------------
# Purpose  : Detect if inside GNU screen
# Usage    : env::is_screen && info "In screen"
# Returns  : PASS if in screen, FAIL otherwise
# Globals  : STY
###############################################################################
function env::is_screen() {
    [[ -n "${STY:-}" ]] && {
        debug "screen detected"
        return "${PASS}"
    }
    return "${FAIL}"
}

###############################################################################
# env::self_test
#------------------------------------------------------------------------------
# Purpose  : Self-test for util_env.sh functionality
# Usage    : env::self_test
# Returns  : PASS (0) if all tests pass, FAIL (1) otherwise
# Globals  : None
###############################################################################
function env::self_test() {
    info "Running util_env.sh self-test..."

    local status="${PASS}"

    # Test 1: XDG functions
    if ! env::get_xdg_config_home > /dev/null 2>&1; then
        fail "env::get_xdg_config_home failed"
        status="${FAIL}"
    fi

    # Test 2: env::exists for a known variable
    if ! env::exists "PATH"; then
        fail "env::exists failed for PATH"
        status="${FAIL}"
    fi

    # Test 3: env::get for a known variable
    if ! env::get "HOME" > /dev/null 2>&1; then
        fail "env::get failed for HOME"
        status="${FAIL}"
    fi

    # Test 4: env::get_user
    if ! env::get_user > /dev/null 2>&1; then
        fail "env::get_user failed"
        status="${FAIL}"
    fi

    if [[ "${status}" -eq "${PASS}" ]]; then
        pass "util_env.sh self-test passed"
    else
        fail "util_env.sh self-test failed"
    fi

    return "${status}"
}
