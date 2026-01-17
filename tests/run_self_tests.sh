#!/usr/bin/env bash
###############################################################################
# NAME         : run_self_tests.sh
# DESCRIPTION  : Run all ::self_test functions from utility modules
# AUTHOR       : Adam Compton
# DATE CREATED : 2026-01-08
###############################################################################
# EDIT HISTORY:
# DATE       | EDITED BY      | DESCRIPTION
# -----------|----------------|----------------------------------------------
# 2026-01-08 | Adam Compton   | Initial creation
###############################################################################

set -uo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PROJECT_ROOT

#===============================================================================
# Configuration
#===============================================================================

# Module prefixes that have ::self_test functions (in recommended order)
readonly -a SELF_TEST_MODULES=(
    utils
    platform
    config
    trap
    str
    env
    cmd
    file
    tui
    os
    dir
    curl
    git
    net
    brew
    apt
    py
    py_multi
    ruby
    go
    tools
    menu
)

#===============================================================================
# Logging (standalone - before lib/util.sh is sourced)
#===============================================================================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

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
# Core Functions
#===============================================================================

###############################################################################
# source_library
#------------------------------------------------------------------------------
# Purpose  : Source the main util.sh library
# Returns  : 0 on success, 1 on failure
###############################################################################
source_library() {
    local lib_path="${PROJECT_ROOT}/lib/util.sh"

    if [[ ! -f "${lib_path}" ]]; then
        fail "Library not found: ${lib_path}"
        return 1
    fi

    info "Sourcing library: ${lib_path}"

    # Clear all library guard variables to ensure fresh load
    # This prevents issues when guards are exported from parent shells
    unset UTILS_SH_LOADED
    unset UTIL_PLATFORM_SH_LOADED
    unset UTIL_CONFIG_SH_LOADED
    unset UTIL_TRAP_SH_LOADED
    unset UTIL_STR_SH_LOADED
    unset UTIL_ENV_SH_LOADED
    unset UTIL_CMD_SH_LOADED
    unset UTIL_FILE_SH_LOADED
    unset UTIL_TUI_SH_LOADED
    unset UTIL_OS_SH_LOADED
    unset UTIL_DIR_SH_LOADED
    unset UTIL_CURL_SH_LOADED
    unset UTIL_GIT_SH_LOADED
    unset UTIL_NET_SH_LOADED
    unset UTIL_APT_SH_LOADED
    unset UTIL_BREW_SH_LOADED
    unset UTIL_PY_SH_LOADED
    unset UTIL_PY_MULTI_SH_LOADED
    unset UTIL_RUBY_SH_LOADED
    unset UTIL_GO_SH_LOADED
    unset UTIL_MENU_SH_LOADED
    unset UTIL_TOOLS_SH_LOADED

    # shellcheck source=/dev/null
    if source "${lib_path}"; then
        pass "Library loaded successfully"
        return 0
    else
        fail "Failed to source library"
        return 1
    fi
}

###############################################################################
# run_module_self_test
#------------------------------------------------------------------------------
# Purpose  : Run a single module's ::self_test function
# Arguments: $1 - Module prefix (e.g., "platform", "os")
# Returns  : 0 if test passes, 1 if fails or not found
###############################################################################
run_module_self_test() {
    local module="${1}"
    local func_name="${module}::self_test"

    # Check if function exists
    if ! declare -F "${func_name}" > /dev/null 2>&1; then
        warn "No self_test for: ${module}"
        return 2 # Not found (different from failure)
    fi

    #_header "${func_name}"

    # Run the self-test and capture result
    if "${func_name}"; then
        return 0
    else
        return 1
    fi
}

###############################################################################
# run_all_self_tests
#------------------------------------------------------------------------------
# Purpose  : Run all module ::self_test functions
# Returns  : 0 if all pass, 1 if any fail
###############################################################################
run_all_self_tests() {
    local module
    local result
    local -i total=0
    local -i passed=0
    local -i failed=0
    local -i skipped=0
    local -a failed_modules=()

    info "Running all module self-tests..."
    echo ""

    for module in "${SELF_TEST_MODULES[@]}"; do
        run_module_self_test "${module}"
        result=$?

        case ${result} in
            0)
                ((passed++))
                ((total++))
                ;;
            1)
                ((failed++))
                ((total++))
                failed_modules+=("${module}")
                ;;
            2)
                ((skipped++))
                ;;
            *) ;;
        esac
        echo ""
    done

    # Print summary
    echo "================================================================"
    info "Self-Test Summary:"
    info "  Total Run: ${total}"
    info "  Skipped:   ${skipped} (no self_test function)"
    pass "  Passed:    ${passed}"

    if [[ ${failed} -gt 0 ]]; then
        fail "  Failed:    ${failed}"
        fail "  Failed modules: ${failed_modules[*]}"
        echo "================================================================"
        return 1
    else
        echo "================================================================"
        pass "All self-tests passed!"
        return 0
    fi
}

###############################################################################
# show_usage
#------------------------------------------------------------------------------
# Purpose  : Display usage information
###############################################################################
show_usage() {
    cat << 'EOF'
Usage: run_self_tests.sh [OPTIONS] [MODULE...]

Run ::self_test functions from utility modules.

OPTIONS:
    -h, --help      Show this help message
    -l, --list      List available modules with self_test functions
    -v, --verbose   Enable verbose output (set DEBUG=1)

ARGUMENTS:
    MODULE...       Specific module(s) to test (e.g., platform os git)
                    If omitted, runs all module self-tests

EXAMPLES:
    ./run_self_tests.sh                 # Run all self-tests
    ./run_self_tests.sh platform os     # Run specific modules
    ./run_self_tests.sh -l              # List available modules
    ./run_self_tests.sh -v git          # Verbose git self-test

EOF
}

###############################################################################
# list_modules
#------------------------------------------------------------------------------
# Purpose  : List all modules and their self_test availability
###############################################################################
list_modules() {
    local module func_name

    info "Available modules:"
    echo ""

    # Must source library first to check functions
    source_library > /dev/null 2>&1 || {
        fail "Cannot list modules - library failed to load"
        return 1
    }

    printf "  %-15s %s\n" "MODULE" "STATUS"
    printf "  %-15s %s\n" "------" "------"

    for module in "${SELF_TEST_MODULES[@]}"; do
        func_name="${module}::self_test"
        if declare -F "${func_name}" > /dev/null 2>&1; then
            printf "  %-15s %b%s%b\n" "${module}" "${GREEN}" "available" "${NC}"
        else
            printf "  %-15s %b%s%b\n" "${module}" "${YELLOW}" "not found" "${NC}"
        fi
    done

    echo ""
    return 0
}

###############################################################################
# main
#------------------------------------------------------------------------------
# Purpose  : Main entry point
# Arguments: $@ - Command line arguments
# Returns  : 0 on success, 1 on failure
###############################################################################
main() {
    local -a modules_to_test=()
    local arg

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        arg="$1"
        case "${arg}" in
            -h | --help)
                show_usage
                return 0
                ;;
            -l | --list)
                list_modules
                return $?
                ;;
            -v | --verbose)
                export DEBUG=1
                shift
                ;;
            -*)
                fail "Unknown option: ${arg}"
                show_usage
                return 1
                ;;
            *)
                modules_to_test+=("${arg}")
                shift
                ;;
        esac
    done

    # Source the library
    echo ""
    if ! source_library; then
        return 1
    fi
    echo ""

    # Run tests
    if [[ ${#modules_to_test[@]} -gt 0 ]]; then
        # Run specific modules
        local module result
        local -i passed=0 failed=0

        for module in "${modules_to_test[@]}"; do
            run_module_self_test "${module}"
            result=$?
            if [[ ${result} -eq 0 ]]; then
                ((passed++))
            elif [[ ${result} -eq 1 ]]; then
                ((failed++))
            fi
            echo ""
        done

        echo "================================================================"
        info "Results: ${passed} passed, ${failed} failed"
        echo "================================================================"

        [[ ${failed} -eq 0 ]] && return 0 || return 1
    else
        # Run all tests
        run_all_self_tests
        return $?
    fi
}

#===============================================================================
# Script Entry Point
#===============================================================================

main "$@"
exit $?
