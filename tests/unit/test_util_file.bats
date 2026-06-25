#!/usr/bin/env bats
###############################################################################
# test_util_file.bats - Unit tests for lib/utils/util_file.sh
###############################################################################

setup() {
    load "${BATS_TEST_DIRNAME}/../helpers/load_lib.bash"
    # Use /tmp explicitly: macOS's default $TMPDIR resolves under /var/folders/,
    # which file::_is_safe_path rejects as a system path.
    TEST_TMP="$(mktemp -d "/tmp/bats_util_file.XXXXXX")"
    export TEST_TMP
}

teardown() {
    if [[ -n "${TEST_TMP:-}" && -d "${TEST_TMP}" ]]; then
        rm -rf "${TEST_TMP}"
    fi
}

#===============================================================================
# Existence / permission checks
#===============================================================================

@test "file::exists true for existing file" {
    local f="${TEST_TMP}/exists.txt"
    : > "${f}"
    run file::exists "${f}"
    [[ "${status}" -eq 0 ]]
}

@test "file::exists false for missing file" {
    run file::exists "${TEST_TMP}/nope.txt"
    [[ "${status}" -ne 0 ]]
}

@test "file::exists fails with empty argument" {
    run file::exists ""
    [[ "${status}" -ne 0 ]]
}

@test "file::is_readable true for readable file" {
    local f="${TEST_TMP}/readme.txt"
    : > "${f}"
    chmod 0644 "${f}"
    run file::is_readable "${f}"
    [[ "${status}" -eq 0 ]]
}

@test "file::is_writable true for writable file" {
    local f="${TEST_TMP}/write.txt"
    : > "${f}"
    chmod 0644 "${f}"
    run file::is_writable "${f}"
    [[ "${status}" -eq 0 ]]
}

@test "file::is_executable true for executable file" {
    local f="${TEST_TMP}/exe.sh"
    : > "${f}"
    chmod 0755 "${f}"
    run file::is_executable "${f}"
    [[ "${status}" -eq 0 ]]
}

@test "file::is_executable false for non-executable file" {
    local f="${TEST_TMP}/noexe.txt"
    : > "${f}"
    chmod 0644 "${f}"
    run file::is_executable "${f}"
    [[ "${status}" -ne 0 ]]
}

#===============================================================================
# Content predicates
#===============================================================================

@test "file::is_non_empty true for file with content" {
    local f="${TEST_TMP}/content.txt"
    echo "hello" > "${f}"
    run file::is_non_empty "${f}"
    [[ "${status}" -eq 0 ]]
}

@test "file::is_non_empty false for empty file" {
    local f="${TEST_TMP}/empty.txt"
    : > "${f}"
    run file::is_non_empty "${f}"
    [[ "${status}" -ne 0 ]]
}

#===============================================================================
# Path component helpers
#===============================================================================

@test "file::get_extension returns extension" {
    run file::get_extension "document.txt"
    [[ "${output}" == "txt" ]]
}

@test "file::get_extension returns empty for no extension" {
    run file::get_extension "no_extension_here"
    [[ "${output}" == "" ]]
}

@test "file::get_basename strips directory" {
    run file::get_basename "/path/to/file.txt"
    [[ "${output}" == "file.txt" ]]
}

@test "file::get_dirname strips filename" {
    run file::get_dirname "/path/to/file.txt"
    [[ "${output}" == "/path/to" ]]
}

#===============================================================================
# Mutation operations
#===============================================================================

@test "file::touch creates missing file" {
    local f="${TEST_TMP}/touched.txt"
    run file::touch "${f}"
    [[ "${status}" -eq 0 ]]
    [[ -f "${f}" ]]
}

@test "file::append appends to file" {
    local f="${TEST_TMP}/append.txt"
    file::touch "${f}" > /dev/null
    file::append "${f}" "line1" > /dev/null
    file::append "${f}" "line2" > /dev/null
    [[ "$(wc -l < "${f}")" -eq 2 ]]
    run grep -c "line1" "${f}"
    [[ "${output}" == "1" ]]
}

@test "file::copy copies file content" {
    local src="${TEST_TMP}/src.txt"
    local dst="${TEST_TMP}/dst.txt"
    echo "payload" > "${src}"
    run file::copy "${src}" "${dst}"
    [[ "${status}" -eq 0 ]]
    [[ -f "${dst}" ]]
    [[ "$(cat "${dst}")" == "payload" ]]
}

@test "file::delete removes file" {
    local f="${TEST_TMP}/doomed.txt"
    : > "${f}"
    [[ -f "${f}" ]]
    run file::delete "${f}"
    [[ "${status}" -eq 0 ]]
    [[ ! -f "${f}" ]]
}

@test "file::mktemp returns a path to an existing file" {
    local f
    f="$(file::mktemp)"
    [[ -n "${f}" ]]
    [[ -f "${f}" ]]
    rm -f "${f}"
}
