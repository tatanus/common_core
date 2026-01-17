#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

###############################################################################
# NAME         : run_tests.sh
# DESCRIPTION  : Run all project test scripts
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-01-04
###############################################################################
# EDIT HISTORY:
# DATE       | EDITED BY      | DESCRIPTION
# -----------|----------------|----------------------------------------------
# 2025-01-04 | Adam Compton   | Initial creation
# 2025-01-04 | Adam Compton   | Complete rewrite for robustness and style compliance
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PROJECT_ROOT
readonly PASS=0
readonly FAIL=1

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

#===============================================================================
# Logging Functions
#===============================================================================

###############################################################################
# info
#------------------------------------------------------------------------------
# Purpose  : Display informational message
###############################################################################
info() {
    printf '%b[INFO]%b %s\n' "${BLUE}" "${NC}" "$*"
}

###############################################################################
# pass_msg
#------------------------------------------------------------------------------
# Purpose  : Display success message
###############################################################################
pass_msg() {
    printf '%b[PASS]%b %s\n' "${GREEN}" "${NC}" "$*"
}

###############################################################################
# warn_msg
#------------------------------------------------------------------------------
# Purpose  : Display warning message
###############################################################################
warn_msg() {
    printf '%b[WARN]%b %s\n' "${YELLOW}" "${NC}" "$*"
}

###############################################################################
# error_msg
#------------------------------------------------------------------------------
# Purpose  : Display error message
###############################################################################
error_msg() {
    printf '%b[ERROR]%b %s\n' "${RED}" "${NC}" "$*" >&2
}

#===============================================================================
# Test Functions
#===============================================================================

###############################################################################
# find_test_scripts
#------------------------------------------------------------------------------
# Purpose  : Find all test_*.sh files in tests/unit/
# Returns  : Array of test script paths via stdout (one per line)
###############################################################################
find_test_scripts() {
    local test_dir="${PROJECT_ROOT}/tests/unit"

    if [[ ! -d "${test_dir}" ]]; then
        return
    fi

    find "${test_dir}" -maxdepth 1 -type f -name "test_*.sh" -print
}

###############################################################################
# run_test_script
#------------------------------------------------------------------------------
# Purpose  : Run a single test script
# Arguments: $1 - Path to test script
# Returns  : PASS if test succeeds, FAIL otherwise
###############################################################################
run_test_script() {
    local test_script="${1}"
    local test_name

    test_name="$(basename "${test_script}")"

    info "Running: ${test_name}"

    if [[ ! -f "${test_script}" ]]; then
        error_msg "Test script not found: ${test_script}"
        return "${FAIL}"
    fi

    if [[ ! -x "${test_script}" ]]; then
        warn_msg "Test script not executable: ${test_script}"
        info "Making executable..."
        chmod +x "${test_script}"
    fi

    # Run the test script
    if bash "${test_script}"; then
        pass_msg "${test_name}"
        return "${PASS}"
    else
        error_msg "${test_name} FAILED"
        return "${FAIL}"
    fi
}

###############################################################################
# run_all_tests
#------------------------------------------------------------------------------
# Purpose  : Run all test scripts found
# Returns  : PASS if all tests pass, FAIL if any fail
###############################################################################
run_all_tests() {
    local -a test_scripts=()
    local test_script
    local total_tests=0
    local failed_tests=0
    local passed_tests=0

    info "Finding test scripts..."

    # Build array of test scripts
    while IFS= read -r test_script; do
        test_scripts+=("${test_script}")
    done < <(find_test_scripts)

    total_tests=${#test_scripts[@]}

    if [[ ${total_tests} -eq 0 ]]; then
        warn_msg "No test scripts found (tests/unit/test_*.sh)"
        info "Create test scripts in tests/unit/"
        return "${PASS}"
    fi

    info "Found ${total_tests} test script(s)"
    echo ""

    # Run each test script
    for test_script in "${test_scripts[@]}"; do
        if run_test_script "${test_script}"; then
            ((passed_tests++))
        else
            ((failed_tests++))
        fi
        echo ""
    done

    # Summary
    echo "================================================================"
    info "Test Summary:"
    info "  Total:  ${total_tests}"
    pass_msg "Passed: ${passed_tests}"

    if [[ ${failed_tests} -gt 0 ]]; then
        error_msg "Failed: ${failed_tests}"
        echo "================================================================"
        return "${FAIL}"
    else
        echo "================================================================"
        pass_msg "All tests passed!"
        return "${PASS}"
    fi
}

###############################################################################
# main
#------------------------------------------------------------------------------
# Purpose  : Main entry point
# Returns  : PASS if all tests pass, FAIL otherwise
###############################################################################
main() {
    local exit_code

    info "Running all test scripts..."
    echo ""

    if run_all_tests; then
        exit_code="${PASS}"
    else
        exit_code="${FAIL}"
    fi

    return "${exit_code}"
}

#===============================================================================
# Script Entry Point
#===============================================================================

main "$@"
exit $?
