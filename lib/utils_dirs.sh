#!/usr/bin/env bash
set -uo pipefail

# =============================================================================
# NAME        : utils_dirs.sh
# DESCRIPTION : Utility functions for directories
# AUTHOR      : Adam Compton
# DATE CREATED: 2024-12-15 21:16:38
# =============================================================================
# EDIT HISTORY:
# DATE                 | EDITED BY    | DESCRIPTION OF CHANGE
# ---------------------|--------------|----------------------------------------
# 2024-12-15 21:16:38  | Adam Compton | Initial creation.
# =============================================================================

# Guard to prevent multiple sourcing
if [[ -z "${UTILS_DIRS_SH_LOADED:-}" ]]; then
    declare -g UTILS_DIRS_SH_LOADED=true

    # Push to a directory, creating it if it doesn't exist
    function _pushd() {
        mkdir -p "$1"
        if pushd "$1" > /dev/null 2>&1; then
            return "${_PASS}"
        else
            return "${_FAIL}"
        fi
    }

    # Pop directory from the stack
    function _popd() {
        if popd > /dev/null 2>&1; then
            return "${_PASS}"
        else
            return "${_FAIL}"
        fi
    }

    # Check if a directory exists
    # Usage: check_dir_exists "dir_path"
    function check_dir_exists() {
        local dir_path="$1"

        if [[ -z "${dir_path}" ]]; then
            fail "No directory path provided."
            return "${_PASS}"
        fi

        if [[ -d "${dir_path}" ]]; then
            pass "Directory ${dir_path} exists."
            return "${_PASS}"
        else
            fail "Directory ${dir_path} does not exist."
            return "${_FAIL}"
        fi
    }

    # Check if a directory is readable
    # Usage: check_dir_readable "dir_path"
    function check_dir_readable() {
        local dir_path="$1"

        if [[ -z "${dir_path}" ]]; then
            fail "No directory path provided."
            return "${_PASS}"
        fi

        if [[ -d "${dir_path}" && -r "${dir_path}" ]]; then
            pass "Directory ${dir_path} is readable."
            return "${_PASS}"
        else
            fail "Directory ${dir_path} is not readable."
            return "${_FAIL}"
        fi
    }

    # Check if a directory is writable
    # Usage: check_dir_writable "dir_path"
    function check_dir_writable() {
        local dir_path="$1"

        if [[ -z "${dir_path}" ]]; then
            fail "No directory path provided."
            return "${_PASS}"
        fi

        if [[ -d "${dir_path}" && -w "${dir_path}" ]]; then
            pass "Directory ${dir_path} is writable."
            return "${_PASS}"
        else
            fail "Directory ${dir_path} is not writable."
            return "${_FAIL}"
        fi
    }

    # Ensure one or more directories exist, using check_dir_exists()
    # Usage: ensure_dirs_exist /path/one /path/two ...
    function ensure_dirs_exist() {
        local d rc overall=0
        for d in "$@"; do
            [[ -n "${d}" ]] || continue
            if check_dir_exists "${d}"; then
                info "Directory exists: ${d}"
                continue
            fi
            mkdir -p "${d}"
            rc=$?
            if [[ ${rc} -ne 0 ]]; then
                error "mkdir failed: ${d} (rc=${rc})"
                overall=${rc}
            else
                info "Created directory: ${d}"
            fi
        done
        return "${overall}"
    }
fi
