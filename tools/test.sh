#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

###############################################################################
# NAME         : test.sh
# DESCRIPTION  : Run project tests (unit and/or integration)
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-01-04
###############################################################################
# EDIT HISTORY:
# DATE       | EDITED BY      | DESCRIPTION
# -----------|----------------|----------------------------------------------
# 2025-01-04 | Adam Compton   | Initial creation
# 2025-01-04 | Adam Compton   | Style compliance fixes - IFS, header, error handling
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
    printf '[INFO] %s\n' "$*"
}

###############################################################################
# warn_msg
#------------------------------------------------------------------------------
# Purpose  : Display warning message with color
###############################################################################
warn_msg() {
    printf '%b⚠%b  %s\n' "${YELLOW}" "${NC}" "$*"
}

###############################################################################
# error_msg
#------------------------------------------------------------------------------
# Purpose  : Display error message with color
###############################################################################
error_msg() {
    printf '%b✗%b %s\n' "${RED}" "${NC}" "$*" >&2
}

#===============================================================================
# Test Functions
#===============================================================================

###############################################################################
# has_bats_tests
#------------------------------------------------------------------------------
# Purpose  : Check if BATS test files exist in a directory
# Arguments: $1 - Directory to check
# Returns  : PASS if tests found, FAIL otherwise
###############################################################################
has_bats_tests() {
    local test_dir="${1}"

    if [[ ! -d "${test_dir}" ]]; then
        return "${FAIL}"
    fi

    # Use find instead of compgen for more reliable file detection
    if find "${test_dir}" -maxdepth 1 -type f -name "*.bats" -print -quit | grep -q .; then
        return "${PASS}"
    fi

    return "${FAIL}"
}

###############################################################################
# run_unit_tests
#------------------------------------------------------------------------------
# Purpose  : Run unit tests if they exist
# Returns  : PASS if tests pass or don't exist, FAIL if tests fail
###############################################################################
run_unit_tests() {
    local test_dir="${PROJECT_ROOT}/tests/unit"

    info "Checking for unit tests..."

    if has_bats_tests "${test_dir}"; then
        info "Running unit tests..."
        if bats "${test_dir}"; then
            return "${PASS}"
        else
            error_msg "Unit tests failed"
            return "${FAIL}"
        fi
    else
        warn_msg "No unit tests found in ${test_dir}"
        info "Create test files like: tests/unit/test_*.bats"
        return "${PASS}"
    fi
}

###############################################################################
# run_integration_tests
#------------------------------------------------------------------------------
# Purpose  : Run integration tests if they exist
# Returns  : PASS if tests pass or don't exist, FAIL if tests fail
###############################################################################
run_integration_tests() {
    local test_dir="${PROJECT_ROOT}/tests/integration"

    info "Checking for integration tests..."

    if has_bats_tests "${test_dir}"; then
        info "Running integration tests..."
        if bats "${test_dir}"; then
            return "${PASS}"
        else
            error_msg "Integration tests failed"
            return "${FAIL}"
        fi
    else
        warn_msg "No integration tests found in ${test_dir}"
        info "Create test files like: tests/integration/test_*.bats"
        return "${PASS}"
    fi
}

###############################################################################
# run_all_tests
#------------------------------------------------------------------------------
# Purpose  : Run all tests recursively
# Returns  : PASS if tests pass, FAIL if tests fail or none found
###############################################################################
run_all_tests() {
    local test_dir="${PROJECT_ROOT}/tests"

    info "Checking for any tests..."

    # Check if any .bats files exist recursively
    if find "${test_dir}" -type f -name "*.bats" -print -quit | grep -q .; then
        info "Running all tests..."
        if bats -r "${test_dir}"; then
            return "${PASS}"
        else
            error_msg "Tests failed"
            return "${FAIL}"
        fi
    else
        warn_msg "No tests found in ${test_dir}"
        info "Create tests in tests/unit/ or tests/integration/"
        return "${PASS}"
    fi
}

###############################################################################
# main
#------------------------------------------------------------------------------
# Purpose  : Main entry point
# Arguments: $1 - Test type (unit|integration|all), default: all
# Returns  : PASS if tests pass, FAIL otherwise
###############################################################################
main() {
    local test_type="${1:-all}"
    local exit_code="${PASS}"

    # Check if bats is installed
    if ! command -v bats > /dev/null 2>&1; then
        error_msg "bats command not found"
        info "Install bats to run tests:"
        info "  git clone https://github.com/bats-core/bats-core"
        info "  sudo ./bats-core/install.sh /usr/local"
        return "${FAIL}"
    fi

    case "${test_type}" in
        unit)
            if ! run_unit_tests; then
                exit_code="${FAIL}"
            fi
            ;;
        integration)
            if ! run_integration_tests; then
                exit_code="${FAIL}"
            fi
            ;;
        all)
            if ! run_all_tests; then
                exit_code="${FAIL}"
            fi
            ;;
        *)
            error_msg "Unknown test type: ${test_type}"
            info "Usage: ${0##*/} [unit|integration|all]"
            exit_code="${FAIL}"
            ;;
    esac

    return "${exit_code}"
}

#===============================================================================
# Script Entry Point
#===============================================================================

main "$@"
exit $?
