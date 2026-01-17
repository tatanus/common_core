#!/usr/bin/env bash
###############################################################################
# NAME         : util_str.sh
# DESCRIPTION  : String manipulation and text processing utilities using Bash
#                built-ins where possible to minimize external command usage.
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-12-26
###############################################################################
# EDIT HISTORY:
# DATE        | EDITED BY      | DESCRIPTION
# ------------|----------------|-----------------------------------------------
# 2025-12-26  | Adam Compton   | Initial creation with core string utilities
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Library Guard
#===============================================================================
if [[ -n "${UTIL_STR_SH_LOADED:-}" ]]; then
    if (return 0 2> /dev/null); then
        return 0
    fi
else
    UTIL_STR_SH_LOADED=1
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
# String Length and Empty Checks
#===============================================================================

###############################################################################
# str::length
#------------------------------------------------------------------------------
# Purpose  : Get the length of a string
# Usage    : len=$(str::length "hello world")
# Arguments:
#   $1 : Input string
# Returns  : PASS always
# Outputs  : Length of string
# Globals  : None
###############################################################################
function str::length() {
    local str="${1:-}"
    printf '%s\n' "${#str}"
    return "${PASS}"
}

###############################################################################
# str::is_empty
#------------------------------------------------------------------------------
# Purpose  : Check if a string is empty or unset
# Usage    : str::is_empty "${var}" && echo "empty"
# Arguments:
#   $1 : Input string
# Returns  : PASS if empty, FAIL if not empty
# Globals  : None
###############################################################################
function str::is_empty() {
    local str="${1:-}"
    [[ -z "${str}" ]] && return "${PASS}" || return "${FAIL}"
}

###############################################################################
# str::is_not_empty
#------------------------------------------------------------------------------
# Purpose  : Check if a string is not empty
# Usage    : str::is_not_empty "${var}" && echo "has content"
# Arguments:
#   $1 : Input string
# Returns  : PASS if not empty, FAIL if empty
# Globals  : None
###############################################################################
function str::is_not_empty() {
    local str="${1:-}"
    [[ -n "${str}" ]] && return "${PASS}" || return "${FAIL}"
}

###############################################################################
# str::is_blank
#------------------------------------------------------------------------------
# Purpose  : Check if a string is empty or contains only whitespace
# Usage    : str::is_blank "   " && echo "blank"
# Arguments:
#   $1 : Input string
# Returns  : PASS if blank, FAIL if has non-whitespace content
# Globals  : None
###############################################################################
function str::is_blank() {
    local str="${1:-}"
    [[ -z "${str//[[:space:]]/}" ]] && return "${PASS}" || return "${FAIL}"
}

#===============================================================================
# Case Conversion
#===============================================================================

###############################################################################
# str::to_upper
#------------------------------------------------------------------------------
# Purpose  : Convert string to uppercase
# Usage    : upper=$(str::to_upper "hello")
# Arguments:
#   $1 : Input string
# Returns  : PASS always
# Outputs  : Uppercase string
# Globals  : None
###############################################################################
function str::to_upper() {
    local str="${1:-}"
    printf '%s\n' "${str^^}"
    return "${PASS}"
}

###############################################################################
# str::to_lower
#------------------------------------------------------------------------------
# Purpose  : Convert string to lowercase
# Usage    : lower=$(str::to_lower "HELLO")
# Arguments:
#   $1 : Input string
# Returns  : PASS always
# Outputs  : Lowercase string
# Globals  : None
###############################################################################
function str::to_lower() {
    local str="${1:-}"
    printf '%s\n' "${str,,}"
    return "${PASS}"
}

###############################################################################
# str::capitalize
#------------------------------------------------------------------------------
# Purpose  : Capitalize first character of string
# Usage    : cap=$(str::capitalize "hello")
# Arguments:
#   $1 : Input string
# Returns  : PASS always
# Outputs  : Capitalized string
# Globals  : None
###############################################################################
function str::capitalize() {
    local str="${1:-}"
    printf '%s\n' "${str^}"
    return "${PASS}"
}

###############################################################################
# str::to_title_case
#------------------------------------------------------------------------------
# Purpose  : Convert string to title case (capitalize each word)
# Usage    : title=$(str::to_title_case "hello world")
# Arguments:
#   $1 : Input string
# Returns  : PASS always
# Outputs  : Title case string
# Globals  : None
###############################################################################
function str::to_title_case() {
    local str="${1:-}"
    local result=""
    local word

    for word in ${str}; do
        result+="${word^} "
    done

    # Remove trailing space
    printf '%s\n' "${result% }"
    return "${PASS}"
}

#===============================================================================
# Trimming and Padding
#===============================================================================

###############################################################################
# str::trim
#------------------------------------------------------------------------------
# Purpose  : Remove leading and trailing whitespace
# Usage    : trimmed=$(str::trim "  hello  ")
# Arguments:
#   $1 : Input string
# Returns  : PASS always
# Outputs  : Trimmed string
# Globals  : None
###############################################################################
function str::trim() {
    local str="${1:-}"

    # Remove leading whitespace
    str="${str#"${str%%[![:space:]]*}"}"
    # Remove trailing whitespace
    str="${str%"${str##*[![:space:]]}"}"

    printf '%s\n' "${str}"
    return "${PASS}"
}

###############################################################################
# str::trim_left
#------------------------------------------------------------------------------
# Purpose  : Remove leading whitespace only
# Usage    : trimmed=$(str::trim_left "  hello  ")
# Arguments:
#   $1 : Input string
# Returns  : PASS always
# Outputs  : Left-trimmed string
# Globals  : None
###############################################################################
function str::trim_left() {
    local str="${1:-}"
    str="${str#"${str%%[![:space:]]*}"}"
    printf '%s\n' "${str}"
    return "${PASS}"
}

###############################################################################
# str::trim_right
#------------------------------------------------------------------------------
# Purpose  : Remove trailing whitespace only
# Usage    : trimmed=$(str::trim_right "  hello  ")
# Arguments:
#   $1 : Input string
# Returns  : PASS always
# Outputs  : Right-trimmed string
# Globals  : None
###############################################################################
function str::trim_right() {
    local str="${1:-}"
    str="${str%"${str##*[![:space:]]}"}"
    printf '%s\n' "${str}"
    return "${PASS}"
}

###############################################################################
# str::pad_left
#------------------------------------------------------------------------------
# Purpose  : Pad string on the left to specified length
# Usage    : padded=$(str::pad_left "42" 5 "0")  # "00042"
# Arguments:
#   $1 : Input string
#   $2 : Total desired length
#   $3 : Padding character (default: space)
# Returns  : PASS always
# Outputs  : Padded string
# Globals  : None
###############################################################################
function str::pad_left() {
    local str="${1:-}"
    local length="${2:-0}"
    local pad_char="${3:- }"

    local current_len="${#str}"
    local pad_needed=$((length - current_len))

    if [[ ${pad_needed} -gt 0 ]]; then
        local padding=""
        local i
        for ((i = 0; i < pad_needed; i++)); do
            padding+="${pad_char}"
        done
        str="${padding}${str}"
    fi

    printf '%s\n' "${str}"
    return "${PASS}"
}

###############################################################################
# str::pad_right
#------------------------------------------------------------------------------
# Purpose  : Pad string on the right to specified length
# Usage    : padded=$(str::pad_right "42" 5 "0")  # "42000"
# Arguments:
#   $1 : Input string
#   $2 : Total desired length
#   $3 : Padding character (default: space)
# Returns  : PASS always
# Outputs  : Padded string
# Globals  : None
###############################################################################
function str::pad_right() {
    local str="${1:-}"
    local length="${2:-0}"
    local pad_char="${3:- }"

    local current_len="${#str}"
    local pad_needed=$((length - current_len))

    if [[ ${pad_needed} -gt 0 ]]; then
        local i
        for ((i = 0; i < pad_needed; i++)); do
            str+="${pad_char}"
        done
    fi

    printf '%s\n' "${str}"
    return "${PASS}"
}

#===============================================================================
# Substring Operations
#===============================================================================

###############################################################################
# str::substring
#------------------------------------------------------------------------------
# Purpose  : Extract substring from string
# Usage    : sub=$(str::substring "hello world" 0 5)  # "hello"
# Arguments:
#   $1 : Input string
#   $2 : Start position (0-indexed)
#   $3 : Length (optional, defaults to rest of string)
# Returns  : PASS always
# Outputs  : Substring
# Globals  : None
###############################################################################
function str::substring() {
    local str="${1:-}"
    local start="${2:-0}"
    local length="${3:-}"

    if [[ -n "${length}" ]]; then
        printf '%s\n' "${str:${start}:${length}}"
    else
        printf '%s\n' "${str:${start}}"
    fi

    return "${PASS}"
}

###############################################################################
# str::contains
#------------------------------------------------------------------------------
# Purpose  : Check if string contains a substring
# Usage    : str::contains "hello world" "world" && echo "found"
# Arguments:
#   $1 : Input string
#   $2 : Substring to find
# Returns  : PASS if found, FAIL if not found
# Globals  : None
###############################################################################
function str::contains() {
    local str="${1:-}"
    local needle="${2:-}"

    [[ -z "${needle}" ]] && return "${FAIL}"
    [[ "${str}" == *"${needle}"* ]] && return "${PASS}" || return "${FAIL}"
}

###############################################################################
# str::starts_with
#------------------------------------------------------------------------------
# Purpose  : Check if string starts with a prefix
# Usage    : str::starts_with "hello world" "hello" && echo "yes"
# Arguments:
#   $1 : Input string
#   $2 : Prefix to check
# Returns  : PASS if starts with prefix, FAIL otherwise
# Globals  : None
###############################################################################
function str::starts_with() {
    local str="${1:-}"
    local prefix="${2:-}"

    [[ -z "${prefix}" ]] && return "${PASS}"
    [[ "${str}" == "${prefix}"* ]] && return "${PASS}" || return "${FAIL}"
}

###############################################################################
# str::ends_with
#------------------------------------------------------------------------------
# Purpose  : Check if string ends with a suffix
# Usage    : str::ends_with "hello world" "world" && echo "yes"
# Arguments:
#   $1 : Input string
#   $2 : Suffix to check
# Returns  : PASS if ends with suffix, FAIL otherwise
# Globals  : None
###############################################################################
function str::ends_with() {
    local str="${1:-}"
    local suffix="${2:-}"

    [[ -z "${suffix}" ]] && return "${PASS}"
    [[ "${str}" == *"${suffix}" ]] && return "${PASS}" || return "${FAIL}"
}

#===============================================================================
# Search and Replace
#===============================================================================

###############################################################################
# str::replace
#------------------------------------------------------------------------------
# Purpose  : Replace first occurrence of pattern in string
# Usage    : new=$(str::replace "hello world" "world" "bash")
# Arguments:
#   $1 : Input string
#   $2 : Pattern to find
#   $3 : Replacement string
# Returns  : PASS always
# Outputs  : Modified string
# Globals  : None
###############################################################################
function str::replace() {
    local str="${1:-}"
    local pattern="${2:-}"
    local replacement="${3:-}"

    printf '%s\n' "${str/${pattern}/${replacement}}"
    return "${PASS}"
}

###############################################################################
# str::replace_all
#------------------------------------------------------------------------------
# Purpose  : Replace all occurrences of pattern in string
# Usage    : new=$(str::replace_all "hello hello" "hello" "hi")
# Arguments:
#   $1 : Input string
#   $2 : Pattern to find
#   $3 : Replacement string
# Returns  : PASS always
# Outputs  : Modified string
# Globals  : None
###############################################################################
function str::replace_all() {
    local str="${1:-}"
    local pattern="${2:-}"
    local replacement="${3:-}"

    printf '%s\n' "${str//${pattern}/${replacement}}"
    return "${PASS}"
}

###############################################################################
# str::remove
#------------------------------------------------------------------------------
# Purpose  : Remove first occurrence of pattern from string
# Usage    : new=$(str::remove "hello world" "world")
# Arguments:
#   $1 : Input string
#   $2 : Pattern to remove
# Returns  : PASS always
# Outputs  : Modified string
# Globals  : None
###############################################################################
function str::remove() {
    local str="${1:-}"
    local pattern="${2:-}"

    printf '%s\n' "${str/${pattern}/}"
    return "${PASS}"
}

###############################################################################
# str::remove_all
#------------------------------------------------------------------------------
# Purpose  : Remove all occurrences of pattern from string
# Usage    : new=$(str::remove_all "hello hello" "hello")
# Arguments:
#   $1 : Input string
#   $2 : Pattern to remove
# Returns  : PASS always
# Outputs  : Modified string
# Globals  : None
###############################################################################
function str::remove_all() {
    local str="${1:-}"
    local pattern="${2:-}"

    printf '%s\n' "${str//${pattern}/}"
    return "${PASS}"
}

#===============================================================================
# Splitting and Joining
#===============================================================================

###############################################################################
# str::split
#------------------------------------------------------------------------------
# Purpose  : Split string by delimiter into array
# Usage    : str::split "a,b,c" "," result_array
# Arguments:
#   $1 : Input string
#   $2 : Delimiter
#   $3 : Name of array variable to populate
# Returns  : PASS always
# Globals  : None
###############################################################################
function str::split() {
    local str="${1:-}"
    local delimiter="${2:-}"
    local array_name="${3:-}"

    if [[ -z "${array_name}" ]]; then
        error "str::split: array name required"
        return "${FAIL}"
    fi

    local -n result_array="${array_name}"
    result_array=()

    if [[ -z "${delimiter}" ]]; then
        # Split by character
        local i
        for ((i = 0; i < ${#str}; i++)); do
            result_array+=("${str:i:1}")
        done
    else
        # Split by delimiter
        local IFS="${delimiter}"
        read -ra result_array <<< "${str}"
    fi

    return "${PASS}"
}

###############################################################################
# str::join
#------------------------------------------------------------------------------
# Purpose  : Join array elements with delimiter
# Usage    : joined=$(str::join "," "${array[@]}")
# Arguments:
#   $1 : Delimiter
#   $@ : Array elements
# Returns  : PASS always
# Outputs  : Joined string
# Globals  : None
###############################################################################
function str::join() {
    local delimiter="${1:-}"
    shift

    local result=""
    local first=true

    for item in "$@"; do
        if [[ "${first}" == "true" ]]; then
            result="${item}"
            first=false
        else
            result+="${delimiter}${item}"
        fi
    done

    printf '%s\n' "${result}"
    return "${PASS}"
}

#===============================================================================
# Validation
#===============================================================================

###############################################################################
# str::is_integer
#------------------------------------------------------------------------------
# Purpose  : Check if string is a valid integer (positive or negative)
# Usage    : str::is_integer "-42" && echo "is integer"
# Arguments:
#   $1 : Input string
# Returns  : PASS if integer, FAIL otherwise
# Globals  : None
###############################################################################
function str::is_integer() {
    local str="${1:-}"
    [[ "${str}" =~ ^-?[0-9]+$ ]] && return "${PASS}" || return "${FAIL}"
}

###############################################################################
# str::is_positive_integer
#------------------------------------------------------------------------------
# Purpose  : Check if string is a positive integer
# Usage    : str::is_positive_integer "42" && echo "is positive"
# Arguments:
#   $1 : Input string
# Returns  : PASS if positive integer, FAIL otherwise
# Globals  : None
###############################################################################
function str::is_positive_integer() {
    local str="${1:-}"
    [[ "${str}" =~ ^[0-9]+$ ]] && [[ "${str}" -gt 0 ]] && return "${PASS}" || return "${FAIL}"
}

###############################################################################
# str::is_float
#------------------------------------------------------------------------------
# Purpose  : Check if string is a valid floating-point number
# Usage    : str::is_float "3.14" && echo "is float"
# Arguments:
#   $1 : Input string
# Returns  : PASS if float, FAIL otherwise
# Globals  : None
###############################################################################
function str::is_float() {
    local str="${1:-}"
    [[ "${str}" =~ ^-?[0-9]*\.?[0-9]+$ ]] && return "${PASS}" || return "${FAIL}"
}

###############################################################################
# str::is_alpha
#------------------------------------------------------------------------------
# Purpose  : Check if string contains only alphabetic characters
# Usage    : str::is_alpha "hello" && echo "is alpha"
# Arguments:
#   $1 : Input string
# Returns  : PASS if alphabetic only, FAIL otherwise
# Globals  : None
###############################################################################
function str::is_alpha() {
    local str="${1:-}"
    [[ -z "${str}" ]] && return "${FAIL}"
    [[ "${str}" =~ ^[a-zA-Z]+$ ]] && return "${PASS}" || return "${FAIL}"
}

###############################################################################
# str::is_alphanumeric
#------------------------------------------------------------------------------
# Purpose  : Check if string contains only alphanumeric characters
# Usage    : str::is_alphanumeric "hello123" && echo "is alnum"
# Arguments:
#   $1 : Input string
# Returns  : PASS if alphanumeric only, FAIL otherwise
# Globals  : None
###############################################################################
function str::is_alphanumeric() {
    local str="${1:-}"
    [[ -z "${str}" ]] && return "${FAIL}"
    [[ "${str}" =~ ^[a-zA-Z0-9]+$ ]] && return "${PASS}" || return "${FAIL}"
}

###############################################################################
# str::matches
#------------------------------------------------------------------------------
# Purpose  : Check if string matches a regex pattern
# Usage    : str::matches "test@example.com" "^[^@]+@[^@]+$" && echo "valid"
# Arguments:
#   $1 : Input string
#   $2 : Regex pattern
# Returns  : PASS if matches, FAIL otherwise
# Globals  : None
###############################################################################
function str::matches() {
    local str="${1:-}"
    local pattern="${2:-}"

    [[ -z "${pattern}" ]] && return "${FAIL}"
    [[ "${str}" =~ ${pattern} ]] && return "${PASS}" || return "${FAIL}"
}

#===============================================================================
# Utility Functions
#===============================================================================

###############################################################################
# str::repeat
#------------------------------------------------------------------------------
# Purpose  : Repeat a string n times
# Usage    : repeated=$(str::repeat "ab" 3)  # "ababab"
# Arguments:
#   $1 : Input string
#   $2 : Number of repetitions
# Returns  : PASS always
# Outputs  : Repeated string
# Globals  : None
###############################################################################
function str::repeat() {
    local str="${1:-}"
    local count="${2:-1}"

    local result=""
    local i

    for ((i = 0; i < count; i++)); do
        result+="${str}"
    done

    printf '%s\n' "${result}"
    return "${PASS}"
}

###############################################################################
# str::reverse
#------------------------------------------------------------------------------
# Purpose  : Reverse a string
# Usage    : reversed=$(str::reverse "hello")  # "olleh"
# Arguments:
#   $1 : Input string
# Returns  : PASS always
# Outputs  : Reversed string
# Globals  : None
###############################################################################
function str::reverse() {
    local str="${1:-}"
    local result=""
    local i

    for ((i = ${#str} - 1; i >= 0; i--)); do
        result+="${str:i:1}"
    done

    printf '%s\n' "${result}"
    return "${PASS}"
}

###############################################################################
# str::count
#------------------------------------------------------------------------------
# Purpose  : Count occurrences of substring in string
# Usage    : count=$(str::count "hello hello hello" "hello")  # 3
# Arguments:
#   $1 : Input string
#   $2 : Substring to count
# Returns  : PASS always
# Outputs  : Count of occurrences
# Globals  : None
###############################################################################
function str::count() {
    local str="${1:-}"
    local needle="${2:-}"

    [[ -z "${needle}" ]] && printf '0\n' && return "${PASS}"

    local count=0
    local temp="${str}"

    while [[ "${temp}" == *"${needle}"* ]]; do
        ((count++))
        temp="${temp#*"${needle}"}"
    done

    printf '%s\n' "${count}"
    return "${PASS}"
}

###############################################################################
# str::truncate
#------------------------------------------------------------------------------
# Purpose  : Truncate string to specified length with optional suffix
# Usage    : short=$(str::truncate "hello world" 8 "...")  # "hello..."
# Arguments:
#   $1 : Input string
#   $2 : Maximum length
#   $3 : Suffix to append if truncated (optional, default: "")
# Returns  : PASS always
# Outputs  : Truncated string
# Globals  : None
###############################################################################
function str::truncate() {
    local str="${1:-}"
    local max_length="${2:-0}"
    local suffix="${3:-}"

    if [[ ${#str} -le ${max_length} ]]; then
        printf '%s\n' "${str}"
    else
        local suffix_len="${#suffix}"
        local content_len=$((max_length - suffix_len))

        if [[ ${content_len} -lt 0 ]]; then
            content_len=0
        fi

        printf '%s\n' "${str:0:${content_len}}${suffix}"
    fi

    return "${PASS}"
}

###############################################################################
# str::in_list
#------------------------------------------------------------------------------
# Purpose  : Check if a value exists in a list/array
# Usage    : str::in_list "needle" "${haystack[@]}"
# Arguments:
#   $1 : Value to search for (required)
#   $@ : Array elements to search in (required)
# Returns  : PASS (0) if found, FAIL (1) otherwise
###############################################################################
function str::in_list() {
    local needle="${1:-}"
    shift
    local item
    for item in "$@"; do
        [[ "${needle}" == "${item}" ]] && return "${PASS}"
    done
    return "${FAIL}"
}

#===============================================================================
# Self-Test
#===============================================================================

###############################################################################
# str::self_test
#------------------------------------------------------------------------------
# Purpose  : Self-test for util_str.sh functionality
# Usage    : str::self_test
# Returns  : PASS (0) if all tests pass, FAIL (1) otherwise
# Globals  : None
###############################################################################
function str::self_test() {
    info "Running util_str.sh self-test..."

    local status="${PASS}"

    # Test 1: str::length
    local len
    len=$(str::length "hello")
    if [[ "${len}" -ne 5 ]]; then
        fail "str::length failed: expected 5, got ${len}"
        status="${FAIL}"
    fi

    # Test 2: str::is_empty
    if ! str::is_empty ""; then
        fail "str::is_empty failed on empty string"
        status="${FAIL}"
    fi

    if str::is_empty "test"; then
        fail "str::is_empty failed on non-empty string"
        status="${FAIL}"
    fi

    # Test 3: str::to_upper
    local upper
    upper=$(str::to_upper "hello")
    if [[ "${upper}" != "HELLO" ]]; then
        fail "str::to_upper failed: expected HELLO, got ${upper}"
        status="${FAIL}"
    fi

    # Test 4: str::to_lower
    local lower
    lower=$(str::to_lower "HELLO")
    if [[ "${lower}" != "hello" ]]; then
        fail "str::to_lower failed: expected hello, got ${lower}"
        status="${FAIL}"
    fi

    # Test 5: str::trim
    local trimmed
    trimmed=$(str::trim "  hello  ")
    if [[ "${trimmed}" != "hello" ]]; then
        fail "str::trim failed: expected 'hello', got '${trimmed}'"
        status="${FAIL}"
    fi

    # Test 6: str::contains
    if ! str::contains "hello world" "world"; then
        fail "str::contains failed to find 'world'"
        status="${FAIL}"
    fi

    # Test 7: str::replace_all
    local replaced
    replaced=$(str::replace_all "hello hello" "hello" "hi")
    if [[ "${replaced}" != "hi hi" ]]; then
        fail "str::replace_all failed: expected 'hi hi', got '${replaced}'"
        status="${FAIL}"
    fi

    # Test 8: str::is_integer
    if ! str::is_integer "-42"; then
        fail "str::is_integer failed on '-42'"
        status="${FAIL}"
    fi

    if str::is_integer "abc"; then
        fail "str::is_integer incorrectly passed 'abc'"
        status="${FAIL}"
    fi

    # Test 9: str::split
    local -a arr
    str::split "a,b,c" "," arr
    if [[ "${#arr[@]}" -ne 3 ]]; then
        fail "str::split failed: expected 3 elements, got ${#arr[@]}"
        status="${FAIL}"
    fi

    # Test 10: str::join
    local joined
    joined=$(str::join "," "a" "b" "c")
    if [[ "${joined}" != "a,b,c" ]]; then
        fail "str::join failed: expected 'a,b,c', got '${joined}'"
        status="${FAIL}"
    fi

    if [[ "${status}" -eq "${PASS}" ]]; then
        pass "util_str.sh self-test passed"
    else
        fail "util_str.sh self-test failed"
    fi

    return "${status}"
}
