#!/usr/bin/env bash
###############################################################################
# NAME         : util.sh
# DESCRIPTION  : Core utility loader - defines global constants, provides
#                logging fallbacks, and loads all util_*.sh modules in
#                dependency order.
# AUTHOR       : Adam Compton
# DATE CREATED : 2024-12-15
###############################################################################
# EDIT HISTORY:
# DATE       | EDITED BY      | DESCRIPTION
# -----------|----------------|------------------------------------------------
# 2024-12-15 | Adam Compton   | Initial creation
# 2025-10-29 | Adam Compton   | Updated to load util_*.sh files from ./utils/
#            |                | Added local log function fallbacks (no color).
# 2025-12-25 | Adam Compton   | Corrected: Export PASS/FAIL globally, added
#            |                | is_root(), enforced dependency-ordered loading
# 2025-12-26 | Adam Compton   | Fixed: Corrected os::is_root() wrapper to call
#            |                | is_root instead of non-existent _is_root
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Library Guard
#===============================================================================
if [[ -n "${UTILS_SH_LOADED:-}" ]]; then
    if (return 0 2> /dev/null); then
        return 0
    else
        exit 0
    fi
else
    export UTILS_SH_LOADED=1
fi

#===============================================================================
# Global Constants (Exported for all modules)
#===============================================================================
export PASS=0
export FAIL=1
readonly PASS FAIL

#===============================================================================
# Environment Setup
#===============================================================================
export DEBIAN_FRONTEND=noninteractive

UTILS_PATH="$(realpath "${BASH_SOURCE[0]}")"
UTILS_DIR="$(dirname "${UTILS_PATH}")"

#===============================================================================
# Early Log Level Detection
#------------------------------------------------------------------------------
# Read log level BEFORE loading modules to control startup verbosity.
# Priority: Environment variable > Config file > Default (info)
#
# Log Level Priorities:
#   debug=20, info=30, pass=40, warn=50, error/fail=60
#===============================================================================
declare -gA _UTIL_LOG_PRIORITIES=(
    [debug]=20
    [info]=30
    [pass]=40
    [warn]=50
    [error]=60
    [fail]=60
    [none]=100
)

# Default log level
_UTIL_CURRENT_LOG_LEVEL="${UTIL_LOG_LEVEL:-}"

# If not set via environment, try to read from config file
if [[ -z "${_UTIL_CURRENT_LOG_LEVEL}" ]]; then
    _UTIL_CONFIG_FILE="${HOME}/.bash_util.conf"
    if [[ -f "${_UTIL_CONFIG_FILE}" && -r "${_UTIL_CONFIG_FILE}" ]]; then
        # Simple grep for log.level - avoid sourcing untrusted file
        _UTIL_CONFIG_LEVEL=$(grep -E '^\s*log\.level\s*=' "${_UTIL_CONFIG_FILE}" 2> /dev/null | head -1 | sed 's/.*=\s*//' | tr -d '[:space:]"'"'")
        if [[ -n "${_UTIL_CONFIG_LEVEL}" ]]; then
            _UTIL_CURRENT_LOG_LEVEL="${_UTIL_CONFIG_LEVEL}"
        fi
    fi
fi

# Final default: warn (suppresses debug, pass, and info messages during startup)
_UTIL_CURRENT_LOG_LEVEL="${_UTIL_CURRENT_LOG_LEVEL:-warn}"

# Get numeric priority for current level
_UTIL_CURRENT_PRIORITY="${_UTIL_LOG_PRIORITIES[${_UTIL_CURRENT_LOG_LEVEL}]:-30}"

###############################################################################
# _util_should_log
#------------------------------------------------------------------------------
# Purpose  : Check if a message at given level should be logged
# Usage    : _util_should_log "debug" && printf "message"
# Arguments:
#   $1 : Log level to check
# Returns  : 0 if should log, 1 if should suppress
###############################################################################
function _util_should_log() {
    local level="${1:-info}"
    local priority="${_UTIL_LOG_PRIORITIES[${level}]:-30}"
    [[ "${priority}" -ge "${_UTIL_CURRENT_PRIORITY}" ]]
}

#===============================================================================
# Logging Functions (Fallbacks for all modules)
#------------------------------------------------------------------------------
# These functions are defined only if not already provided by sourced modules.
# All util_*.sh files will use these if no color logging is available.
# Fallbacks respect the configured log level.
#===============================================================================
if ! declare -F info > /dev/null 2>&1; then
    function info() { _util_should_log info && printf '[INFO ] %s\n' "${*}" >&2; }
fi

if ! declare -F warn > /dev/null 2>&1; then
    function warn() { _util_should_log warn && printf '[WARN ] %s\n' "${*}" >&2; }
fi

if ! declare -F error > /dev/null 2>&1; then
    function error() { _util_should_log error && printf '[ERROR] %s\n' "${*}" >&2; }
fi

if ! declare -F debug > /dev/null 2>&1; then
    function debug() { _util_should_log debug && printf '[DEBUG] %s\n' "${*}" >&2; }
fi

if ! declare -F pass > /dev/null 2>&1; then
    function pass() { _util_should_log pass && printf '[PASS ] %s\n' "${*}" >&2; }
fi

if ! declare -F fail > /dev/null 2>&1; then
    function fail() { _util_should_log fail && printf '[FAIL ] %s\n' "${*}" >&2; }
fi

#===============================================================================
# Core System Functions - Foundation Layer
#------------------------------------------------------------------------------
# These must be defined before loading any util_*.sh modules
#===============================================================================

###############################################################################
# is_root
#------------------------------------------------------------------------------
# Purpose  : Check if running as root user (EUID == 0)
# Usage    : is_root && info "Running as root"
# Returns  : PASS (0) if root, FAIL (1) otherwise
###############################################################################
function is_root() {
    [[ "${EUID:-65535}" -eq 0 ]] && return "${PASS}" || return "${FAIL}"
}

###############################################################################
# os::is_root
#------------------------------------------------------------------------------
# Purpose  : Namespaced wrapper for is_root (for consistency with util_os.sh)
# Usage    : os::is_root && info "Running as root"
# Returns  : PASS (0) if root, FAIL (1) otherwise
###############################################################################
function os::is_root() {
    is_root
}

###############################################################################
# cmd::exists
#------------------------------------------------------------------------------
# Purpose  : Check if command exists in PATH (foundation for all modules)
# Usage    : cmd::exists "curl" && info "curl available"
# Arguments:
#   $1 : Command name to check
# Returns  : PASS (0) if exists, FAIL (1) otherwise
###############################################################################
function cmd::exists() {
    local cmd="${1:-}"
    [[ -z "${cmd}" ]] && return "${FAIL}"
    command -v "${cmd}" > /dev/null 2>&1
}

#===============================================================================
# Dynamic Utility Loader
#------------------------------------------------------------------------------
# Loads all util_*.sh scripts in dependency order.
# Fails fast if any source fails. Logs each action without color.
#
# Load Order (by dependency layer):
#   Layer 1: util_platform.sh, util_config.sh, util_trap.sh (foundation)
#   Layer 2: util_env.sh (depends on platform)
#   Layer 3: util_cmd.sh (standalone)
#   Layer 4: util_file.sh, util_tui.sh (depend on platform, config)
#   Layer 5: util_os.sh, util_dir.sh (depend on platform, config)
#   Layer 6: util_curl.sh, util_git.sh (depend on platform, config, trap)
#   Layer 7: util_net.sh (depends on platform)
#   Layer 8: util_apt.sh, util_brew.sh (package managers, depend on config)
#   Layer 9: util_py.sh, util_ruby.sh, util_go.sh (language tools)
#   Layer 10: util_menu.sh (high-level UI, depends on config)
#===============================================================================
debug "Initializing utility loader in: ${UTILS_DIR}"

declare -a UTIL_LOAD_ORDER=(
    "util_platform.sh"
    "util_config.sh"
    "util_trap.sh"
    "util_str.sh"
    "util_env.sh"
    "util_cmd.sh"
    "util_file.sh"
    "util_tui.sh"
    "util_os.sh"
    "util_dir.sh"
    "util_curl.sh"
    "util_git.sh"
    "util_net.sh"
    "util_apt.sh"
    "util_brew.sh"
    "util_py.sh"
    "util_py_multi.sh"
    "util_ruby.sh"
    "util_go.sh"
    "util_menu.sh"
    "util_tools.sh"
)

UTILS_SOURCED=false

for util_file in "${UTIL_LOAD_ORDER[@]}"; do
    util_path="${UTILS_DIR}/utils/${util_file}"

    if [[ ! -f "${util_path}" ]]; then
        debug "Skipping missing utility: ${util_file}"
        continue
    fi

    debug "Attempting to source: ${util_file}"
    # shellcheck disable=SC1090
    if source "${util_path}"; then
        pass "Successfully sourced: ${util_file}"
        UTILS_SOURCED=true
    else
        fail "Failed to source: ${util_path}"
        exit 1
    fi
done

if [[ "${UTILS_SOURCED}" == false ]]; then
    warn "No util_*.sh scripts found in ${UTILS_DIR}"
else
    debug "All utility modules loaded successfully."
fi

#===============================================================================
# Exported Variables
#===============================================================================
export UTILS_DIR UTILS_SOURCED
debug "Utility framework initialization complete."

###############################################################################
# utils::self_test
#------------------------------------------------------------------------------
# Purpose  : Self-test for util.sh core functionality
# Usage    : utils::self_test
# Returns  : PASS (0) if all tests pass, FAIL (1) otherwise
# Globals  : UTILS_SH_LOADED, PASS, FAIL, UTILS_DIR, UTILS_SOURCED
###############################################################################
function utils::self_test() {
    info "Running util.sh self-test..."

    local status="${PASS}"

    # Test 1: Check module loaded
    if [[ "${UTILS_SH_LOADED:-0}" -ne 1 ]]; then
        fail "util.sh not loaded properly"
        status="${FAIL}"
    fi

    # Test 2: Check PASS/FAIL constants
    if [[ "${PASS}" -ne 0 ]] || [[ "${FAIL}" -ne 1 ]]; then
        fail "PASS/FAIL constants not set correctly"
        status="${FAIL}"
    fi

    # Test 3: Check core functions
    if ! declare -F is_root > /dev/null 2>&1; then
        fail "is_root function not available"
        status="${FAIL}"
    fi

    if ! declare -F cmd::exists > /dev/null 2>&1; then
        fail "cmd::exists function not available"
        status="${FAIL}"
    fi

    if ! declare -F os::is_root > /dev/null 2>&1; then
        fail "os::is_root function not available"
        status="${FAIL}"
    fi

    # Test 4: Check logging functions
    for func in info warn error debug pass fail; do
        if ! declare -F "${func}" > /dev/null 2>&1; then
            fail "${func} function not available"
            status="${FAIL}"
        fi
    done

    # Test 5: Check UTILS_DIR is set
    if [[ -z "${UTILS_DIR:-}" ]]; then
        fail "UTILS_DIR not set"
        status="${FAIL}"
    fi

    # Test 6: Test cmd::exists with a known command
    if ! cmd::exists "bash"; then
        fail "cmd::exists failed for 'bash'"
        status="${FAIL}"
    fi

    if [[ "${status}" -eq "${PASS}" ]]; then
        pass "util.sh self-test passed"
    else
        fail "util.sh self-test failed"
    fi

    return "${status}"
}
