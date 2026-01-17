#!/usr/bin/env bash
###############################################################################
# NAME         : util_trap.sh
# DESCRIPTION  : Safe trap handling and cleanup utilities
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-12-25
###############################################################################
# EDIT HISTORY:
# DATE        | EDITED BY      | DESCRIPTION
# ------------|----------------|-----------------------------------------------
# 2025-12-25  | Adam Compton   | Initial creation
# 2025-12-26  | Adam Compton   | Fixed library guard structure, added security
#             |                | documentation for eval usage
# 2026-01-03  | Adam Compton   | CRITICAL: Removed unsafe eval - now only
#             |                | executes declared functions. Fixed empty array
#             |                | iteration bug with set -u. Added -- separators.
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Library Guard
#===============================================================================
if [[ -n "${UTIL_TRAP_SH_LOADED:-}" ]]; then
    if (return 0 2> /dev/null); then
        return 0
    fi
else
    UTIL_TRAP_SH_LOADED=1
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
# Global Constants
#===============================================================================
: "${PASS:=0}"
: "${FAIL:=1}"

#===============================================================================
# Trap Management
#===============================================================================

# Stack of cleanup functions to execute on exit
declare -ga TRAP_CLEANUP_STACK=()

# Temporary files/directories to clean up
declare -ga TRAP_TEMP_FILES=()
declare -ga TRAP_TEMP_DIRS=()

###############################################################################
# trap::add_cleanup
#------------------------------------------------------------------------------
# Purpose  : Add a cleanup FUNCTION to the exit trap stack
# Usage    : trap::add_cleanup "my_cleanup_function"
# Arguments:
#   $1 : Function name to execute on exit (MUST be a declared function)
# Returns  : PASS if function registered, FAIL if invalid
# Notes    : Cleanup functions execute in LIFO order (last added, first executed)
# Security : ONLY accepts declared function names, not arbitrary commands.
#            This prevents command injection attacks via the cleanup mechanism.
###############################################################################
function trap::add_cleanup() {
    local cleanup="${1:-}"

    if [[ -z "${cleanup}" ]]; then
        error "trap::add_cleanup: Function name required"
        return "${FAIL}"
    fi

    # SECURITY FIX: Validate that cleanup is a declared function
    # This prevents arbitrary command execution
    if ! declare -F "${cleanup}" > /dev/null 2>&1; then
        error "trap::add_cleanup: '${cleanup}' is not a declared function"
        error "Hint: Define the function before registering it for cleanup"
        error "Example:"
        error "  my_cleanup() { rm -f -- \"\${my_temp_file}\"; }"
        error "  trap::add_cleanup my_cleanup"
        return "${FAIL}"
    fi

    TRAP_CLEANUP_STACK+=("${cleanup}")
    debug "Added cleanup function: ${cleanup}"

    # Install trap handler if not already installed
    trap::_install_handler

    return "${PASS}"
}

###############################################################################
# trap::add_temp_file
#------------------------------------------------------------------------------
# Purpose  : Register a temporary file for automatic cleanup
# Usage    : trap::add_temp_file "${tmp_file}"
# Arguments:
#   $1 : Path to temporary file
# Returns  : PASS if registered, FAIL if empty path
###############################################################################
function trap::add_temp_file() {
    local file="${1:-}"

    if [[ -z "${file}" ]]; then
        error "trap::add_temp_file: File path required"
        return "${FAIL}"
    fi

    TRAP_TEMP_FILES+=("${file}")
    debug "Registered temp file for cleanup: ${file}"

    trap::_install_handler

    return "${PASS}"
}

###############################################################################
# trap::add_temp_dir
#------------------------------------------------------------------------------
# Purpose  : Register a temporary directory for automatic cleanup
# Usage    : trap::add_temp_dir "${tmp_dir}"
# Arguments:
#   $1 : Path to temporary directory
# Returns  : PASS if registered, FAIL if empty path
###############################################################################
function trap::add_temp_dir() {
    local dir="${1:-}"

    if [[ -z "${dir}" ]]; then
        error "trap::add_temp_dir: Directory path required"
        return "${FAIL}"
    fi

    TRAP_TEMP_DIRS+=("${dir}")
    debug "Registered temp directory for cleanup: ${dir}"

    trap::_install_handler

    return "${PASS}"
}

###############################################################################
# trap::_cleanup_handler
#------------------------------------------------------------------------------
# Purpose  : Internal cleanup handler (executes all registered cleanup functions)
# Usage    : Called automatically by trap
# Returns  : Original exit code (preserved through cleanup)
# Security : ONLY executes declared functions, never arbitrary strings.
#            Each cleanup entry was validated by trap::add_cleanup() to be
#            a declared function. We re-validate here for defense in depth.
###############################################################################
function trap::_cleanup_handler() {
    local exit_code=$?

    debug "Running cleanup handler (exit code: ${exit_code})"

    # SECURITY FIX: Execute cleanup functions in reverse order (LIFO)
    # Only execute if it's a declared function - NO eval of arbitrary strings
    if [[ ${#TRAP_CLEANUP_STACK[@]} -gt 0 ]]; then
        local i cleanup
        for ((i = ${#TRAP_CLEANUP_STACK[@]} - 1; i >= 0; i--)); do
            cleanup="${TRAP_CLEANUP_STACK[i]}"
            debug "Executing cleanup: ${cleanup}"

            # SECURITY: Re-validate and only execute declared functions
            if declare -F "${cleanup}" > /dev/null 2>&1; then
                # Execute function directly - no eval needed
                "${cleanup}" 2> /dev/null || true
            else
                warn "trap::_cleanup_handler: Skipping non-function: ${cleanup}"
            fi
        done
    fi

    # SECURITY FIX: Check array is non-empty before iteration (fixes set -u issue)
    # Clean up temporary files with -- to prevent argument injection
    if [[ ${#TRAP_TEMP_FILES[@]} -gt 0 ]]; then
        local file
        for file in "${TRAP_TEMP_FILES[@]}"; do
            if [[ -n "${file}" && -f "${file}" ]]; then
                debug "Removing temp file: ${file}"
                rm -f -- "${file}" 2> /dev/null || true
            fi
        done
    fi

    # Clean up temporary directories with -- to prevent argument injection
    if [[ ${#TRAP_TEMP_DIRS[@]} -gt 0 ]]; then
        local dir
        for dir in "${TRAP_TEMP_DIRS[@]}"; do
            if [[ -n "${dir}" && -d "${dir}" ]]; then
                debug "Removing temp directory: ${dir}"
                rm -rf -- "${dir}" 2> /dev/null || true
            fi
        done
    fi

    return "${exit_code}"
}

###############################################################################
# trap::_install_handler
#------------------------------------------------------------------------------
# Purpose  : Install the cleanup handler (internal, idempotent)
# Usage    : Called automatically
# Returns  : PASS always
###############################################################################
function trap::_install_handler() {
    # Use marker to ensure we only install once
    if [[ "${TRAP_HANDLER_INSTALLED:-0}" -eq 1 ]]; then
        return "${PASS}"
    fi

    # Install trap for multiple signals
    trap trap::_cleanup_handler EXIT SIGINT SIGTERM

    TRAP_HANDLER_INSTALLED=1
    debug "Installed trap cleanup handler"

    return "${PASS}"
}

###############################################################################
# trap::with_cleanup
#------------------------------------------------------------------------------
# Purpose  : Execute a command with automatic temp file cleanup
# Usage    : result=$(trap::with_cleanup mktemp /tmp/foo.XXXXXX)
# Arguments:
#   $@ : Command to execute
# Returns  : Exit code of command
# Outputs  : Output of command
# Notes    : If command creates a file and prints its path, registers it for cleanup
###############################################################################
function trap::with_cleanup() {
    if [[ $# -eq 0 ]]; then
        error "trap::with_cleanup: Command required"
        return "${FAIL}"
    fi

    local output
    output=$("$@")
    local exit_code=$?

    # If output looks like a file path, register for cleanup
    if [[ -n "${output}" ]] && [[ -e "${output}" ]]; then
        if [[ -f "${output}" ]]; then
            trap::add_temp_file "${output}"
        elif [[ -d "${output}" ]]; then
            trap::add_temp_dir "${output}"
        fi
    fi

    printf '%s\n' "${output}"
    return "${exit_code}"
}

###############################################################################
# trap::clear_all
#------------------------------------------------------------------------------
# Purpose  : Clear all registered cleanup functions and temp files/dirs
# Usage    : trap::clear_all
# Returns  : PASS always
# Notes    : Use with caution - typically only needed in testing
###############################################################################
function trap::clear_all() {
    TRAP_CLEANUP_STACK=()
    TRAP_TEMP_FILES=()
    TRAP_TEMP_DIRS=()

    debug "Cleared all trap cleanup registrations"
    return "${PASS}"
}

###############################################################################
# trap::list
#------------------------------------------------------------------------------
# Purpose  : List all registered cleanup items (for debugging)
# Usage    : trap::list
# Returns  : PASS always
# Outputs  : List of registered cleanups to stderr
###############################################################################
function trap::list() {
    info "Registered cleanup functions (${#TRAP_CLEANUP_STACK[@]}):"
    if [[ ${#TRAP_CLEANUP_STACK[@]} -gt 0 ]]; then
        local i
        for i in "${!TRAP_CLEANUP_STACK[@]}"; do
            info "  [${i}] ${TRAP_CLEANUP_STACK[i]}"
        done
    else
        info "  (none)"
    fi

    info "Registered temp files (${#TRAP_TEMP_FILES[@]}):"
    if [[ ${#TRAP_TEMP_FILES[@]} -gt 0 ]]; then
        local f
        for f in "${TRAP_TEMP_FILES[@]}"; do
            info "  ${f}"
        done
    else
        info "  (none)"
    fi

    info "Registered temp directories (${#TRAP_TEMP_DIRS[@]}):"
    if [[ ${#TRAP_TEMP_DIRS[@]} -gt 0 ]]; then
        local d
        for d in "${TRAP_TEMP_DIRS[@]}"; do
            info "  ${d}"
        done
    else
        info "  (none)"
    fi

    return "${PASS}"
}

###############################################################################
# trap::self_test
#------------------------------------------------------------------------------
# Purpose  : Self-test for util_trap.sh functionality
# Usage    : trap::self_test
# Returns  : PASS (0) if all tests pass, FAIL (1) otherwise
# Globals  : TRAP_CLEANUP_STACK, TRAP_TEMP_FILES, TRAP_TEMP_DIRS
###############################################################################
function trap::self_test() {
    info "Running util_trap.sh self-test..."

    local status="${PASS}"

    # Test 1: Check cleanup stack exists
    if ! declare -p TRAP_CLEANUP_STACK > /dev/null 2>&1; then
        fail "TRAP_CLEANUP_STACK not defined"
        status="${FAIL}"
    else
        pass "TRAP_CLEANUP_STACK defined"
    fi

    # Test 2: Check critical functions exist
    local -a required_functions=(
        trap::add_cleanup
        trap::add_temp_file
        trap::add_temp_dir
        trap::with_cleanup
        trap::clear_all
    )

    local func
    for func in "${required_functions[@]}"; do
        if ! declare -F "${func}" > /dev/null 2>&1; then
            fail "${func} function not available"
            status="${FAIL}"
        else
            pass "${func} function available"
        fi
    done

    # Test 3: Test that non-function is rejected (SECURITY TEST)
    if trap::add_cleanup "rm -rf /" 2> /dev/null; then
        fail "SECURITY: trap::add_cleanup accepted non-function string"
        status="${FAIL}"
    else
        pass "SECURITY: trap::add_cleanup correctly rejects non-functions"
    fi

    # Test 4: Test that valid function is accepted
    ###############################################################################
    # _trap_test_cleanup_func - Test helper for trap::add_cleanup validation
    ###############################################################################
    function _trap_test_cleanup_func() { true; }
    if trap::add_cleanup _trap_test_cleanup_func; then
        pass "trap::add_cleanup accepts declared functions"
    else
        fail "trap::add_cleanup rejected valid function"
        status="${FAIL}"
    fi

    # Test 5: Test temp file registration
    local test_tmp
    test_tmp=$(mktemp) || {
        fail "Could not create temp file for testing"
        status="${FAIL}"
    }

    if [[ -n "${test_tmp}" ]]; then
        if trap::add_temp_file "${test_tmp}"; then
            pass "trap::add_temp_file works"
        else
            fail "trap::add_temp_file failed"
            status="${FAIL}"
        fi
        rm -f -- "${test_tmp}" 2> /dev/null || true
    fi

    # Cleanup test artifacts
    trap::clear_all
    unset -f _trap_test_cleanup_func 2> /dev/null || true

    if [[ "${status}" -eq "${PASS}" ]]; then
        pass "util_trap.sh self-test passed"
    else
        fail "util_trap.sh self-test failed"
    fi

    return "${status}"
}
