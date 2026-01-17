#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

###############################################################################
# NAME         : test_example.sh
# DESCRIPTION  : Example unit test demonstrating test helper usage
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-01-04
###############################################################################
# EDIT HISTORY:
# DATE       | EDITED BY      | DESCRIPTION
# -----------|----------------|----------------------------------------------
# 2025-01-04 | Adam Compton   | Initial creation
# 2025-01-04 | Adam Compton   | Added safety checks, IFS, header
###############################################################################
# NOTE: This is an example test file. Delete when adding your own tests.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly TEST_HELPER="${SCRIPT_DIR}/../helpers/test_common.sh"
readonly PASS=0
readonly FAIL=1

#===============================================================================
# Setup
#===============================================================================

# Verify test helper exists before sourcing
if [[ ! -f "${TEST_HELPER}" ]]; then
    printf 'ERROR: Test helper not found: %s\n' "${TEST_HELPER}" >&2
    exit "${FAIL}"
fi

# Source test helper
# shellcheck source=/dev/null
source "${TEST_HELPER}" || {
    printf 'ERROR: Failed to source test helper: %s\n' "${TEST_HELPER}" >&2
    exit "${FAIL}"
}

#===============================================================================
# Tests
#===============================================================================

###############################################################################
# test_assert_equals
#------------------------------------------------------------------------------
# Purpose  : Test the assert_equals function
###############################################################################
test_assert_equals() {
    printf 'Running test_assert_equals...\n'

    # Should pass
    if ! assert_equals "hello" "hello"; then
        printf 'FAIL: assert_equals failed on matching strings\n'
        return "${FAIL}"
    fi

    # Should fail (we expect this)
    if assert_equals "hello" "world"; then
        printf 'FAIL: assert_equals passed on non-matching strings\n'
        return "${FAIL}"
    fi

    printf 'PASS: test_assert_equals\n'
    return "${PASS}"
}

###############################################################################
# test_assert_not_equals
#------------------------------------------------------------------------------
# Purpose  : Test the assert_not_equals function
###############################################################################
test_assert_not_equals() {
    printf 'Running test_assert_not_equals...\n'

    # Should pass
    if ! assert_not_equals "hello" "world"; then
        printf 'FAIL: assert_not_equals failed on different strings\n'
        return "${FAIL}"
    fi

    printf 'PASS: test_assert_not_equals\n'
    return "${PASS}"
}

###############################################################################
# test_assert_true
#------------------------------------------------------------------------------
# Purpose  : Test the assert_true function
###############################################################################
test_assert_true() {
    printf 'Running test_assert_true...\n'

    # Should pass
    if ! assert_true true; then
        printf 'FAIL: assert_true failed on true command\n'
        return "${FAIL}"
    fi

    # Test with command that returns 0
    if ! assert_true [[ "test" == "test" ]]; then
        printf 'FAIL: assert_true failed on successful test\n'
        return "${FAIL}"
    fi

    printf 'PASS: test_assert_true\n'
    return "${PASS}"
}

###############################################################################
# test_assert_contains
#------------------------------------------------------------------------------
# Purpose  : Test the assert_contains function
###############################################################################
test_assert_contains() {
    printf 'Running test_assert_contains...\n'

    local text="hello world"

    # Should pass
    if ! assert_contains "${text}" "world"; then
        printf 'FAIL: assert_contains failed to find substring\n'
        return "${FAIL}"
    fi

    printf 'PASS: test_assert_contains\n'
    return "${PASS}"
}

#===============================================================================
# Test Runner
#===============================================================================

###############################################################################
# main
#------------------------------------------------------------------------------
# Purpose  : Run all tests
# Returns  : PASS if all tests pass, FAIL if any fail
###############################################################################
main() {
    local failed=0

    printf '==================== Running Example Tests ====================\n'
    printf '\n'

    # Run each test
    test_assert_equals || ((failed++))
    printf '\n'

    test_assert_not_equals || ((failed++))
    printf '\n'

    test_assert_true || ((failed++))
    printf '\n'

    test_assert_contains || ((failed++))
    printf '\n'

    # Summary
    printf '===============================================================\n'
    if [[ ${failed} -eq 0 ]]; then
        printf 'All tests passed!\n'
        return "${PASS}"
    else
        printf 'Tests failed: %d\n' "${failed}"
        return "${FAIL}"
    fi
}

#===============================================================================
# Entry Point
#===============================================================================

main "$@"
exit $?
