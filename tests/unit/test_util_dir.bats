#!/usr/bin/env bats
###############################################################################
# test_util_dir.bats - Unit tests for lib/utils/util_dir.sh
###############################################################################

setup() {
    load "${BATS_TEST_DIRNAME}/../helpers/load_lib.bash"
    # Use /tmp explicitly: macOS's default $TMPDIR resolves under /var/folders/,
    # which dir::create / file::_is_safe_path reject as a system path.
    TEST_TMP="$(mktemp -d "/tmp/bats_util_dir.XXXXXX")"
    export TEST_TMP
}

teardown() {
    if [[ -n "${TEST_TMP:-}" && -d "${TEST_TMP}" ]]; then
        rm -rf "${TEST_TMP}"
    fi
}

#===============================================================================
# Existence
#===============================================================================

@test "dir::exists true for existing dir" {
    run dir::exists "${TEST_TMP}"
    [[ "${status}" -eq 0 ]]
}

@test "dir::exists false for missing dir" {
    run dir::exists "${TEST_TMP}/nope"
    [[ "${status}" -ne 0 ]]
}

@test "dir::exists fails with no argument" {
    run dir::exists
    [[ "${status}" -ne 0 ]]
}

@test "dir::exists true when all arguments exist" {
    mkdir -p "${TEST_TMP}/a" "${TEST_TMP}/b"
    run dir::exists "${TEST_TMP}/a" "${TEST_TMP}/b"
    [[ "${status}" -eq 0 ]]
}

@test "dir::exists false when any argument missing" {
    mkdir -p "${TEST_TMP}/a"
    run dir::exists "${TEST_TMP}/a" "${TEST_TMP}/missing"
    [[ "${status}" -ne 0 ]]
}

#===============================================================================
# Readable / writable / empty
#===============================================================================

@test "dir::is_readable true for readable dir" {
    run dir::is_readable "${TEST_TMP}"
    [[ "${status}" -eq 0 ]]
}

@test "dir::is_writable true for writable dir" {
    run dir::is_writable "${TEST_TMP}"
    [[ "${status}" -eq 0 ]]
}

@test "dir::is_empty true for empty dir" {
    run dir::is_empty "${TEST_TMP}"
    [[ "${status}" -eq 0 ]]
}

@test "dir::is_empty false for non-empty dir" {
    : > "${TEST_TMP}/marker"
    run dir::is_empty "${TEST_TMP}"
    [[ "${status}" -ne 0 ]]
}

#===============================================================================
# Create / delete
#===============================================================================

@test "dir::create makes nested directory" {
    local d="${TEST_TMP}/new/nested/dir"
    run dir::create "${d}"
    [[ "${status}" -eq 0 ]]
    [[ -d "${d}" ]]
}

@test "dir::create succeeds when directory already exists" {
    run dir::create "${TEST_TMP}"
    [[ "${status}" -eq 0 ]]
}

@test "dir::delete removes empty directory" {
    local d="${TEST_TMP}/to_delete"
    mkdir -p "${d}"
    run dir::delete "${d}"
    [[ "${status}" -eq 0 ]]
    [[ ! -d "${d}" ]]
}

@test "dir::delete removes non-empty directory" {
    local d="${TEST_TMP}/non_empty"
    mkdir -p "${d}"
    : > "${d}/file"
    run dir::delete "${d}"
    [[ "${status}" -eq 0 ]]
    [[ ! -d "${d}" ]]
}

#===============================================================================
# Listing
#===============================================================================

@test "dir::list_files lists regular files" {
    : > "${TEST_TMP}/a.txt"
    : > "${TEST_TMP}/b.txt"
    mkdir -p "${TEST_TMP}/subdir"
    run dir::list_files "${TEST_TMP}"
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"a.txt"* ]]
    [[ "${output}" == *"b.txt"* ]]
    [[ "${output}" != *"subdir"* ]]
}

@test "dir::list_dirs lists subdirectories" {
    mkdir -p "${TEST_TMP}/sub1" "${TEST_TMP}/sub2"
    : > "${TEST_TMP}/file.txt"
    run dir::list_dirs "${TEST_TMP}"
    [[ "${status}" -eq 0 ]]
    [[ "${output}" == *"sub1"* ]]
    [[ "${output}" == *"sub2"* ]]
    [[ "${output}" != *"file.txt"* ]]
}
