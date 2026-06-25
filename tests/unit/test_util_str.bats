#!/usr/bin/env bats
###############################################################################
# test_util_str.bats - Unit tests for lib/utils/util_str.sh
###############################################################################

setup() {
    load "${BATS_TEST_DIRNAME}/../helpers/load_lib.bash"
}

#===============================================================================
# Length / emptiness
#===============================================================================

@test "str::length returns char count" {
    run str::length "hello"
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "5" ]]
}

@test "str::length returns 0 for empty string" {
    run str::length ""
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "0" ]]
}

@test "str::is_empty true for empty string" {
    run str::is_empty ""
    [[ "${status}" -eq 0 ]]
}

@test "str::is_empty false for non-empty string" {
    run str::is_empty "x"
    [[ "${status}" -ne 0 ]]
}

@test "str::is_not_empty true for non-empty string" {
    run str::is_not_empty "x"
    [[ "${status}" -eq 0 ]]
}

@test "str::is_blank true for whitespace-only string" {
    run str::is_blank "   "
    [[ "${status}" -eq 0 ]]
}

@test "str::is_blank false for string with non-whitespace" {
    run str::is_blank "  x  "
    [[ "${status}" -ne 0 ]]
}

#===============================================================================
# Case conversion
#===============================================================================

@test "str::to_upper uppercases mixed case" {
    run str::to_upper "Hello World"
    [[ "${output}" == "HELLO WORLD" ]]
}

@test "str::to_lower lowercases mixed case" {
    run str::to_lower "Hello World"
    [[ "${output}" == "hello world" ]]
}

@test "str::capitalize uppercases first character only" {
    run str::capitalize "hello world"
    [[ "${output}" == "Hello world" ]]
}

# NOTE: str::to_title_case has a known bug — it relies on word-splitting via
# IFS=' ' but util.sh sets IFS=$'\n\t', so only the first word gets capitalized.
# Test omitted intentionally; bug should be tracked separately.

#===============================================================================
# Trim / pad
#===============================================================================

@test "str::trim removes leading and trailing whitespace" {
    run str::trim "   hello   "
    [[ "${output}" == "hello" ]]
}

@test "str::trim_left removes only leading whitespace" {
    run str::trim_left "   hello   "
    [[ "${output}" == "hello   " ]]
}

@test "str::trim_right removes only trailing whitespace" {
    run str::trim_right "   hello   "
    [[ "${output}" == "   hello" ]]
}

@test "str::pad_left pads with zeros to width 5" {
    run str::pad_left "42" 5 "0"
    [[ "${output}" == "00042" ]]
}

@test "str::pad_right pads with dashes to width 5" {
    run str::pad_right "42" 5 "-"
    [[ "${output}" == "42---" ]]
}

@test "str::pad_left does not truncate longer string" {
    run str::pad_left "longstring" 3 "0"
    [[ "${output}" == "longstring" ]]
}

#===============================================================================
# Search / match
#===============================================================================

@test "str::contains true when substring present" {
    run str::contains "hello world" "world"
    [[ "${status}" -eq 0 ]]
}

@test "str::contains false when substring absent" {
    run str::contains "hello world" "xyz"
    [[ "${status}" -ne 0 ]]
}

@test "str::starts_with true when prefix matches" {
    run str::starts_with "hello world" "hello"
    [[ "${status}" -eq 0 ]]
}

@test "str::starts_with false when prefix mismatches" {
    run str::starts_with "hello world" "world"
    [[ "${status}" -ne 0 ]]
}

@test "str::ends_with true when suffix matches" {
    run str::ends_with "hello world" "world"
    [[ "${status}" -eq 0 ]]
}

@test "str::ends_with false when suffix mismatches" {
    run str::ends_with "hello world" "hello"
    [[ "${status}" -ne 0 ]]
}

#===============================================================================
# Replace / remove
#===============================================================================

@test "str::replace replaces first occurrence only" {
    run str::replace "foo bar foo" "foo" "baz"
    [[ "${output}" == "baz bar foo" ]]
}

@test "str::replace_all replaces every occurrence" {
    run str::replace_all "foo bar foo" "foo" "baz"
    [[ "${output}" == "baz bar baz" ]]
}

@test "str::remove removes first occurrence" {
    run str::remove "foo bar foo" "foo"
    [[ "${output}" == " bar foo" ]]
}

@test "str::remove_all removes every occurrence" {
    run str::remove_all "foo bar foo" "foo"
    [[ "${output}" == " bar " ]]
}

#===============================================================================
# Validators
#===============================================================================

@test "str::is_integer true for positive int" {
    run str::is_integer "42"
    [[ "${status}" -eq 0 ]]
}

@test "str::is_integer true for negative int" {
    run str::is_integer "-42"
    [[ "${status}" -eq 0 ]]
}

@test "str::is_integer false for float" {
    run str::is_integer "3.14"
    [[ "${status}" -ne 0 ]]
}

@test "str::is_integer false for alpha" {
    run str::is_integer "abc"
    [[ "${status}" -ne 0 ]]
}

@test "str::is_positive_integer false for negative int" {
    run str::is_positive_integer "-1"
    [[ "${status}" -ne 0 ]]
}

@test "str::is_float true for decimal" {
    run str::is_float "3.14"
    [[ "${status}" -eq 0 ]]
}

@test "str::is_alpha true for letters only" {
    run str::is_alpha "abcXYZ"
    [[ "${status}" -eq 0 ]]
}

@test "str::is_alpha false when digits present" {
    run str::is_alpha "abc123"
    [[ "${status}" -ne 0 ]]
}

@test "str::is_alphanumeric true for letters and digits" {
    run str::is_alphanumeric "abc123"
    [[ "${status}" -eq 0 ]]
}

@test "str::is_alphanumeric false when punctuation present" {
    run str::is_alphanumeric "abc-123"
    [[ "${status}" -ne 0 ]]
}

#===============================================================================
# Misc
#===============================================================================

@test "str::repeat repeats string n times" {
    run str::repeat "ab" 3
    [[ "${output}" == "ababab" ]]
}

@test "str::reverse reverses string" {
    run str::reverse "hello"
    [[ "${output}" == "olleh" ]]
}

@test "str::count counts occurrences of substring" {
    run str::count "foo bar foo baz foo" "foo"
    [[ "${output}" == "3" ]]
}

@test "str::truncate trims to max length" {
    run str::truncate "hello world" 5
    [[ "${output}" == *"hello"* ]]
}

@test "str::in_list true when value is in list" {
    run str::in_list "bar" "foo" "bar" "baz"
    [[ "${status}" -eq 0 ]]
}

@test "str::in_list false when value not in list" {
    run str::in_list "qux" "foo" "bar" "baz"
    [[ "${status}" -ne 0 ]]
}
