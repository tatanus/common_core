#!/usr/bin/env bats

###############################################################################
# test_example.bats - Example BATS unit test
#
# This is an example test file to demonstrate BATS testing with proper
# Bash 4+ patterns and style compliance.
#
# NOTE: Delete this file when you add your own tests.
###############################################################################

#===============================================================================
# Setup and Teardown
#===============================================================================

setup() {
    # Create temporary directory for test files
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
}

teardown() {
    # Clean up temporary directory
    if [[ -n "${TEST_TEMP_DIR:-}" ]] && [[ -d "${TEST_TEMP_DIR}" ]]; then
        rm -rf "${TEST_TEMP_DIR}"
    fi
}

#===============================================================================
# Basic Tests
#===============================================================================

@test "example: basic assertion with [[]]" {
    run echo "test"
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "test" ]]
}

@test "example: bash version check (Bash 4+)" {
    run bash --version
    [[ "${status}" -eq 0 ]]

    # Check for Bash 4.0 or higher (required by style guide)
    [[ "${output}" =~ "version 4" ]] || [[ "${output}" =~ "version 5" ]]
}

@test "example: string equality with proper quoting" {
    local str="hello world"
    [[ "${str}" == "hello world" ]]
}

@test "example: string pattern matching" {
    local str="hello world"

    # Pattern matching with [[]]
    [[ "${str}" == *"world"* ]]
    [[ "${str}" != *"foo"* ]]
}

@test "example: arithmetic comparisons with (())" {
    local num=42

    ((num > 0))
    ((num == 42))
    ((num <= 100))
}

@test "example: file operations with safe cleanup" {
    # Create temp file in our temp directory
    local temp_file="${TEST_TEMP_DIR}/test.txt"

    # Write to file with quoted variables
    echo "test content" >"${temp_file}"

    # Verify file exists using [[]]
    [[ -f "${temp_file}" ]]

    # Verify file is readable
    [[ -r "${temp_file}" ]]

    # Verify content
    run cat "${temp_file}"
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == "test content" ]]

    # Cleanup handled by teardown()
}

@test "example: command availability check" {
    # Check that bash is available using command -v
    run command -v bash
    [[ "${status}" -eq 0 ]]
    [[ -n "${output}" ]]
}

@test "example: arithmetic operations with (())" {
    local result

    result=$((2 + 2))
    [[ "${result}" -eq 4 ]]

    result=$((10 - 5))
    [[ "${result}" -eq 5 ]]

    result=$((3 * 4))
    [[ "${result}" -eq 12 ]]
}

@test "example: string operations with Bash 4+ features" {
    local str="hello world"

    # Check string length using ${#var}
    [[ ${#str} -eq 11 ]]

    # Check substring using pattern matching
    [[ "${str}" == *"world"* ]]

    # Check case conversion (Bash 4+)
    local upper="${str^^}"
    [[ "${upper}" == "HELLO WORLD" ]]

    local lower="${upper,,}"
    [[ "${lower}" == "hello world" ]]
}

@test "example: array operations (Bash 4+)" {
    # Declare indexed array
    local -a fruits=("apple" "banana" "cherry")

    # Check array length
    [[ ${#fruits[@]} -eq 3 ]]

    # Access individual elements
    [[ "${fruits[0]}" == "apple" ]]
    [[ "${fruits[1]}" == "banana" ]]
    [[ "${fruits[2]}" == "cherry" ]]

    # Add element
    fruits+=("date")
    [[ ${#fruits[@]} -eq 4 ]]
}

@test "example: associative arrays (Bash 4+)" {
    # Declare associative array
    local -A config=(
        [host]="localhost"
        [port]="8080"
        [debug]="true"
    )

    # Check values
    [[ "${config[host]}" == "localhost" ]]
    [[ "${config[port]}" == "8080" ]]
    [[ "${config[debug]}" == "true" ]]

    # Check if key exists
    [[ -v config[host] ]]
}

@test "example: parameter expansion" {
    local filename="document.txt"

    # Remove extension
    local basename="${filename%.*}"
    [[ "${basename}" == "document" ]]

    # Get extension
    local extension="${filename##*.}"
    [[ "${extension}" == "txt" ]]
}

@test "example: safe command substitution with quotes" {
    # Use $(...) not backticks
    local current_dir
    current_dir="$(pwd)"

    [[ -n "${current_dir}" ]]
    [[ -d "${current_dir}" ]]
}

@test "example: working with temporary files safely" {
    # Create temp file in test directory
    local temp_file="${TEST_TEMP_DIR}/temp_$$"

    # Create file with quoted variable
    touch "${temp_file}"
    [[ -f "${temp_file}" ]]

    # Write data
    printf 'line 1\nline 2\nline 3\n' >"${temp_file}"

    # Read file safely
    local -a lines=()
    while IFS= read -r line; do
        lines+=("${line}")
    done <"${temp_file}"

    [[ ${#lines[@]} -eq 3 ]]
    [[ "${lines[0]}" == "line 1" ]]
    [[ "${lines[2]}" == "line 3" ]]

    # Cleanup handled by teardown()
}
