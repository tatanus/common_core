#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

# =============================================================================
# NAME        : utils_tools.sh
# DESCRIPTION : Tool presence checks and installation helpers (apt/brew), plus
#               test harness utilities for verifying tool installs.
# AUTHOR      : Adam Compton
# DATE CREATED: 2024-12-10 12:29:41
# =============================================================================
# EDIT HISTORY:
# DATE                 | EDITED BY    | DESCRIPTION OF CHANGE
# ---------------------|--------------|----------------------------------------
# 2024-12-10 12:29:41  | Adam Compton | Initial creation.
# =============================================================================

#----------------------------------------------------------------------------
# Guard to prevent multiple sourcing (portable; works on macOS Bash 3.2)
#----------------------------------------------------------------------------
if [[ -n "${UTILS_TOOLS_SH_LOADED:-}" ]]; then
    if ( return 0 2> /dev/null); then
        return 0
    else
        : # executed as a script; continue
    fi
else
    UTILS_TOOLS_SH_LOADED=1
fi

# -----------------------------------------------------------------------------
# Fallback and Defaults
# -----------------------------------------------------------------------------
# Provide fallback for logging (only if caller hasn't provided logger functions)
if ! declare -f info   > /dev/null 2>&1; then function info()  { printf '[ * INFO  ] %s\n'  "${1-}"; };     fi
if ! declare -f warn   > /dev/null 2>&1; then function warn()  { printf '[ ! WARN  ] %s\n'  "${1-}" >&2; }; fi
if ! declare -f error  > /dev/null 2>&1; then function error() { printf '[ - ERROR ] %s\n' "${1-}" >&2; };  fi
if ! declare -f debug  > /dev/null 2>&1; then function debug() { printf '[ # DEBUG ] %s\n' "${1-}"; };      fi
if ! declare -f vdebug > /dev/null 2>&1; then function vdebug() { printf '[ # V-DBG ] %s\n' "${1-}"; };     fi
if ! declare -f pass   > /dev/null 2>&1; then function pass()  { printf '[ + PASS  ] %s\n'  "${1-}"; };     fi
if ! declare -f fail   > /dev/null 2>&1; then function fail()  { printf '[ ! FAIL  ] %s\n'  "${1-}" >&2; }; fi

# Provide sane defaults if not defined elsewhere
PASS="${PASS:-0}"
FAIL="${FAIL:-1}"
readonly PASS FAIL

# Provide fallback for _popd and _pushd
if ! declare -f _pushd > /dev/null 2>&1; then
    function _pushd() {
        builtin pushd "$@" > /dev/null 2>&1 || {
            error "pushd failed: $*"
            return 1
        }
    }
fi
if ! declare -f _popd > /dev/null 2>&1; then
    function _popd() {
        builtin popd "$@" > /dev/null 2>&1 || {
            error "popd failed: $*"
            return 1
        }
    }
fi

# -----------------------------------------------------------------------------
# Utility predicates
# -----------------------------------------------------------------------------
# Returns 0 if apt-get is available.
function _has_apt()  { command -v apt-get > /dev/null 2>&1; }
# Returns 0 if Homebrew is available.
function _has_brew() { command -v brew    > /dev/null 2>&1; }

###############################################################################
# tool_is_installed
#------------------
# Check if a tool (executable) is in PATH.
#
# Args:
#   $1 - tool name (e.g., "curl")
#
# Returns:
#   0 if found; 1 if missing; 2 on bad usage.
###############################################################################
function tool_is_installed() {
    local tool="${1:-}"
    if [[ -z "${tool}" ]]; then
        error "tool_is_installed: tool name is required"
        return 2
    fi
    if command -v -- "${tool}" > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

###############################################################################
# ensure_tool
#------------
# Ensure a tool exists; if not, attempt to install via apt or brew.
#
# Usage:
#   ensure_tool <tool> [apt_pkg] [brew_pkg]
#
# Args:
#   $1 - tool name (executable to check for)
#   $2 - apt package name (optional, defaults to $1)
#   $3 - brew formula name (optional, defaults to $1)
#
# Returns:
#   0 on success; 1 on failure; 2 on bad usage.
###############################################################################
function ensure_tool() {
    local tool="${1:-}"
    local apt_pkg="${2:-${tool}}"
    local brew_pkg="${3:-${tool}}"

    if [[ -z "${tool}" ]]; then
        error "ensure_tool: tool name is required"
        return 2
    fi

    if tool_is_installed "${tool}"; then
        info "Tool present: ${tool}"
        return 0
    fi

    info "Tool missing: ${tool} (will attempt install)"

    if _has_apt; then
        if command -v apt_install_missing > /dev/null 2>&1; then
            if apt_install_missing "${apt_pkg}"; then
                pass "Installed via apt: ${apt_pkg}"
            else
                error "apt install failed: ${apt_pkg}"
                return 1
            fi
        else
            error "apt helpers not loaded (lib/utils_apt.sh)."
            return 1
        fi
    elif _has_brew; then
        if command -v brew_install_missing > /dev/null 2>&1; then
            if brew_install_missing "${brew_pkg}"; then
                pass "Installed via brew: ${brew_pkg}"
            else
                error "brew install failed: ${brew_pkg}"
                return 1
            fi
        else
            error "brew helpers not loaded (lib/utils_brew.sh)."
            return 1
        fi
    else
        error "No supported package manager detected (need apt or brew) to install ${tool}"
        return 1
    fi

    # Re-check and report
    if tool_is_installed "${tool}"; then
        return 0
    fi
    error "Tool still not available after install: ${tool}"
    return 1
}

# =============================================================================
# INSTALL/ALIAS HELPERS
# =============================================================================

###############################################################################
# _add_tool_function
#-------------------
# Append a small wrapper function into ${PENTEST_ALIAS_FILE} that shims to
# "${TOOLS_DIR}/${tool_path}" with any provided arguments.
#
# Args:
#   $1 - function_name to add (identifier)
#   $2 - tool_path under ${TOOLS_DIR}
#
# Returns:
#   ${PASS} on success; ${FAIL} on failure.
###############################################################################
function _add_tool_function() {
    local function_name="${1:-}"
    local tool_path="${2:-}"

    if [[ -z "${PENTEST_ALIAS_FILE:-}" ]]; then
        fail "PENTEST_ALIAS_FILE is not set. Cannot add alias."
        return "${FAIL}"
    fi
    if [[ ! -w "${PENTEST_ALIAS_FILE}" ]]; then
        fail "ALIAS_FILE (${PENTEST_ALIAS_FILE}) is not writable."
        return "${FAIL}"
    fi
    if [[ -z "${function_name}" || -z "${tool_path}" ]]; then
        fail "Usage: _add_tool_function <function_name> <tool_path>"
        return "${FAIL}"
    fi

    # Avoid duplicate function definitions.
    if grep -qE "^function[[:space:]]+${function_name}[[:space:]]*\(\)[[:space:]]*\{" "${PENTEST_ALIAS_FILE}"; then
        fail "Function '${function_name}' already exists in ${PENTEST_ALIAS_FILE}."
        return "${FAIL}"
    fi

    {
        printf 'function %s() {\n' "${function_name}"
        printf '    run_tools_command "%s/%s" "$@"\n' "${TOOLS_DIR}" "${tool_path}"
        printf '}\n'
    } >> "${PENTEST_ALIAS_FILE}"

    if grep -qE "^function[[:space:]]+${function_name}[[:space:]]*\(\)[[:space:]]*\{" "${PENTEST_ALIAS_FILE}"; then
        pass "Added alias: ${function_name}"
        return "${PASS}"
    fi
    fail "Failed to add alias: ${function_name}"
    return "${FAIL}"
}

###############################################################################
# _del_tool_function
#-------------------
# Remove a wrapper function from ${PENTEST_ALIAS_FILE}.
#
# Args:
#   $1 - function_name to remove.
#
# Returns:
#   ${PASS} on success; ${FAIL} on failure.
###############################################################################
function _del_tool_function() {
    local function_name="${1:-}"

    if [[ -z "${function_name}" ]]; then
        fail "Usage: _del_tool_function <function_name>"
        return "${FAIL}"
    fi
    if [[ -z "${PENTEST_ALIAS_FILE:-}" ]]; then
        fail "PENTEST_ALIAS_FILE is not set. Cannot remove alias."
        return "${FAIL}"
    fi
    if [[ ! -w "${PENTEST_ALIAS_FILE}" ]]; then
        fail "ALIAS_FILE (${PENTEST_ALIAS_FILE}) is not writable."
        return "${FAIL}"
    fi
    if ! grep -qE "^function[[:space:]]+${function_name}[[:space:]]*\(\)[[:space:]]*\{" "${PENTEST_ALIAS_FILE}"; then
        fail "Function '${function_name}' not found in '${PENTEST_ALIAS_FILE}'."
        return "${FAIL}"
    fi

    # Remove the function block (from its "function name() {" line to the matching "}")
    # macOS and GNU sed compatible: -E + -i.bak
    sed -i.bak -E "/^function[[:space:]]+${function_name}[[:space:]]*\\(\\)[[:space:]]*\\{/{
        N
        :loop
        /\\}/! {N; b loop}
        d
    }" "${PENTEST_ALIAS_FILE}"

    if grep -qE "^function[[:space:]]+${function_name}[[:space:]]*\(\)[[:space:]]*\{" "${PENTEST_ALIAS_FILE}"; then
        fail "Failed to remove function '${function_name}' from '${PENTEST_ALIAS_FILE}'."
        return "${FAIL}"
    fi

    info "Function '${function_name}' successfully removed from '${PENTEST_ALIAS_FILE}'."
    return "${PASS}"
}

###############################################################################
# _install_git_python_tool
#-------------------------
# Clone a Git repo into ${TOOLS_DIR}, create a venv, install requirements and
# optional extras, then add a wrapper function into ${PENTEST_ALIAS_FILE}.
#
# Args:
#   $1 - TOOL_NAME          (installed entry point name)
#   $2 - GIT_URL            (repo to clone)
#   $3 - INSTALL_IMPACKET   ("true" to install Impacket via helper)
#   $4 - REQUIREMENTS_FILE  (path relative to repo root)
#   $@ - additional pip install targets
#
# Returns:
#   ${PASS} on success; ${FAIL} on failure.
###############################################################################
function _install_git_python_tool() {
    local tool_name="${1:-}"
    local git_url="${2:-}"
    local install_impacket="${3:-}"
    local requirements_file="${4:-}"
    shift 4 || true
    local pip_installs=("$@")

    if [[ -z "${tool_name}" || -z "${git_url}" ]]; then
        fail "_install_git_python_tool: need <tool_name> <git_url>"
        return "${FAIL}"
    fi
    if [[ -z "${TOOLS_DIR:-}" ]]; then
        fail "TOOLS_DIR is not set."
        return "${FAIL}"
    fi
    if [[ -z "${PYTHON:-}" ]]; then
        fail "PYTHON is not set (path to python interpreter)."
        return "${FAIL}"
    fi

    local directory_name="${git_url}"
    [[ "${directory_name}" == *.git ]] && directory_name="${directory_name%.git}"
    directory_name="${directory_name##*/}"

    if ! command -v _git_clone > /dev/null 2>&1; then
        fail "_git_clone helper is missing (lib/utils_git.sh)."
        return "${FAIL}"
    fi
    if ! _git_clone "${git_url}"; then
        fail "Failed to clone repository from ${git_url}."
        return "${FAIL}"
    fi
    pass "git cloned"

    __pushd "${TOOLS_DIR}/${directory_name}" || return "${FAIL}"

    if ! "${PYTHON}" -m venv ./venv; then
        fail "Failed to create virtual environment."
        __popd || true
        return "${FAIL}"
    fi
    pass "Created virtual env"

    # shellcheck source=/dev/null
    . ./venv/bin/activate

    if [[ "${install_impacket}" == "true" ]]; then
        if command -v Install_Impacket > /dev/null 2>&1; then
            Install_Impacket || {
                fail "Failed to install Impacket."
                deactivate || true
                __popd || true
                return "${FAIL}"
            }
        else
            warn "Install_Impacket helper not available; skipping Impacket install."
        fi
    fi

    if [[ -n "${requirements_file}" && -f "${requirements_file}" ]]; then
        if ! _pip_install_requirements "${requirements_file}" ""; then
            fail "Failed to install requirements from ${requirements_file}."
            deactivate || true
            __popd || true
            return "${FAIL}"
        fi
    fi

    if [[ ${#pip_installs[@]} -gt 0 ]]; then
        local package
        for package in "${pip_installs[@]}"; do
            if [[ "${package}" == "." ]]; then
                if ! _pip_install "${TOOLS_DIR}/${directory_name}/." ""; then
                    fail "Failed to install package: ${TOOLS_DIR}/${directory_name}/."
                    deactivate || true
                    __popd || true
                    fail "Failed to install ${directory_name}"
                    return "${FAIL}"
                fi
            else
                if ! _pip_install "${package}" ""; then
                    fail "Failed to install package: ${package}"
                    deactivate || true
                    __popd || true
                    fail "Failed to install ${directory_name}"
                    return "${FAIL}"
                fi
            fi
            info "Installed package ${package}"
        done
    fi

    if [[ -f "setup.py" ]]; then
        if ! "${PYTHON}" setup.py install; then
            fail "setup.py install failed."
            deactivate || true
            __popd || true
            return "${FAIL}"
        fi
        pass "setup.py install completed"
    fi

    deactivate || true
    _add_tool_function "${tool_name}" "${directory_name}/${tool_name}"
    __popd || true
    pass "${directory_name} installed and virtual environment set up successfully."
    return "${PASS}"
}

###############################################################################
# run_app_test
#-------------
# Execute an app command and check its exit code against an expected value.
#
# Args:
#   $1 - app name (for logs)
#   $2 - app command string (will be eval'd)
#   $3 - expected exit code (default: 0)
#
# Returns:
#   0 on expected success; otherwise the command's exit status.
#
# NOTE: Uses "eval" to allow complex command strings. Prefer passing exact
#       commands without user input to avoid injection risks.
###############################################################################
function run_app_test() {
    shopt -s expand_aliases

    local app_name="${1:-}"
    local app_command="${2:-}"
    local success_exit_code="${3:-0}"

    if [[ -z "${app_name}" || -z "${app_command}" ]]; then
        return 2
    fi

    local output
    output="$(eval "${app_command}" 2>&1)"
    local status=$?

    if [[ "${status}" -eq "${success_exit_code}" ]]; then
        return 0
    fi
    return "${status}"
}

###############################################################################
# app_test
#---------
# Wrapper around run_app_test that logs PASS/FAIL with context.
###############################################################################
function app_test() {
    local app_name="${1:-}"
    local app_command="${2:-}"
    local success_exit_code="${3:-0}"

    if run_app_test "${app_name}" "${app_command}" "${success_exit_code}"; then
        pass "SUCCESS: [${app_name}] - [${app_command}]"
        return 0
    fi
    local status=$?
    fail "FAILED : [${app_name}] - [${app_command}] - Exit Status [${status}]"
    return "${status}"
}

###############################################################################
# _test_tool_installs
#--------------------
# Load alias wrappers and module tests, then run APP_TESTS in sorted order.
#
# Requirements:
#   - PENTEST_ALIAS_FILE readable (optional)
#   - "tools/modules" directory with *.sh files (optional)
#   - APP_TESTS array mapping app_name -> command (associative or indexed)
#
# Returns:
#   0 if all tests passed; 1 if some failed.
###############################################################################
function _test_tool_installs() {
    # Optional: load aliases, if provided
    if [[ -n "${PENTEST_ALIAS_FILE:-}" && -r "${PENTEST_ALIAS_FILE}" ]]; then
        # shellcheck source=/dev/null
        . "${PENTEST_ALIAS_FILE}"
    fi

    local modules_dir="tools/modules"
    if [[ -d "${modules_dir}" ]]; then
        local module
        for module in "${modules_dir}"/*.sh; do
            [[ -f "${module}" ]] || continue
            # shellcheck source=/dev/null
            . "${module}"
        done
    else
        warn "Directory not found: ${modules_dir}"
    fi

    # Build sorted key list without relying on Bash 4's mapfile (macOS 3.2 ok).
    local sorted_keys=()
    local key
    # shellcheck disable=SC2154 # APP_TESTS expected to be defined by modules/aliases
    while IFS= read -r key; do
        sorted_keys+=("${key}")
    done < <(
        # tolerate either indexed or associative; we just need keys
        eval 'for k in "${!APP_TESTS[@]}"; do printf "%s\n" "$k"; done' 2> /dev/null | sort -f
    )

    local total_tests=0
    local failed_tests=0
    local app_name command status

    for app_name in "${sorted_keys[@]}"; do
        # shellcheck disable=SC2154
        command="${APP_TESTS[${app_name}]}"
        if [[ -z "${command:-}" ]]; then
            warn "No command mapped for ${app_name}; skipping."
            continue
        fi
        app_test "${app_name}" "${command}"
        status=$?
        ((total_tests++))
        if [[ "${status}" -ne 0 ]]; then
            ((failed_tests++))
        fi
    done

    warn "Test Summary: ${total_tests} tests ran, ${failed_tests} failed."
    if command -v _Pause > /dev/null 2>&1; then _Pause; fi

    ((failed_tests == 0))   && return 0 || return 1
}

###############################################################################
# _install_package
#-----------------
# Generic package install dispatcher by OS.
#
# Args:
#   $1 - package name (string)
#
# Returns:
#   ${PASS} on success; ${FAIL} on failure.
###############################################################################
function _install_package() {
    local package_name="${1:-}"

    if [[ -z "${package_name}" ]]; then
        fail "Package name is required for installation."
        return "${FAIL}"
    fi

    info "Installing ${package_name} for ${OS_NAME:-unknown OS}..."

    case "${OS_NAME:-}" in
        Linux)
            if [[ -n "${UBUNTU_VER:-}" ]]; then
                if command -v _apt_install > /dev/null 2>&1; then
                    _apt_install "${package_name}"
                    return $?
                else
                    fail "_apt_install helper missing (lib/utils_apt.sh)."
                    return "${FAIL}"
                fi
            else
                fail "Unsupported Linux distribution. Please install ${package_name} manually."
                return "${FAIL}"
            fi
            ;;
        Darwin)
            if command -v _brew_install > /dev/null 2>&1; then
                _brew_install "${package_name}"
                return $?
            else
                fail "_brew_install helper missing (lib/utils_brew.sh)."
                return "${FAIL}"
            fi
            ;;
        CYGWIN* | MINGW* | MSYS* | Windows_NT)
            fail "Automatic installation for ${package_name} on Windows is not supported. Please install it manually."
            return "${FAIL}"
            ;;
        *)
            fail "Unsupported operating system: ${OS_NAME:-unknown}. Please install ${package_name} manually."
            return "${FAIL}"
            ;;
    esac
}

###############################################################################
# apply_tool_fixes
#-----------------
# Iterate over TOOL_FIXES and run fixes for tools that pass APP_TESTS checks.
#
# Globals:
#   TOOL_FIXES  - array/map of tool -> fix command
#   APP_TESTS   - array/map of tool -> test command
#   PROXY       - optional proxy prefix to prepend (string)
#
# Returns:
#   0 if all fixes succeeded; 1 if any failed.
###############################################################################
function apply_tool_fixes() {
    local overall_status=0
    local tool test_cmd fix_cmd

    # shellcheck disable=SC2154
    for tool in "${!TOOL_FIXES[@]}"; do
        # shellcheck disable=SC2154
        test_cmd="${APP_TESTS[${tool}]}"
        # shellcheck disable=SC2154
        fix_cmd="${TOOL_FIXES[${tool}]}"

        if [[ -z "${test_cmd:-}" ]]; then
            warn "No APP_TESTS entry found for [${tool}]; skipping test."
            continue
        fi

        info "Checking if [${tool}] is installed..."
        if app_test "${tool}" "${test_cmd}"; then
            info "Applying fix for [${tool}]: ${fix_cmd}"
            # NOTE: eval allows a proxy prefix and complex commands; prefer static commands where possible.
            if eval "${PROXY:-} ${fix_cmd}"; then
                pass "Fix applied successfully for [${tool}]."
            else
                fail "Fix FAILED for [${tool}]."
                overall_status=1
            fi
        else
            warn "Tool [${tool}] not installed or failed test; skipping fix."
        fi
    done

    return "${overall_status}"
}
