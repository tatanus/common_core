#!/usr/bin/env bash
###############################################################################
# NAME         : test_common.sh
# DESCRIPTION  : Common test helper functions
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-01-04
###############################################################################
# EDIT HISTORY:
# DATE       | EDITED BY      | DESCRIPTION
# -----------|----------------|----------------------------------------------
# 2025-01-04 | Adam Compton   | Initial creation
# 2025-01-04 | Adam Compton   | Added library guard, documentation, strict mode
###############################################################################
# USAGE:
#   source tests/helpers/test_common.sh || exit 1
###############################################################################

#===============================================================================
# Library Guard
#===============================================================================
if [[ -n "${TEST_COMMON_SH_LOADED:-}" ]]; then
    if (return 0 2> /dev/null); then
        return 0
    fi
else
    TEST_COMMON_SH_LOADED=1
fi

#===============================================================================
# Optional Strict Mode for Test Libraries
#===============================================================================
# Note: Some test frameworks may not work well with strict mode
# Uncomment if needed for your tests
# set -uo pipefail
# IFS=$'\n\t'

#===============================================================================
# Constants
#===============================================================================
readonly PASS=0
readonly FAIL=1

#===============================================================================
# Assertion Functions
#===============================================================================

###############################################################################
# assert_equals
#------------------------------------------------------------------------------
# Purpose  : Assert that two values are equal
# Usage    : assert_equals "expected" "actual"
# Arguments:
#   $1 : Expected value
#   $2 : Actual value
# Returns  : PASS if values match, FAIL otherwise
# Outputs  : Error message to stdout if assertion fails
###############################################################################
assert_equals() {
    local expected="${1:-}"
    local actual="${2:-}"

    if [[ "${expected}" == "${actual}" ]]; then
        return "${PASS}"
    else
        printf 'FAIL: Expected "%s", got "%s"\n' "${expected}" "${actual}"
        return "${FAIL}"
    fi
}

###############################################################################
# assert_not_equals
#------------------------------------------------------------------------------
# Purpose  : Assert that two values are not equal
# Usage    : assert_not_equals "expected" "actual"
# Arguments:
#   $1 : Expected value (that should not match)
#   $2 : Actual value
# Returns  : PASS if values differ, FAIL otherwise
# Outputs  : Error message to stdout if assertion fails
###############################################################################
assert_not_equals() {
    local expected="${1:-}"
    local actual="${2:-}"

    if [[ "${expected}" != "${actual}" ]]; then
        return "${PASS}"
    else
        printf 'FAIL: Expected values to differ, but both are "%s"\n' "${actual}"
        return "${FAIL}"
    fi
}

###############################################################################
# assert_true
#------------------------------------------------------------------------------
# Purpose  : Assert that a condition is true (exit code 0)
# Usage    : assert_true command_or_test
# Arguments:
#   $@ : Command or test to evaluate
# Returns  : PASS if command succeeds, FAIL otherwise
# Outputs  : Error message to stdout if assertion fails
###############################################################################
assert_true() {
    if "$@"; then
        return "${PASS}"
    else
        printf 'FAIL: Expected command to succeed: %s\n' "$*"
        return "${FAIL}"
    fi
}

###############################################################################
# assert_false
#------------------------------------------------------------------------------
# Purpose  : Assert that a condition is false (non-zero exit code)
# Usage    : assert_false command_or_test
# Arguments:
#   $@ : Command or test to evaluate
# Returns  : PASS if command fails, FAIL otherwise
# Outputs  : Error message to stdout if assertion fails
###############################################################################
assert_false() {
    if ! "$@"; then
        return "${PASS}"
    else
        printf 'FAIL: Expected command to fail: %s\n' "$*"
        return "${FAIL}"
    fi
}

###############################################################################
# assert_file_exists
#------------------------------------------------------------------------------
# Purpose  : Assert that a file exists
# Usage    : assert_file_exists "path/to/file"
# Arguments:
#   $1 : Path to file
# Returns  : PASS if file exists, FAIL otherwise
# Outputs  : Error message to stdout if assertion fails
###############################################################################
assert_file_exists() {
    local file="${1:-}"

    if [[ -f "${file}" ]]; then
        return "${PASS}"
    else
        printf 'FAIL: File does not exist: %s\n' "${file}"
        return "${FAIL}"
    fi
}

###############################################################################
# assert_dir_exists
#------------------------------------------------------------------------------
# Purpose  : Assert that a directory exists
# Usage    : assert_dir_exists "path/to/dir"
# Arguments:
#   $1 : Path to directory
# Returns  : PASS if directory exists, FAIL otherwise
# Outputs  : Error message to stdout if assertion fails
###############################################################################
assert_dir_exists() {
    local dir="${1:-}"

    if [[ -d "${dir}" ]]; then
        return "${PASS}"
    else
        printf 'FAIL: Directory does not exist: %s\n' "${dir}"
        return "${FAIL}"
    fi
}

###############################################################################
# assert_contains
#------------------------------------------------------------------------------
# Purpose  : Assert that a string contains a substring
# Usage    : assert_contains "haystack" "needle"
# Arguments:
#   $1 : String to search in (haystack)
#   $2 : Substring to find (needle)
# Returns  : PASS if substring found, FAIL otherwise
# Outputs  : Error message to stdout if assertion fails
###############################################################################
assert_contains() {
    local haystack="${1:-}"
    local needle="${2:-}"

    if [[ "${haystack}" == *"${needle}"* ]]; then
        return "${PASS}"
    else
        printf 'FAIL: String "%s" does not contain "%s"\n' "${haystack}" "${needle}"
        return "${FAIL}"
    fi
}

# Return success when sourced
return "${PASS}"
