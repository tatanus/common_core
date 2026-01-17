#!/usr/bin/env bash
###############################################################################
# NAME         : util_tools.sh
# DESCRIPTION  : Pentest toolkit installation helpers. Provides functions for
#                installing tools from Git repositories, managing tool aliases,
#                creating Python virtual environments for tools, and running
#                tool installation test suites.
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-12-26
###############################################################################
# EDIT HISTORY:
# DATE        | EDITED BY      | DESCRIPTION
# ------------|----------------|-----------------------------------------------
# 2025-12-26  | Adam Compton   | Initial creation - migrated from utils_tools.sh
#             |                | with style guide compliance and namespacing
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Library Guard
#===============================================================================
if [[ -n "${UTIL_TOOLS_SH_LOADED:-}" ]]; then
    if (return 0 2> /dev/null); then
        return 0
    fi
else
    UTIL_TOOLS_SH_LOADED=1
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

# Configuration variables (should be set by consuming scripts)
: "${TOOLS_DIR:=}"
: "${TOOLS_ALIAS_FILE:=}"
: "${PYTHON:=python3}"

# Tool installation tracking
declare -gA TOOLS_INSTALL_STATUS=()

#===============================================================================
# Internal Helpers
#===============================================================================

###############################################################################
# tools::_validate_env
#------------------------------------------------------------------------------
# Purpose  : Validate that required environment variables are set
# Usage    : tools::_validate_env
# Returns  : PASS if valid, FAIL otherwise
###############################################################################
function tools::_validate_env() {
    local valid="${PASS}"

    if [[ -z "${TOOLS_DIR:-}" ]]; then
        error "TOOLS_DIR is not set"
        valid="${FAIL}"
    elif [[ ! -d "${TOOLS_DIR}" ]]; then
        warn "TOOLS_DIR does not exist: ${TOOLS_DIR}"
    fi

    return "${valid}"
}

###############################################################################
# tools::_validate_alias_file
#------------------------------------------------------------------------------
# Purpose  : Validate that the alias file is configured and writable
# Usage    : tools::_validate_alias_file
# Returns  : PASS if valid, FAIL otherwise
###############################################################################
function tools::_validate_alias_file() {
    if [[ -z "${TOOLS_ALIAS_FILE:-}" ]]; then
        error "TOOLS_ALIAS_FILE is not set"
        return "${FAIL}"
    fi

    if [[ ! -f "${TOOLS_ALIAS_FILE}" ]]; then
        # Try to create it
        if ! touch "${TOOLS_ALIAS_FILE}" 2> /dev/null; then
            error "Cannot create TOOLS_ALIAS_FILE: ${TOOLS_ALIAS_FILE}"
            return "${FAIL}"
        fi
    fi

    if [[ ! -w "${TOOLS_ALIAS_FILE}" ]]; then
        error "TOOLS_ALIAS_FILE is not writable: ${TOOLS_ALIAS_FILE}"
        return "${FAIL}"
    fi

    return "${PASS}"
}

#===============================================================================
# Alias/Function Management
#===============================================================================

###############################################################################
# tools::add_function
#------------------------------------------------------------------------------
# Purpose  : Add a wrapper function to the tools alias file
# Usage    : tools::add_function "tool_name" "relative/path/to/tool"
# Arguments:
#   $1 : Function name to create (required)
#   $2 : Tool path relative to TOOLS_DIR (required)
# Returns  : PASS on success, FAIL on failure
# Notes    : Creates a function that calls run_tools_command with the tool path
###############################################################################
function tools::add_function() {
    local function_name="${1:-}"
    local tool_path="${2:-}"

    if [[ -z "${function_name}" || -z "${tool_path}" ]]; then
        error "Usage: tools::add_function <function_name> <tool_path>"
        return "${FAIL}"
    fi

    if ! tools::_validate_alias_file; then
        return "${FAIL}"
    fi

    # Check for duplicate
    if grep -qE "^function[[:space:]]+${function_name}[[:space:]]*\(\)[[:space:]]*\{" "${TOOLS_ALIAS_FILE}" 2> /dev/null; then
        warn "Function '${function_name}' already exists in ${TOOLS_ALIAS_FILE}"
        return "${FAIL}"
    fi

    # Append function definition
    {
        printf '\nfunction %s() {\n' "${function_name}"
        # shellcheck disable=SC2016
        printf '    run_tools_command "%s/%s" "$@"\n' '${TOOLS_DIR}' "${tool_path}"
        printf '}\n'
    } >> "${TOOLS_ALIAS_FILE}"

    # Verify it was added
    if grep -qE "^function[[:space:]]+${function_name}[[:space:]]*\(\)[[:space:]]*\{" "${TOOLS_ALIAS_FILE}" 2> /dev/null; then
        pass "Added function: ${function_name}"
        return "${PASS}"
    fi

    fail "Failed to add function: ${function_name}"
    return "${FAIL}"
}

###############################################################################
# tools::remove_function
#------------------------------------------------------------------------------
# Purpose  : Remove a wrapper function from the tools alias file
# Usage    : tools::remove_function "tool_name"
# Arguments:
#   $1 : Function name to remove (required)
# Returns  : PASS on success, FAIL on failure
###############################################################################
function tools::remove_function() {
    local function_name="${1:-}"

    if [[ -z "${function_name}" ]]; then
        error "Usage: tools::remove_function <function_name>"
        return "${FAIL}"
    fi

    if ! tools::_validate_alias_file; then
        return "${FAIL}"
    fi

    # Check if function exists
    if ! grep -qE "^function[[:space:]]+${function_name}[[:space:]]*\(\)[[:space:]]*\{" "${TOOLS_ALIAS_FILE}" 2> /dev/null; then
        warn "Function '${function_name}' not found in ${TOOLS_ALIAS_FILE}"
        return "${FAIL}"
    fi

    # Remove the function block using sed
    # This pattern matches from "function name() {" to the next "}"
    if sed -i.bak -E "/^function[[:space:]]+${function_name}[[:space:]]*\\(\\)[[:space:]]*\\{/,/^\\}/d" "${TOOLS_ALIAS_FILE}"; then
        rm -f "${TOOLS_ALIAS_FILE}.bak"

        # Verify removal
        if ! grep -qE "^function[[:space:]]+${function_name}[[:space:]]*\(\)[[:space:]]*\{" "${TOOLS_ALIAS_FILE}" 2> /dev/null; then
            pass "Removed function: ${function_name}"
            return "${PASS}"
        fi
    fi

    fail "Failed to remove function: ${function_name}"
    return "${FAIL}"
}

###############################################################################
# tools::list_functions
#------------------------------------------------------------------------------
# Purpose  : List all tool functions defined in the alias file
# Usage    : tools::list_functions
# Returns  : Prints function names, one per line
###############################################################################
function tools::list_functions() {
    if ! tools::_validate_alias_file; then
        return "${FAIL}"
    fi

    grep -oE "^function[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*" "${TOOLS_ALIAS_FILE}" 2> /dev/null |
        sed 's/^function[[:space:]]*//' |
        sort -u

    return "${PASS}"
}

#===============================================================================
# Git + Python Tool Installation
#===============================================================================

###############################################################################
# tools::install_git_python
#------------------------------------------------------------------------------
# Purpose  : Clone a Git repo, create venv, install requirements, add alias
# Usage    : tools::install_git_python "tool_name" "git_url" [options...]
# Arguments:
#   $1 : Tool name (entry point command name, required)
#   $2 : Git repository URL (required)
#   $3 : Requirements file path relative to repo (optional)
#   $@ : Additional pip packages to install (optional)
# Returns  : PASS on success, FAIL on failure
# Environment:
#   TOOLS_DIR       : Base directory for tools (required)
#   PYTHON          : Python interpreter to use (default: python3)
#   TOOLS_ALIAS_FILE: File to add wrapper functions to
###############################################################################
function tools::install_git_python() {
    local tool_name="${1:-}"
    local git_url="${2:-}"
    local requirements_file="${3:-}"
    shift 3 2> /dev/null || shift $#
    local -a extra_packages=("$@")

    if [[ -z "${tool_name}" || -z "${git_url}" ]]; then
        error "Usage: tools::install_git_python <tool_name> <git_url> [requirements_file] [extra_packages...]"
        return "${FAIL}"
    fi

    if ! tools::_validate_env; then
        return "${FAIL}"
    fi

    # Extract directory name from git URL
    local dir_name="${git_url##*/}"
    dir_name="${dir_name%.git}"
    local tool_dir="${TOOLS_DIR}/${dir_name}"

    info "Installing ${tool_name} from ${git_url}..."

    # Clone repository
    if declare -F git::clone > /dev/null 2>&1; then
        if ! git::clone "${git_url}" "${tool_dir}"; then
            fail "Failed to clone ${git_url}"
            return "${FAIL}"
        fi
    else
        if ! git clone "${git_url}" "${tool_dir}" 2> /dev/null; then
            fail "Failed to clone ${git_url}"
            return "${FAIL}"
        fi
    fi
    pass "Cloned repository to ${tool_dir}"

    # Change to tool directory
    local orig_dir="${PWD}"
    cd "${tool_dir}" || {
        fail "Failed to enter ${tool_dir}"
        return "${FAIL}"
    }

    # Create virtual environment
    info "Creating virtual environment..."
    if ! "${PYTHON}" -m venv ./venv; then
        fail "Failed to create virtual environment"
        cd "${orig_dir}" || true
        return "${FAIL}"
    fi
    pass "Created virtual environment"

    # Activate venv
    # shellcheck source=/dev/null
    source ./venv/bin/activate || {
        fail "Failed to activate virtual environment"
        cd "${orig_dir}" || true
        return "${FAIL}"
    }

    # Upgrade pip in venv
    "${PYTHON}" -m pip install --upgrade pip > /dev/null 2>&1 || true

    # Install from requirements file if specified
    if [[ -n "${requirements_file}" && -f "${requirements_file}" ]]; then
        info "Installing from ${requirements_file}..."
        if ! "${PYTHON}" -m pip install -r "${requirements_file}" > /dev/null 2>&1; then
            fail "Failed to install requirements from ${requirements_file}"
            deactivate 2> /dev/null || true
            cd "${orig_dir}" || true
            return "${FAIL}"
        fi
        pass "Installed requirements"
    fi

    # Install extra packages
    if [[ ${#extra_packages[@]} -gt 0 ]]; then
        local pkg
        for pkg in "${extra_packages[@]}"; do
            info "Installing ${pkg}..."
            if [[ "${pkg}" == "." ]]; then
                if ! "${PYTHON}" -m pip install . > /dev/null 2>&1; then
                    warn "Failed to install from current directory"
                fi
            else
                if ! "${PYTHON}" -m pip install "${pkg}" > /dev/null 2>&1; then
                    warn "Failed to install ${pkg}"
                fi
            fi
        done
    fi

    # Run setup.py if present
    if [[ -f "setup.py" ]]; then
        info "Running setup.py install..."
        if "${PYTHON}" setup.py install > /dev/null 2>&1; then
            pass "setup.py install completed"
        else
            warn "setup.py install failed (non-fatal)"
        fi
    fi

    # Deactivate venv
    deactivate 2> /dev/null || true

    # Add tool function to alias file
    if [[ -n "${TOOLS_ALIAS_FILE:-}" ]]; then
        tools::add_function "${tool_name}" "${dir_name}/${tool_name}" || true
    fi

    cd "${orig_dir}" || true

    TOOLS_INSTALL_STATUS[${tool_name}]="success"
    pass "${tool_name} installed successfully"
    return "${PASS}"
}

###############################################################################
# tools::install_git_tool
#------------------------------------------------------------------------------
# Purpose  : Clone a Git repo and optionally add alias (no Python venv)
# Usage    : tools::install_git_tool "tool_name" "git_url" ["entry_point"]
# Arguments:
#   $1 : Tool name (required)
#   $2 : Git repository URL (required)
#   $3 : Entry point path relative to repo (optional, defaults to tool_name)
# Returns  : PASS on success, FAIL on failure
###############################################################################
function tools::install_git_tool() {
    local tool_name="${1:-}"
    local git_url="${2:-}"
    local entry_point="${3:-${tool_name}}"

    if [[ -z "${tool_name}" || -z "${git_url}" ]]; then
        error "Usage: tools::install_git_tool <tool_name> <git_url> [entry_point]"
        return "${FAIL}"
    fi

    if ! tools::_validate_env; then
        return "${FAIL}"
    fi

    # Extract directory name from git URL
    local dir_name="${git_url##*/}"
    dir_name="${dir_name%.git}"
    local tool_dir="${TOOLS_DIR}/${dir_name}"

    info "Installing ${tool_name} from ${git_url}..."

    # Clone repository
    if declare -F git::clone > /dev/null 2>&1; then
        if ! git::clone "${git_url}" "${tool_dir}"; then
            fail "Failed to clone ${git_url}"
            return "${FAIL}"
        fi
    else
        if ! git clone "${git_url}" "${tool_dir}" 2> /dev/null; then
            fail "Failed to clone ${git_url}"
            return "${FAIL}"
        fi
    fi

    # Make entry point executable if it exists
    local entry_path="${tool_dir}/${entry_point}"
    if file::exists "${entry_path}"; then
        chmod +x "${entry_path}" 2> /dev/null || true
    fi

    # Add tool function to alias file
    if [[ -n "${TOOLS_ALIAS_FILE:-}" ]]; then
        tools::add_function "${tool_name}" "${dir_name}/${entry_point}" || true
    fi

    TOOLS_INSTALL_STATUS[${tool_name}]="success"
    pass "${tool_name} installed successfully"
    return "${PASS}"
}

#===============================================================================
# Tool Testing
#===============================================================================

###############################################################################
# tools::test
#------------------------------------------------------------------------------
# Purpose  : Test if a tool is installed and working
# Usage    : tools::test "tool_name" "test_command" [expected_exit_code]
# Arguments:
#   $1 : Tool name (for logging, required)
#   $2 : Test command to execute (required)
#   $3 : Expected exit code (optional, default: 0)
# Returns  : PASS if test passes, FAIL otherwise
###############################################################################
function tools::test() {
    local tool_name="${1:-}"
    local test_command="${2:-}"
    local expected_code="${3:-0}"

    if [[ -z "${tool_name}" || -z "${test_command}" ]]; then
        error "Usage: tools::test <tool_name> <test_command> [expected_code]"
        return "${FAIL}"
    fi

    debug "Testing ${tool_name}: ${test_command}"

    # Enable aliases in case tool is aliased
    shopt -s expand_aliases 2> /dev/null || true

    # Execute test command
    # SECURITY: test_command originates from hardcoded TESTS arrays in source
    # code, not from runtime user input. Callers must never pass untrusted input.
    local output
    output=$(eval "${test_command}" 2>&1)
    local actual_code=$?

    if [[ "${actual_code}" -eq "${expected_code}" ]]; then
        pass "[${tool_name}] test passed"
        return "${PASS}"
    fi

    fail "[${tool_name}] test failed (exit ${actual_code}, expected ${expected_code})"
    return "${FAIL}"
}

###############################################################################
# tools::test_batch
#------------------------------------------------------------------------------
# Purpose  : Run multiple tool tests from an associative array
# Usage    : declare -A TESTS=([curl]="curl --version" [git]="git --version")
#            tools::test_batch "TESTS"
# Arguments:
#   $1 : Name of associative array mapping tool -> test command
# Returns  : PASS if all tests pass, FAIL if any fail
###############################################################################
function tools::test_batch() {
    local array_name="${1:-}"

    if [[ -z "${array_name}" ]]; then
        error "tools::test_batch: requires array name"
        return "${FAIL}"
    fi

    # Load alias file if configured
    if [[ -n "${TOOLS_ALIAS_FILE:-}" && -r "${TOOLS_ALIAS_FILE}" ]]; then
        # shellcheck source=/dev/null
        source "${TOOLS_ALIAS_FILE}" 2> /dev/null || true
    fi

    # Use nameref for associative array access
    declare -n tests_ref="${array_name}" 2> /dev/null || {
        error "tools::test_batch: array not defined: ${array_name}"
        return "${FAIL}"
    }

    local tool command
    local total=0 passed=0 failed=0

    info "Running ${#tests_ref[@]} tool test(s)..."

    # Sort keys for consistent output
    local -a sorted_keys=()
    while IFS= read -r key; do
        sorted_keys+=("${key}")
    done < <(printf '%s\n' "${!tests_ref[@]}" | sort -f)

    for tool in "${sorted_keys[@]}"; do
        command="${tests_ref[${tool}]}"
        ((total++))

        if tools::test "${tool}" "${command}"; then
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
# Tool Fixes
#===============================================================================

###############################################################################
# tools::apply_fixes
#------------------------------------------------------------------------------
# Purpose  : Apply fixes for tools from a fixes array
# Usage    : declare -A FIXES=([tool]="fix_command")
#            declare -A TESTS=([tool]="test_command")
#            tools::apply_fixes "FIXES" "TESTS"
# Arguments:
#   $1 : Name of associative array mapping tool -> fix command
#   $2 : Name of associative array mapping tool -> test command
# Returns  : PASS if all fixes succeed, FAIL if any fail
###############################################################################
function tools::apply_fixes() {
    local fixes_array="${1:-}"
    local tests_array="${2:-}"

    if [[ -z "${fixes_array}" ]]; then
        error "tools::apply_fixes: requires fixes array name"
        return "${FAIL}"
    fi

    declare -n fixes_ref="${fixes_array}" 2> /dev/null || {
        error "tools::apply_fixes: fixes array not defined: ${fixes_array}"
        return "${FAIL}"
    }

    declare -n tests_ref="${tests_array}" 2> /dev/null || {
        # Tests array is optional
        tests_ref=()
    }

    local tool fix_cmd test_cmd
    local overall_status="${PASS}"

    for tool in "${!fixes_ref[@]}"; do
        fix_cmd="${fixes_ref[${tool}]}"
        test_cmd="${tests_ref[${tool}]:-}"

        # If test command provided, verify tool is installed first
        if [[ -n "${test_cmd}" ]]; then
            if ! tools::test "${tool}" "${test_cmd}" > /dev/null 2>&1; then
                warn "Tool [${tool}] not installed or failed test; skipping fix"
                continue
            fi
        fi

        info "Applying fix for [${tool}]: ${fix_cmd}"

        # Apply fix (with optional PROXY)
        # SECURITY: fix_cmd originates from hardcoded FIXES arrays in source
        # code, not from runtime user input. Callers must never pass untrusted input.
        if eval "${PROXY:-} ${fix_cmd}"; then
            pass "Fix applied for [${tool}]"
        else
            fail "Fix failed for [${tool}]"
            overall_status="${FAIL}"
        fi
    done

    return "${overall_status}"
}

#===============================================================================
# Utility Functions
#===============================================================================

###############################################################################
# tools::get_install_status
#------------------------------------------------------------------------------
# Purpose  : Get the installation status of a tool
# Usage    : status=$(tools::get_install_status "tool_name")
# Arguments:
#   $1 : Tool name
# Returns  : Prints status (success, failed, or unknown)
###############################################################################
function tools::get_install_status() {
    local tool_name="${1:-}"

    if [[ -z "${tool_name}" ]]; then
        printf '%s\n' "unknown"
        return "${FAIL}"
    fi

    printf '%s\n' "${TOOLS_INSTALL_STATUS[${tool_name}]:-unknown}"
    return "${PASS}"
}

###############################################################################
# tools::list_installed
#------------------------------------------------------------------------------
# Purpose  : List tools that have been installed in this session
# Usage    : tools::list_installed
# Returns  : Prints tool names and statuses
###############################################################################
function tools::list_installed() {
    if [[ ${#TOOLS_INSTALL_STATUS[@]} -eq 0 ]]; then
        info "No tools installed in this session"
        return "${PASS}"
    fi

    printf "Installed Tools:\n"
    local tool status
    for tool in "${!TOOLS_INSTALL_STATUS[@]}"; do
        status="${TOOLS_INSTALL_STATUS[${tool}]}"
        printf "  %-30s %s\n" "${tool}" "${status}"
    done

    return "${PASS}"
}

###############################################################################
# tools::run_command
#------------------------------------------------------------------------------
# Purpose  : Run a tool command (helper for alias wrappers)
# Usage    : tools::run_command "/path/to/tool" [args...]
# Arguments:
#   $1 : Full path to tool
#   $@ : Arguments to pass to tool
# Returns  : Exit code of tool
###############################################################################
function tools::run_command() {
    local tool_path="${1:-}"
    shift || true

    if [[ -z "${tool_path}" ]]; then
        error "tools::run_command: tool path required"
        return "${FAIL}"
    fi

    if [[ ! -x "${tool_path}" ]]; then
        # Check if it's a Python script in a venv
        local tool_dir="${tool_path%/*}"
        local venv_python="${tool_dir}/venv/bin/python"

        if [[ -x "${venv_python}" && -f "${tool_path}" ]]; then
            "${venv_python}" "${tool_path}" "$@"
            return $?
        fi

        error "Tool not executable: ${tool_path}"
        return "${FAIL}"
    fi

    "${tool_path}" "$@"
    return $?
}

# Alias for compatibility with old scripts
function run_tools_command() {
    tools::run_command "$@"
}

#===============================================================================
# Self-Test
#===============================================================================

###############################################################################
# tools::self_test
#------------------------------------------------------------------------------
# Purpose  : Self-test for util_tools.sh functionality
# Usage    : tools::self_test
# Returns  : PASS (0) if all tests pass, FAIL (1) otherwise
###############################################################################
function tools::self_test() {
    info "Running util_tools.sh self-test..."

    local status="${PASS}"

    # Test 1: Validate function existence
    if ! declare -F tools::add_function > /dev/null 2>&1; then
        fail "tools::add_function not defined"
        status="${FAIL}"
    fi

    if ! declare -F tools::test > /dev/null 2>&1; then
        fail "tools::test not defined"
        status="${FAIL}"
    fi

    # Test 2: Test the test function
    if ! tools::test "true" "true" 0 > /dev/null 2>&1; then
        fail "tools::test failed for 'true'"
        status="${FAIL}"
    fi

    # Test 3: Status tracking
    TOOLS_INSTALL_STATUS["test_tool"]="success"
    local test_status
    test_status=$(tools::get_install_status "test_tool")
    if [[ "${test_status}" != "success" ]]; then
        fail "tools::get_install_status failed"
        status="${FAIL}"
    fi
    unset 'TOOLS_INSTALL_STATUS[test_tool]'

    if [[ "${status}" -eq "${PASS}" ]]; then
        pass "util_tools.sh self-test passed"
    else
        fail "util_tools.sh self-test failed"
    fi

    return "${status}"
}
