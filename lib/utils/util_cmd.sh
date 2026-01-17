#!/usr/bin/env bash
###############################################################################
# NAME         : util_cmd.sh
# DESCRIPTION  : Command execution, validation, and process control utilities.
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-10-27
###############################################################################
# EDIT HISTORY:
# DATE       | EDITED BY      | DESCRIPTION
# -----------|----------------|------------------------------------------------
# 2025-10-27 | Adam Compton   | Initial generation (style-guide compliant)
# 2025-11-20 | Adam Compton   | Merged utils_cmd.sh, added compatibility
#            |                | wrappers and self-test, normalized headers
# 2025-12-25 | Adam Compton   | Corrected: Removed PASS/FAIL defs, added
#            |                | logging fallbacks, uses is_root from util.sh,
#            |                | standardized error messages
# 2025-12-26 | Adam Compton   | Added cmd::ensure (auto-install missing tools),
#            |                | cmd::test (verify command exit codes), and
#            |                | cmd::install_package (generic package install)
# 2025-12-27 | Adam Compton   | Refactored cmd::parallel, cmd::test, cmd::test_tool
#            |                | to use arrays instead of eval/bash -c. Added
#            |                | cmd::parallel_array for complex argument handling.
# 2025-12-28 | Adam Compton   | Updated cmd::timeout to use platform::timeout
#            |                | for cross-platform macOS/Linux compatibility
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Library Guard
#===============================================================================
if [[ -n "${UTIL_CMD_SH_LOADED:-}" ]]; then
    if (return 0 2> /dev/null); then return 0; fi
else
    UTIL_CMD_SH_LOADED=1
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
# Global Constants (imported from util.sh)
#===============================================================================
: "${PASS:=0}"
: "${FAIL:=1}"

#===============================================================================
# Command Availability
#===============================================================================

###############################################################################
# cmd::require
#------------------------------------------------------------------------------
# Purpose  : Ensure that a command is installed; exit with an error if missing.
# Usage    : cmd::require "git"
# Arguments:
#   $1 : Command name to check (required)
# Returns  : PASS (0) if command exists, exits 1 if missing
# Requires:
#   Functions: cmd::exists, error, pass
###############################################################################
function cmd::require() {
    local cmd="${1:-}"
    if [[ -z "${cmd}" ]]; then
        error "cmd::require: requires a command name"
        exit 1
    fi

    if ! cmd::exists "${cmd}"; then
        error "cmd::require: missing required command: ${cmd}"
        exit 1
    fi

    pass "Command available: ${cmd}"
    return "${PASS}"
}

#===============================================================================
# Execution Wrappers
#===============================================================================

###############################################################################
# cmd::build
#------------------------------------------------------------------------------
# Purpose  : Build a command array safely (helper for complex commands)
# Usage    : cmd::build cmd_array "git" "config" "--global" "user.name" "value"
# Arguments:
#   $1 : Name of array variable to populate
#   $@ : Command components
# Returns  : PASS always
# Example  :
#   local -a my_cmd
#   cmd::build my_cmd git config --global user.name "John Doe"
#   "${my_cmd[@]}"
###############################################################################
function cmd::build() {
    local array_name="${1:-}"
    shift || true

    if [[ -z "${array_name}" ]]; then
        error "cmd::build: array name required"
        return "${FAIL}"
    fi

    # Use nameref to populate caller's array
    local -n cmd_array="${array_name}"
    cmd_array=("$@")

    debug "Built command: ${cmd_array[*]}"
    return "${PASS}"
}

###############################################################################
# cmd::run_with_env
#------------------------------------------------------------------------------
# Purpose  : Run command with custom environment variables
# Usage    : cmd::run_with_env "VAR1=value1" "VAR2=value2" -- command args
# Arguments:
#   $@ : Environment variables (VAR=value), then --, then command
# Returns  : Exit code of command
# Example  : cmd::run_with_env "GOOS=linux" "GOARCH=amd64" -- go build
###############################################################################
function cmd::run_with_env() {
    local -a env_vars=()
    local -a cmd_args=()
    local parsing_env=true

    while [[ $# -gt 0 ]]; do
        if [[ "$1" == "--" ]]; then
            parsing_env=false
            shift
            continue
        fi

        if [[ "${parsing_env}" == "true" ]]; then
            env_vars+=("$1")
        else
            cmd_args+=("$1")
        fi
        shift
    done

    if [[ ${#cmd_args[@]} -eq 0 ]]; then
        error "cmd::run_with_env: no command specified"
        return "${FAIL}"
    fi

    info "Executing with env: ${env_vars[*]:-none} -- ${cmd_args[*]}"

    # Build full command
    local -a full_cmd=(env)
    [[ ${#env_vars[@]} -gt 0 ]] && full_cmd+=("${env_vars[@]}")
    full_cmd+=("${cmd_args[@]}")

    "${full_cmd[@]}"
    local rc=$?

    if [[ ${rc} -eq 0 ]]; then
        pass "Command succeeded"
    else
        fail "Command failed (${rc})"
    fi

    return "${rc}"
}

###############################################################################
# cmd::run
#------------------------------------------------------------------------------
# Purpose  : Execute a command visibly with logging and exit-code reporting.
# Usage    : cmd::run ls -la /tmp
# Arguments:
#   $@ : Command and arguments to execute (required)
# Returns  : PASS (0) if command exits successfully, FAIL (1) otherwise
# Requires:
#   Functions: info, pass, fail, error
###############################################################################
function cmd::run() {
    if [[ $# -eq 0 ]]; then
        error "cmd::run: requires a command"
        return "${FAIL}"
    fi

    # Log the command being executed
    info "Executing: $*"

    # Execute with proper quoting
    "$@"
    local rc=$?

    if [[ "${rc}" -eq 0 ]]; then
        pass "Command succeeded: $*"
        return "${PASS}"
    fi

    fail "Command failed (${rc}): $*"
    return "${FAIL}"
}

###############################################################################
# cmd::run_silent
#------------------------------------------------------------------------------
# Purpose  : Execute a command silently (output suppressed).
# Usage    : cmd::run_silent rm -rf /tmp/test
# Arguments:
#   $@ : Command and arguments to execute (required)
# Returns  : PASS (0) on success, FAIL (1) otherwise
# Requires:
#   Functions: debug, error
###############################################################################
function cmd::run_silent() {
    if [[ $# -eq 0 ]]; then
        error "cmd::run_silent: requires a command"
        return "${FAIL}"
    fi

    "$@" > /dev/null 2>&1
    local rc=$?

    if [[ "${rc}" -eq 0 ]]; then
        debug "Silent command succeeded: $*"
        return "${PASS}"
    fi

    debug "Silent command failed (${rc}): $*"
    return "${FAIL}"
}

###############################################################################
# cmd::run_as_user
#------------------------------------------------------------------------------
# Purpose  : Execute a command as a specified user via sudo.
# Usage    : cmd::run_as_user "username" id
# Arguments:
#   $1 : Username to run as (required)
#   $@ : Command and arguments to execute (required)
# Returns  : PASS (0) if command succeeds, FAIL (1) otherwise
# Requires:
#   Functions: cmd::exists, pass, fail, error
###############################################################################
function cmd::run_as_user() {
    local user="${1:-}"
    shift || true

    if [[ -z "${user}" || $# -eq 0 ]]; then
        error "cmd::run_as_user: requires username and command"
        return "${FAIL}"
    fi

    if ! cmd::exists sudo; then
        error "cmd::run_as_user: sudo not available; cannot run as ${user}"
        return "${FAIL}"
    fi

    sudo -u "${user}" "$@"
    local rc=$?

    if [[ "${rc}" -eq 0 ]]; then
        pass "Ran as ${user}: $*"
        return "${PASS}"
    fi

    fail "Failed as ${user} (${rc}): $*"
    return "${FAIL}"
}

###############################################################################
# cmd::timeout
#------------------------------------------------------------------------------
# Purpose  : Run a command with a timeout constraint (cross-platform).
# Usage    : cmd::timeout 5 sleep 20
# Arguments:
#   $1 : Timeout in seconds (required)
#   $@ : Command and arguments to execute (required)
# Returns  : PASS (0) if command completes, FAIL (1) on timeout or error
# Notes    : Uses platform::timeout for cross-platform support (Linux, macOS)
# Requires:
#   Functions: platform::timeout (from util_platform.sh), pass, fail, error
###############################################################################
function cmd::timeout() {
    local seconds="${1:-}"
    shift || true

    if [[ -z "${seconds}" || $# -eq 0 ]]; then
        error "cmd::timeout: requires timeout seconds and a command"
        return "${FAIL}"
    fi

    # Use platform abstraction for cross-platform timeout
    platform::timeout "${seconds}" "$@"
    local rc=$?

    if [[ "${rc}" -eq 0 ]]; then
        pass "Completed within ${seconds}s: $*"
        return "${PASS}"
    elif [[ "${rc}" -eq 124 ]]; then
        fail "Timed out after ${seconds}s: $*"
        return "${FAIL}"
    fi

    fail "Command failed (${rc}): $*"
    return "${FAIL}"
}

###############################################################################
# cmd::get_exit_code
#------------------------------------------------------------------------------
# Purpose  : Print the exit code of the last command.
# Usage    : cmd::get_exit_code
# Returns  : PASS (0) always
# Outputs  : Exit code of previous command
###############################################################################
function cmd::get_exit_code() {
    printf '%s\n' "$?"
    return "${PASS}"
}

###############################################################################
# cmd::parallel
#------------------------------------------------------------------------------
# Purpose  : Run multiple commands in parallel and wait for all to complete.
# Usage    : cmd::parallel "cmd1 arg1" "cmd2 arg2"
#            cmd::parallel_array cmd1_array cmd2_array  # Use for complex args
# Arguments:
#   $@ : Commands to run in parallel (required)
# Returns  : PASS (0) if all commands succeed, FAIL (1) otherwise
# Notes    : Each argument is executed as a separate command. For commands
#            with complex arguments (spaces, quotes), use cmd::parallel_array.
# Requires:
#   Functions: debug, pass, fail, error
###############################################################################
function cmd::parallel() {
    if [[ $# -eq 0 ]]; then
        error "cmd::parallel: requires commands to run"
        return "${FAIL}"
    fi

    local pids=()
    local cmd rc=0

    for cmd in "$@"; do
        # Use read to safely split the command string into an array
        local -a cmd_parts
        read -ra cmd_parts <<< "${cmd}"
        ("${cmd_parts[@]}") &
        pids+=("$!")
        debug "Started PID ${pids[-1]}: ${cmd}"
    done

    for pid in "${pids[@]}"; do
        wait "${pid}" || rc=1
    done

    if [[ "${rc}" -eq 0 ]]; then
        pass "All parallel commands succeeded"
        return "${PASS}"
    fi

    fail "One or more parallel commands failed"
    return "${FAIL}"
}

###############################################################################
# cmd::parallel_array
#------------------------------------------------------------------------------
# Purpose  : Run multiple commands in parallel using array references.
# Usage    : local -a cmd1=(git clone "$repo1" "$dest1")
#            local -a cmd2=(git clone "$repo2" "$dest2")
#            cmd::parallel_array cmd1 cmd2
# Arguments:
#   $@ : Names of array variables containing commands (required)
# Returns  : PASS (0) if all commands succeed, FAIL (1) otherwise
# Notes    : Use this for commands with complex arguments containing spaces.
# Requires:
#   Functions: debug, pass, fail, error
###############################################################################
function cmd::parallel_array() {
    if [[ $# -eq 0 ]]; then
        error "cmd::parallel_array: requires array names"
        return "${FAIL}"
    fi

    local pids=()
    local array_name rc=0

    for array_name in "$@"; do
        # Use nameref to access the array
        local -n cmd_ref="${array_name}"
        ("${cmd_ref[@]}") &
        pids+=("$!")
        debug "Started PID ${pids[-1]}: ${cmd_ref[*]}"
    done

    for pid in "${pids[@]}"; do
        wait "${pid}" || rc=1
    done

    if [[ "${rc}" -eq 0 ]]; then
        pass "All parallel commands succeeded"
        return "${PASS}"
    fi

    fail "One or more parallel commands failed"
    return "${FAIL}"
}

###############################################################################
# cmd::retry
#------------------------------------------------------------------------------
# Purpose  : Retry a command multiple times with delay intervals.
# Usage    : cmd::retry 3 5 curl -f https://example.com
# Arguments:
#   $1 : Number of attempts (required)
#   $2 : Delay between attempts in seconds (required)
#   $@ : Command and arguments to execute (required)
# Returns  : PASS (0) if command eventually succeeds, FAIL (1) if all fail
# Requires:
#   Functions: warn, pass, fail, error
###############################################################################
function cmd::retry() {
    local attempts="${1:-}"
    local delay="${2:-}"
    shift 2 || true

    if [[ -z "${attempts}" || -z "${delay}" || $# -eq 0 ]]; then
        error "cmd::retry: usage: <attempts> <delay> <command...>"
        return "${FAIL}"
    fi

    local count=1
    until "$@"; do
        if ((count >= attempts)); then
            fail "Command failed after ${attempts} attempts: $*"
            return "${FAIL}"
        fi

        warn "Attempt ${count} failed; retrying in ${delay}s..."
        sleep "${delay}"
        ((count++))
    done

    pass "Command succeeded after ${count} attempt(s)"
    return "${PASS}"
}

###############################################################################
# cmd::sudo_available
#------------------------------------------------------------------------------
# Purpose  : Determine whether sudo is installed and functional.
# Usage    : if cmd::sudo_available; then ...
# Returns  : PASS (0) if sudo is usable, FAIL (1) otherwise
# Requires:
#   Functions: cmd::exists
###############################################################################
function cmd::sudo_available() {
    if cmd::exists sudo && sudo -v > /dev/null 2>&1; then
        return "${PASS}"
    fi
    return "${FAIL}"
}

###############################################################################
# cmd::ensure_sudo_cached
#------------------------------------------------------------------------------
# Purpose  : Ensure sudo credentials are cached (macOS/Linux compatible)
# Usage    : cmd::ensure_sudo_cached
# Returns  : PASS if sudo available and cached, FAIL otherwise
###############################################################################
function cmd::ensure_sudo_cached() {
    if ! cmd::sudo_available; then
        return "${FAIL}"
    fi

    # macOS requires explicit validation
    if os::is_macos; then
        sudo -v 2> /dev/null || return "${FAIL}"
    fi

    return "${PASS}"
}

###############################################################################
# cmd::elevate
#------------------------------------------------------------------------------
# Purpose  : Run a command with elevated privileges (sudo or root).
# Usage    : cmd::elevate apt update
# Arguments:
#   $@ : Command and arguments to execute (required)
# Returns  : PASS (0) if command succeeds, FAIL (1) otherwise
# Requires:
#   Functions: is_root (from util.sh), cmd::sudo_available, cmd::run,
#              info, pass, fail, error
###############################################################################
function cmd::elevate() {
    if [[ $# -eq 0 ]]; then
        error "cmd::elevate: requires a command"
        return "${FAIL}"
    fi

    if os::is_root; then
        cmd::run "$@"
        return $?
    fi

    if cmd::sudo_available; then
        info "Using sudo for elevated execution"
        sudo "$@"
        local rc=$?
        if [[ "${rc}" -eq 0 ]]; then
            pass "Elevated success: $*"
            return "${PASS}"
        fi
        fail "Elevated command failed (${rc}): $*"
        return "${FAIL}"
    fi

    error "cmd::elevate: not root and sudo unavailable"
    return "${FAIL}"
}

#===============================================================================
# Tool Availability and Installation
#===============================================================================

###############################################################################
# cmd::ensure
#------------------------------------------------------------------------------
# Purpose  : Ensure a tool exists; if not, attempt to install via apt or brew.
# Usage    : cmd::ensure "curl"
#            cmd::ensure "curl" "curl" "curl"  # tool, apt_pkg, brew_pkg
# Arguments:
#   $1 : Tool name (executable to check for, required)
#   $2 : apt package name (optional, defaults to $1)
#   $3 : brew formula name (optional, defaults to $1)
# Returns  : PASS (0) on success, FAIL (1) on failure
# Exit codes:
#   0 : Tool is available (already installed or successfully installed)
#   1 : Installation failed
#   2 : Bad usage (no tool name provided)
# Requires:
#   Functions: cmd::exists, apt::is_available, apt::install,
#              brew::is_available, brew::install
###############################################################################
function cmd::ensure() {
    local tool="${1:-}"
    local apt_pkg="${2:-${tool}}"
    local brew_pkg="${3:-${tool}}"

    if [[ -z "${tool}" ]]; then
        error "cmd::ensure: tool name is required"
        return 2
    fi

    # Check if already installed
    if cmd::exists "${tool}"; then
        debug "Tool already present: ${tool}"
        return "${PASS}"
    fi

    info "Tool missing: ${tool} (attempting install)"

    # Try apt first (Linux)
    if declare -F apt::is_available > /dev/null 2>&1 && apt::is_available; then
        if declare -F apt::install > /dev/null 2>&1; then
            if apt::install "${apt_pkg}"; then
                # Verify installation
                if cmd::exists "${tool}"; then
                    pass "Installed via apt: ${apt_pkg}"
                    return "${PASS}"
                fi
            fi
        else
            warn "apt available but apt::install not loaded"
        fi
    fi

    # Try brew (macOS or Linux with Homebrew)
    if declare -F brew::is_available > /dev/null 2>&1 && brew::is_available; then
        if declare -F brew::install > /dev/null 2>&1; then
            if brew::install "${brew_pkg}"; then
                # Verify installation
                if cmd::exists "${tool}"; then
                    pass "Installed via brew: ${brew_pkg}"
                    return "${PASS}"
                fi
            fi
        else
            warn "brew available but brew::install not loaded"
        fi
    fi

    # Check if we succeeded despite warnings
    if cmd::exists "${tool}"; then
        pass "Tool now available: ${tool}"
        return "${PASS}"
    fi

    fail "Failed to install ${tool} (no supported package manager or install failed)"
    return "${FAIL}"
}

###############################################################################
# cmd::ensure_all
#------------------------------------------------------------------------------
# Purpose  : Ensure multiple tools exist, installing any that are missing.
# Usage    : cmd::ensure_all "curl" "wget" "git"
# Arguments:
#   $@ : Tool names to ensure are installed
# Returns  : PASS (0) if all tools available, FAIL (1) if any failed
###############################################################################
function cmd::ensure_all() {
    if [[ $# -eq 0 ]]; then
        error "cmd::ensure_all: requires at least one tool name"
        return "${FAIL}"
    fi

    local tool
    local overall_status="${PASS}"
    local failed_count=0

    for tool in "$@"; do
        if ! cmd::ensure "${tool}"; then
            ((failed_count++))
            overall_status="${FAIL}"
        fi
    done

    if [[ ${failed_count} -gt 0 ]]; then
        fail "Failed to ensure ${failed_count} tool(s)"
    else
        pass "All ${#@} tool(s) available"
    fi

    return "${overall_status}"
}

###############################################################################
# cmd::install_package
#------------------------------------------------------------------------------
# Purpose  : Generic package install dispatcher by OS.
# Usage    : cmd::install_package "package_name"
# Arguments:
#   $1 : Package name (required)
# Returns  : PASS (0) on success, FAIL (1) on failure
# Requires:
#   Functions: os::is_linux, os::is_macos, apt::is_available, apt::install,
#              brew::is_available, brew::install
###############################################################################
function cmd::install_package() {
    local package="${1:-}"

    if [[ -z "${package}" ]]; then
        error "cmd::install_package: package name is required"
        return "${FAIL}"
    fi

    info "Installing package: ${package}"

    # Try to detect OS and use appropriate package manager
    if declare -F os::is_linux > /dev/null 2>&1 && os::is_linux; then
        if declare -F apt::is_available > /dev/null 2>&1 && apt::is_available; then
            if declare -F apt::install > /dev/null 2>&1; then
                apt::install "${package}"
                return $?
            fi
        fi
        fail "No supported package manager for Linux (apt not available)"
        return "${FAIL}"

    elif declare -F os::is_macos > /dev/null 2>&1 && os::is_macos; then
        if declare -F brew::is_available > /dev/null 2>&1 && brew::is_available; then
            if declare -F brew::install > /dev/null 2>&1; then
                brew::install "${package}"
                return $?
            fi
        fi
        fail "No supported package manager for macOS (brew not available)"
        return "${FAIL}"
    fi

    fail "Unsupported platform or no package manager available"
    return "${FAIL}"
}

#===============================================================================
# Test Harness
#===============================================================================

###############################################################################
# cmd::test
#------------------------------------------------------------------------------
# Purpose  : Execute a command and verify its exit code matches expected.
# Usage    : cmd::test 0 curl --version
#            cmd::test 1 false
# Arguments:
#   $1 : Expected exit code (required)
#   $@ : Command and arguments to execute (required)
# Returns  : PASS (0) if exit code matches, FAIL (1) otherwise
# Notes    : Command runs in current shell environment. First argument is
#            the expected exit code, remaining arguments form the command.
###############################################################################
function cmd::test() {
    local expected_code="${1:-}"
    shift || true

    if [[ -z "${expected_code}" ]] || [[ $# -eq 0 ]]; then
        error "cmd::test: usage: <expected_code> <command...>"
        return "${FAIL}"
    fi

    debug "Testing command: $* (expecting exit ${expected_code})"

    # Execute command and capture exit code
    local output
    output=$("$@" 2>&1)
    local actual_code=$?

    if [[ "${actual_code}" -eq "${expected_code}" ]]; then
        debug "Command test passed: exit ${actual_code} == ${expected_code}"
        return "${PASS}"
    fi

    debug "Command test failed: exit ${actual_code} != ${expected_code}"
    return "${FAIL}"
}

###############################################################################
# cmd::test_tool
#------------------------------------------------------------------------------
# Purpose  : Test if a tool is installed and functioning by running a command.
# Usage    : cmd::test_tool "curl" 0 curl --version
#            cmd::test_tool "myapp" 0 myapp --check
# Arguments:
#   $1 : Tool name (for logging, required)
#   $2 : Expected exit code (required)
#   $@ : Test command and arguments (required)
# Returns  : PASS (0) if test passes, FAIL (1) otherwise
###############################################################################
function cmd::test_tool() {
    local tool_name="${1:-}"
    local expected_code="${2:-0}"
    shift 2 || true

    if [[ -z "${tool_name}" ]] || [[ $# -eq 0 ]]; then
        error "cmd::test_tool: usage: <tool_name> <expected_code> <command...>"
        return "${FAIL}"
    fi

    if cmd::test "${expected_code}" "$@"; then
        pass "[${tool_name}] test passed"
        return "${PASS}"
    fi

    fail "[${tool_name}] test failed"
    return "${FAIL}"
}

###############################################################################
# cmd::test_batch
#------------------------------------------------------------------------------
# Purpose  : Run multiple tool tests from an associative array.
# Usage    : declare -A TESTS=([curl]="curl --version" [git]="git --version")
#            cmd::test_batch "TESTS"
# Arguments:
#   $1 : Name of associative array mapping tool -> test command string
# Returns  : PASS (0) if all tests pass, FAIL (1) if any fail
# Notes    : Command strings are split on whitespace. For complex commands,
#            use cmd::test_tool directly with proper arrays.
###############################################################################
function cmd::test_batch() {
    local array_name="${1:-}"

    if [[ -z "${array_name}" ]]; then
        error "cmd::test_batch: requires array name"
        return "${FAIL}"
    fi

    # Use nameref for associative array access
    declare -n tests_ref="${array_name}" 2> /dev/null || {
        error "cmd::test_batch: array not defined: ${array_name}"
        return "${FAIL}"
    }

    local tool command
    local total=0 passed=0 failed=0

    info "Running ${#tests_ref[@]} tool test(s)..."

    for tool in "${!tests_ref[@]}"; do
        command="${tests_ref[${tool}]}"
        ((total++))

        # Split command string into array
        local -a cmd_parts
        read -ra cmd_parts <<< "${command}"

        if cmd::test_tool "${tool}" 0 "${cmd_parts[@]}"; then
            ((passed++))
        else
            ((failed++))
        fi
    done

    info "Test Summary: ${total} total, ${passed} passed, ${failed} failed"

    if [[ ${failed} -eq 0 ]]; then
        pass "All tool tests passed"
        return "${PASS}"
    fi

    fail "${failed} tool test(s) failed"
    return "${FAIL}"
}

#===============================================================================
# Self-Test
#===============================================================================

###############################################################################
# cmd::self_test
#------------------------------------------------------------------------------
# Purpose  : Run basic self-tests for util_cmd.sh functionality.
# Usage    : cmd::self_test
# Returns  : PASS (0) if all tests pass, FAIL (1) if failures occur
# Requires:
#   Functions: cmd::exists, cmd::run, cmd::run_silent, cmd::test, info, pass, warn, fail
###############################################################################
function cmd::self_test() {
    info "Running util_cmd.sh self-test..."

    local status="${PASS}"

    # Test 1: cmd::exists
    if ! cmd::exists "bash"; then
        fail "cmd::exists failed for bash"
        status="${FAIL}"
    fi

    # Test 2: cmd::run
    if ! cmd::run true > /dev/null 2>&1; then
        fail "cmd::run failed on true"
        status="${FAIL}"
    fi

    # Test 3: cmd::run_silent
    if ! cmd::run_silent true; then
        fail "cmd::run_silent failed on true"
        status="${FAIL}"
    fi

    # Test 4: cmd::test (new signature: expected_code command...)
    if ! cmd::test 0 true; then
        fail "cmd::test failed for 'true' with exit 0"
        status="${FAIL}"
    fi

    if ! cmd::test 1 false; then
        fail "cmd::test failed for 'false' with exit 1"
        status="${FAIL}"
    fi

    # Test 5: cmd::test_tool (new signature: tool_name expected_code command...)
    if ! cmd::test_tool "bash" 0 bash --version > /dev/null 2>&1; then
        fail "cmd::test_tool failed for bash"
        status="${FAIL}"
    fi

    if [[ "${status}" -eq "${PASS}" ]]; then
        pass "util_cmd.sh self-test passed"
    else
        fail "util_cmd.sh self-test failed"
    fi

    return "${status}"
}
