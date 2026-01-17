#!/usr/bin/env bash
###############################################################################
# NAME         : util_dir.sh
# DESCRIPTION  : Directory operations, management, and cleanup utilities.
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-10-27
###############################################################################
# EDIT HISTORY:
# DATE        | EDITED BY      | DESCRIPTION
# ------------|----------------|-----------------------------------------------
# 2025-10-27  | Adam Compton   | Initial generation (style-guide compliant)
# 2025-11-20  | Adam Compton   | Hardened destructive ops (Home-Safe model),
#             |                | normalized headers, added ensure/rotate/tempdir
#             |                | helpers and self-test.
# 2025-12-25  | Adam Compton   | Corrected: Removed PASS/FAIL defs, added
#             |                | logging fallbacks, standardized error messages
#             |                | COMPLETE version with ALL functions
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Library Guard
#===============================================================================
if [[ -n "${UTIL_DIR_SH_LOADED:-}" ]]; then
    if (return 0 2> /dev/null); then
        return 0
    fi
else
    UTIL_DIR_SH_LOADED=1
fi

#===============================================================================
# Module Dependencies
#===============================================================================
if [[ "${UTIL_PLATFORM_SH_LOADED:-0}" -eq 0 ]]; then
    echo "ERROR: util_platform.sh must be loaded before util_dir.sh" >&2
    return 1
fi

if [[ "${UTIL_CONFIG_SH_LOADED:-0}" -eq 0 ]]; then
    echo "ERROR: util_config.sh must be loaded before util_dir.sh" >&2
    return 1
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
# Global Constants (imported from util.sh)
#===============================================================================
: "${PASS:=0}"
: "${FAIL:=1}"

#===============================================================================
# Internal Helpers
#===============================================================================

###############################################################################
# _dir_is_unsafe_target
#------------------------------------------------------------------------------
# Purpose  : Determine if a directory path is unsafe for destructive operations
#            under the Home-Safe model. This prevents accidental modification
#            of critical system directories.
# Usage    : _dir_is_unsafe_target "/path"
# Arguments:
#   $1 : Directory path (required)
# Returns  : PASS (0) if path is unsafe, FAIL (1) if path is safe
# Requires:
#   Functions: debug
#   Environment: HOME
###############################################################################
function _dir_is_unsafe_target() {
    local dir="${1:-}"

    # Check if safety checks are enabled
    if ! config::get_bool "dir.safe_mode"; then
        debug "_dir_is_unsafe_target: safety checks disabled"
        return "${FAIL}" # Return FAIL = safe to proceed
    fi

    # Empty or whitespace-only
    if [[ -z "${dir//[[:space:]]/}" ]]; then
        debug "_dir_is_unsafe_target: empty/whitespace path"
        return "${PASS}"
    fi

    # Normalize simple forms
    if [[ "${dir}" == "." ]]; then
        # Current directory allowed
        return "${FAIL}"
    fi

    # Resolve HOME for checks
    local home="${HOME:-}"

    # Absolute dangerous roots and system locations
    case "${dir}" in
        "/" | "/home" | "/root" | "/etc" | "/bin" | "/sbin" | "/usr" | "/usr/"* | "/lib" | "/lib64" | "/boot" | "/opt" | "/var" | "/var/"*)
            debug "_dir_is_unsafe_target: sensitive system dir: ${dir}"
            return "${PASS}"
            ;;
        "${home}" | "${home}/")
            debug "_dir_is_unsafe_target: HOME directory: ${dir}"
            return "${PASS}"
            ;;
        *) ;;
    esac

    # Paths containing parent traversal
    if [[ "${dir}" == *".."* ]]; then
        debug "_dir_is_unsafe_target: contains '..': ${dir}"
        return "${PASS}"
    fi

    # Otherwise treat as safe
    return "${FAIL}"
}

#===============================================================================
# Directory Existence and Validation
#===============================================================================

###############################################################################
# dir::exists
#------------------------------------------------------------------------------
# Purpose  : Check if one or more directories exist.
# Usage    : dir::exists "/path/to/dir1" ["/path/to/dir2" ...]
# Arguments:
#   $@ : Directory paths (required)
# Returns  : PASS (0) if all directories exist, FAIL (1) if any missing
# Requires:
#   Functions: error, warn, debug
###############################################################################
function dir::exists() {
    if [[ "$#" -eq 0 ]]; then
        error "dir::exists: requires at least one directory argument"
        return "${FAIL}"
    fi

    local dir
    local overall_status="${PASS}"

    for dir in "$@"; do
        if [[ -d "${dir}" ]]; then
            debug "Directory exists: ${dir}"
        else
            warn "Directory not found: ${dir}"
            overall_status="${FAIL}"
        fi
    done

    return "${overall_status}"
}

###############################################################################
# dir::is_readable
#------------------------------------------------------------------------------
# Purpose  : Check if one or more directories are readable.
# Usage    : dir::is_readable "/path/to/dir1" ["/path/to/dir2" ...]
# Arguments:
#   $@ : Directory paths (required)
# Returns  : PASS (0) if all readable, FAIL (1) if any unreadable
# Requires:
#   Functions: dir::exists, error, warn, fail, debug
###############################################################################
function dir::is_readable() {
    if [[ "$#" -eq 0 ]]; then
        error "dir::is_readable: requires at least one directory argument"
        return "${FAIL}"
    fi

    local dir
    local overall_status="${PASS}"

    for dir in "$@"; do
        if ! dir::exists "${dir}"; then
            warn "Skipping non-existent directory: ${dir}"
            overall_status="${FAIL}"
            continue
        fi

        if [[ -r "${dir}" ]]; then
            debug "Directory readable: ${dir}"
        else
            fail "Directory not readable: ${dir}"
            overall_status="${FAIL}"
        fi
    done

    return "${overall_status}"
}

###############################################################################
# dir::is_writable
#------------------------------------------------------------------------------
# Purpose  : Check if one or more directories are writable.
# Usage    : dir::is_writable "/path/to/dir1" ["/path/to/dir2" ...]
# Arguments:
#   $@ : Directory paths (required)
# Returns  : PASS (0) if all writable, FAIL (1) if any unwritable
# Requires:
#   Functions: dir::exists, error, warn, fail, debug
###############################################################################
function dir::is_writable() {
    if [[ "$#" -eq 0 ]]; then
        error "dir::is_writable: requires at least one directory argument"
        return "${FAIL}"
    fi

    local dir
    local overall_status="${PASS}"

    for dir in "$@"; do
        if ! dir::exists "${dir}"; then
            warn "Skipping non-existent directory: ${dir}"
            overall_status="${FAIL}"
            continue
        fi

        if [[ -w "${dir}" ]]; then
            debug "Directory writable: ${dir}"
        else
            fail "Directory not writable: ${dir}"
            overall_status="${FAIL}"
        fi
    done

    return "${overall_status}"
}

###############################################################################
# dir::is_empty
#------------------------------------------------------------------------------
# Purpose  : Check if a directory is empty (contains no files or subdirectories).
# Usage    : dir::is_empty "/path/to/dir"
# Arguments:
#   $1 : Directory path (required)
# Returns  : PASS (0) if empty, FAIL (1) if not empty or missing
# Requires:
#   Functions: dir::exists, error, debug
#   Commands: ls
###############################################################################
function dir::is_empty() {
    local dir="${1:-}"

    if [[ -z "${dir}" ]]; then
        error "dir::is_empty: requires a directory path"
        return "${FAIL}"
    fi
    if ! dir::exists "${dir}"; then
        error "dir::is_empty: directory not found: ${dir}"
        return "${FAIL}"
    fi

    if [[ -z "$(ls -A "${dir}" 2> /dev/null)" ]]; then
        debug "Directory is empty: ${dir}"
        return "${PASS}"
    fi

    debug "Directory not empty: ${dir}"
    return "${FAIL}"
}

#===============================================================================
# Creation and Deletion (Home-Safe model)
#===============================================================================

###############################################################################
# dir::create
#------------------------------------------------------------------------------
# Purpose  : Create a directory and all parents if necessary, with safety checks
#            to avoid creating directories in dangerous system locations.
# Usage    : dir::create "/path/to/dir"
# Arguments:
#   $1 : Directory path (required)
# Returns  : PASS (0) if exists or created, FAIL (1) on error
# Requires:
#   Functions: _dir_is_unsafe_target, cmd::run_silent (optional),
#              error, warn, pass, fail, debug
#   Commands: mkdir
###############################################################################
function dir::create() {
    local dir="${1:-}"

    if [[ -z "${dir}" ]]; then
        error "dir::create: requires a directory path"
        return "${FAIL}"
    fi

    if _dir_is_unsafe_target "${dir}"; then
        fail "dir::create: refusing to create potentially unsafe directory: ${dir}"
        return "${FAIL}"
    fi

    if [[ -d "${dir}" ]]; then
        debug "Directory already exists: ${dir}"
        return "${PASS}"
    fi

    if command -v cmd::run_silent > /dev/null 2>&1; then
        if cmd::run_silent mkdir -p "${dir}"; then
            pass "Directory created: ${dir}"
            return "${PASS}"
        fi
    else
        if mkdir -p "${dir}" > /dev/null 2>&1; then
            pass "Directory created: ${dir}"
            return "${PASS}"
        fi
    fi

    fail "dir::create: failed to create directory: ${dir}"
    return "${FAIL}"
}

###############################################################################
# dir::delete
#------------------------------------------------------------------------------
# Purpose  : Delete a directory recursively with Home-Safe protections to prevent
#            accidental deletion of critical system directories.
# Usage    : dir::delete "/path/to/dir"
# Arguments:
#   $1 : Directory path (required)
# Returns  : PASS (0) if deleted or didn't exist, FAIL (1) on error
# Requires:
#   Functions: dir::exists, _dir_is_unsafe_target, cmd::run_silent (optional),
#              warn, fail, pass, error
#   Commands: rm
###############################################################################
function dir::delete() {
    local dir="${1:-}"

    if [[ -z "${dir}" ]]; then
        error "dir::delete: requires a directory path"
        return "${FAIL}"
    fi

    if ! dir::exists "${dir}"; then
        warn "Directory not found, skipping delete: ${dir}"
        return "${PASS}"
    fi

    if _dir_is_unsafe_target "${dir}"; then
        fail "dir::delete: refusing to delete unsafe directory: ${dir}"
        return "${FAIL}"
    fi

    if command -v cmd::run_silent > /dev/null 2>&1; then
        if cmd::run_silent rm -rf "${dir}"; then
            pass "Deleted directory: ${dir}"
            return "${PASS}"
        fi
    else
        if rm -rf "${dir}" > /dev/null 2>&1; then
            pass "Deleted directory: ${dir}"
            return "${PASS}"
        fi
    fi

    fail "dir::delete: failed to delete directory: ${dir}"
    return "${FAIL}"
}

#===============================================================================
# Basic Directory Operations
#===============================================================================

###############################################################################
# dir::copy
#------------------------------------------------------------------------------
# Purpose  : Copy a directory recursively to a destination, preserving permissions
#            and attributes.
# Usage    : dir::copy "/src/dir" "/dest/dir"
# Arguments:
#   $1 : Source directory (required)
#   $2 : Destination directory (required)
# Returns  : PASS (0) if copy succeeds, FAIL (1) on error
# Requires:
#   Functions: dir::exists, cmd::run_silent (optional), error, pass, fail
#   Commands: cp
###############################################################################
function dir::copy() {
    local src="${1:-}"
    local dest="${2:-}"

    if [[ -z "${src}" || -z "${dest}" ]]; then
        error "dir::copy: usage: <src> <dest>"
        return "${FAIL}"
    fi
    if ! dir::exists "${src}"; then
        error "dir::copy: source directory missing: ${src}"
        return "${FAIL}"
    fi

    if command -v cmd::run_silent > /dev/null 2>&1; then
        if cmd::run_silent cp -a "${src}" "${dest}"; then
            pass "Copied directory: ${src} -> ${dest}"
            return "${PASS}"
        fi
    else
        if cp -a "${src}" "${dest}" > /dev/null 2>&1; then
            pass "Copied directory: ${src} -> ${dest}"
            return "${PASS}"
        fi
    fi

    fail "dir::copy: failed to copy directory: ${src}"
    return "${FAIL}"
}

###############################################################################
# dir::move
#------------------------------------------------------------------------------
# Purpose  : Move or rename a directory.
# Usage    : dir::move "/src" "/dest"
# Arguments:
#   $1 : Source directory (required)
#   $2 : Destination path (required)
# Returns  : PASS (0) if move succeeds, FAIL (1) on error
# Requires:
#   Functions: cmd::run_silent (optional), error, pass, fail
#   Commands: mv
###############################################################################
function dir::move() {
    local src="${1:-}"
    local dest="${2:-}"

    if [[ -z "${src}" || -z "${dest}" ]]; then
        error "dir::move: usage: <src> <dest>"
        return "${FAIL}"
    fi

    if command -v cmd::run_silent > /dev/null 2>&1; then
        if cmd::run_silent mv -f "${src}" "${dest}"; then
            pass "Moved directory: ${src} -> ${dest}"
            return "${PASS}"
        fi
    else
        if mv -f "${src}" "${dest}" > /dev/null 2>&1; then
            pass "Moved directory: ${src} -> ${dest}"
            return "${PASS}"
        fi
    fi

    fail "dir::move: failed to move directory: ${src}"
    return "${FAIL}"
}

#===============================================================================
# Size and Listing
#===============================================================================

###############################################################################
# dir::get_size
#------------------------------------------------------------------------------
# Purpose  : Get the size of a directory in bytes
# Usage    : bytes=$(dir::get_size "/path/to/dir")
# Arguments:
#   $1 : Directory path (required)
# Returns  : PASS on success, FAIL if directory missing or size unavailable
# Outputs  : Size in bytes
# Globals  : None
###############################################################################
function dir::get_size() {
    local dir="${1:-}"

    if [[ -z "${dir}" ]]; then
        error "dir::get_size requires a directory path"
        printf '0\n'
        return "${FAIL}"
    fi
    if ! dir::exists "${dir}"; then
        error "Directory not found: ${dir}"
        printf '0\n'
        return "${FAIL}"
    fi

    local size
    # Use platform-aware du command
    if command -v du > /dev/null 2>&1; then
        if du --version > /dev/null 2>&1; then
            # GNU du (Linux)
            size=$(du -sb "${dir}" 2> /dev/null | awk '{print $1}')
        else
            # BSD du (macOS) - use -k and multiply by 1024
            size=$(du -sk "${dir}" 2> /dev/null | awk '{print $1 * 1024}')
        fi
    else
        error "du command not available"
        printf '0\n'
        return "${FAIL}"
    fi

    if [[ -z "${size}" ]]; then
        error "Failed to determine size for: ${dir}"
        printf '0\n'
        return "${FAIL}"
    fi

    debug "Directory size: ${dir} = ${size} bytes"
    printf '%s\n' "${size}"
    return "${PASS}"
}

###############################################################################
# dir::list_files
#------------------------------------------------------------------------------
# Purpose  : List files in a directory (non-recursive)
# Usage    : dir::list_files "/path/to/dir"
# Arguments:
#   $1 : Directory path (required)
# Returns  : PASS on success, FAIL if directory missing
# Outputs  : File paths (one per line)
# Globals  : None
###############################################################################
function dir::list_files() {
    local dir="${1:-}"

    if [[ -z "${dir}" ]]; then
        error "dir::list_files requires a directory path"
        return "${FAIL}"
    fi
    if ! dir::exists "${dir}"; then
        error "Directory not found: ${dir}"
        return "${FAIL}"
    fi

    find "${dir}" -maxdepth 1 -type f -print
    return "${PASS}"
}

###############################################################################
# dir::list_dirs
#------------------------------------------------------------------------------
# Purpose  : List subdirectories (non-recursive)
# Usage    : dir::list_dirs "/path/to/dir"
# Arguments:
#   $1 : Directory path (required)
# Returns  : PASS on success, FAIL if directory missing
# Outputs  : Directory paths (one per line)
# Globals  : None
###############################################################################
function dir::list_dirs() {
    local dir="${1:-}"

    if [[ -z "${dir}" ]]; then
        error "dir::list_dirs requires a directory path"
        return "${FAIL}"
    fi
    if ! dir::exists "${dir}"; then
        error "Directory not found: ${dir}"
        return "${FAIL}"
    fi

    find "${dir}" -maxdepth 1 -type d ! -path "${dir}" -print
    return "${PASS}"
}

###############################################################################
# dir::find_files
#------------------------------------------------------------------------------
# Purpose  : Find files by pattern recursively under a directory
# Usage    : dir::find_files "/path" "*.log"
# Arguments:
#   $1 : Directory path (required)
#   $2 : File pattern (optional, default: *)
# Returns  : PASS on success, FAIL if directory missing
# Outputs  : Matched file paths
# Globals  : None
###############################################################################
function dir::find_files() {
    local dir="${1:-}"
    local pattern="${2:-*}"

    if [[ -z "${dir}" ]]; then
        error "dir::find_files requires a directory path"
        return "${FAIL}"
    fi
    if ! dir::exists "${dir}"; then
        error "Directory not found: ${dir}"
        return "${FAIL}"
    fi

    find "${dir}" -type f -name "${pattern}" -print
    return "${PASS}"
}

#===============================================================================
# Backups and Cleanup
#===============================================================================

###############################################################################
# dir::backup
#------------------------------------------------------------------------------
# Purpose  : Create a timestamped backup of a directory (copied alongside original)
# Usage    : dir::backup "/path/to/dir"
# Arguments:
#   $1 : Directory path (required)
# Returns  : PASS if backup succeeds, FAIL if directory missing or backup fails
# Globals  : None
###############################################################################
function dir::backup() {
    local dir="${1:-}"

    if [[ -z "${dir}" ]]; then
        error "dir::backup requires a directory path"
        return "${FAIL}"
    fi
    if ! dir::exists "${dir}"; then
        error "Cannot backup missing directory: ${dir}"
        return "${FAIL}"
    fi

    local backup
    backup="${dir}_$(date +%Y%m%d%H%M%S).bak"

    if cmd::run_silent cp -a "${dir}" "${backup}"; then
        pass "Backup created: ${backup}"
        return "${PASS}"
    fi

    fail "Failed to backup directory: ${dir}"
    return "${FAIL}"
}

###############################################################################
# dir::cleanup_old
#------------------------------------------------------------------------------
# Purpose  : Remove files and directories older than N days under a path
# Usage    : dir::cleanup_old "/path/to/dir" "7"
# Arguments:
#   $1 : Directory path (required)
#   $2 : Age threshold in days (required)
# Returns  : PASS if cleanup runs, FAIL on invalid input or missing directory
# Globals  : None
###############################################################################
function dir::cleanup_old() {
    local dir="${1:-}"
    local days="${2:-}"

    if [[ -z "${dir}" || -z "${days}" ]]; then
        error "Usage: dir::cleanup_old <dir> <days>"
        return "${FAIL}"
    fi
    if ! dir::exists "${dir}"; then
        error "Directory not found: ${dir}"
        return "${FAIL}"
    fi

    cmd::run_silent find "${dir}" -mindepth 1 -mtime +"${days}" -exec rm -rf {} +
    pass "Cleaned up items older than ${days} days in ${dir}"
    return "${PASS}"
}

#===============================================================================
# Path Resolution
#===============================================================================

###############################################################################
# dir::get_absolute_path
#------------------------------------------------------------------------------
# Purpose  : Get the absolute path for a directory
# Usage    : abs=$(dir::get_absolute_path "/some/path")
# Arguments:
#   $1 : Directory path (required)
# Returns  : PASS on success, FAIL if directory is invalid
# Outputs  : Absolute path
# Globals  : None
###############################################################################
function dir::get_absolute_path() {
    local dir="${1:-}"

    if [[ -z "${dir}" ]]; then
        error "dir::get_absolute_path requires a directory path"
        return "${FAIL}"
    fi

    if [[ -d "${dir}" ]]; then
        # Use platform abstraction for readlink
        platform::readlink_canonical "${dir}" || (cd "${dir}" && pwd)
        return "${PASS}"
    fi

    error "Invalid directory: ${dir}"
    return "${FAIL}"
}

###############################################################################
# dir::get_relative_path
#------------------------------------------------------------------------------
# Purpose  : Get the relative path from one directory to another
# Usage    : rel=$(dir::get_relative_path "/from" "/to")
# Arguments:
#   $1 : Source directory (required)
#   $2 : Target directory (required)
# Returns  : PASS on success, FAIL on invalid input or failure
# Outputs  : Relative path
# Globals  : None
###############################################################################
function dir::get_relative_path() {
    local from="${1:-}"
    local to="${2:-}"

    if [[ -z "${from}" || -z "${to}" ]]; then
        error "Usage: dir::get_relative_path <from> <to>"
        return "${FAIL}"
    fi

    if ! command -v realpath > /dev/null 2>&1; then
        fail "realpath command not available"
        return "${FAIL}"
    fi

    realpath --relative-to="${from}" "${to}" 2> /dev/null || {
        fail "Failed to compute relative path"
        return "${FAIL}"
    }

    return "${PASS}"
}

#===============================================================================
# Directory Stack and PATH Utilities
#===============================================================================

###############################################################################
# dir::push
#------------------------------------------------------------------------------
# Purpose  : Push a directory onto the directory stack (like pushd)
# Usage    : dir::push "/path/to/dir"
# Arguments:
#   $1 : Directory path (required)
# Returns  : PASS if push succeeds, FAIL otherwise
# Globals  : None
###############################################################################
function dir::push() {
    local dir="${1:-}"

    if [[ -z "${dir}" ]]; then
        error "dir::push requires a directory path"
        return "${FAIL}"
    fi
    if ! dir::exists "${dir}"; then
        error "Invalid directory: ${dir}"
        return "${FAIL}"
    fi

    pushd "${dir}" > /dev/null || {
        fail "Failed to push directory: ${dir}"
        return "${FAIL}"
    }

    debug "Pushed: ${dir}"
    return "${PASS}"
}

###############################################################################
# dir::pop
#------------------------------------------------------------------------------
# Purpose  : Pop a directory from the directory stack (like popd)
# Usage    : dir::pop
# Returns  : PASS if pop succeeds, FAIL otherwise
# Globals  : None
###############################################################################
function dir::pop() {
    popd > /dev/null || {
        fail "Failed to pop directory"
        return "${FAIL}"
    }

    debug "Popped directory stack"
    return "${PASS}"
}

###############################################################################
# dir::in_path
#------------------------------------------------------------------------------
# Check whether a directory is present in the PATH environment variable.
#--------------------
# Usage:
#   if dir::in_path "/usr/local/bin"; then ...
#
# Return Values:
#   PASS (0) if directory is in PATH
#   FAIL (1) otherwise
#--------------------
# Requirements:
#   Functions:
#     - debug
#
#   Environment:
#     - PATH
###############################################################################
function dir::in_path() {
    local dir="${1:-}"

    if [[ -z "${dir}" ]]; then
        debug "dir::in_path called with empty directory"
        return "${FAIL}"
    fi

    if [[ ":${PATH}:" == *":${dir}:"* ]]; then
        debug "Directory in PATH: ${dir}"
        return "${PASS}"
    fi

    debug "Directory not in PATH: ${dir}"
    return "${FAIL}"
}

#===============================================================================
# New Convenience Utilities
#===============================================================================

###############################################################################
# dir::ensure_exists
#------------------------------------------------------------------------------
# Ensure that a directory exists; create it if missing with Home-Safe checks.
#--------------------
# Usage:
#   dir::ensure_exists "/path/to/dir"
#
# Return Values:
#   PASS (0) if directory exists or was created
#   FAIL (1) on invalid/unsafe path or creation failure
#--------------------
# Requirements:
#   Functions:
#     - dir::exists
#     - dir::create
#     - error
###############################################################################
function dir::ensure_exists() {
    local dir="${1:-}"

    if [[ -z "${dir}" ]]; then
        error "dir::ensure_exists requires a directory path"
        return "${FAIL}"
    fi

    if dir::exists "${dir}"; then
        return "${PASS}"
    fi

    dir::create "${dir}"
}

###############################################################################
# dir::ensure_writable
#------------------------------------------------------------------------------
# Ensure that a directory exists and is writable; create it if needed.
#--------------------
# Usage:
#   dir::ensure_writable "/path/to/dir"
#
# Return Values:
#   PASS (0) if directory is writable
#   FAIL (1) on invalid/unsafe path or permission failure
#--------------------
# Requirements:
#   Functions:
#     - dir::ensure_exists
#     - dir::is_writable
#     - error, fail
###############################################################################
function dir::ensure_writable() {
    local dir="${1:-}"

    if [[ -z "${dir}" ]]; then
        error "dir::ensure_writable requires a directory path"
        return "${FAIL}"
    fi

    dir::ensure_exists "${dir}" || return "${FAIL}"

    if dir::is_writable "${dir}"; then
        return "${PASS}"
    fi

    fail "Directory is not writable: ${dir}"
    return "${FAIL}"
}

###############################################################################
# dir::tempdir
#------------------------------------------------------------------------------
# Create a secure temporary directory and print its path.
#--------------------
# Usage:
#   tmpdir=$(dir::tempdir)
#
# Return Values:
#   PASS (0) on success; prints directory path
#   FAIL (1) on failure
#--------------------
# Requirements:
#   Functions:
#     - fail, debug
###############################################################################
function dir::tempdir() {
    local tmp=""

    # Get temp directory from config
    local tmp_dir
    tmp_dir=$(config::get "tmp.dir" "${TMPDIR:-/tmp}")

    # Get temp prefix from config
    local prefix
    prefix=$(config::get "tmp.prefix" "util")

    # Use platform abstraction with config
    if ! tmp="$(platform::mktemp -d "${tmp_dir}/${prefix}_dir.XXXXXX")"; then
        fail "Failed to create temporary directory"
        return "${FAIL}"
    fi

    # Set permissions from config
    local mode
    mode=$(config::get "tmp.mode" "0700")
    chmod "${mode}" "${tmp}" 2> /dev/null || true

    debug "Created temporary directory: ${tmp}"
    printf '%s\n' "${tmp}"
    return "${PASS}"
}

###############################################################################
# dir::empty
#------------------------------------------------------------------------------
# Remove all contents of a directory without removing the directory itself.
#--------------------
# Usage:
#   dir::empty "/path/to/dir"
#
# Return Values:
#   PASS (0) if contents are removed or directory is already empty
#   FAIL (1) on unsafe directory or deletion failure
#--------------------
# Requirements:
#   Functions:
#     - dir::exists
#     - _dir_is_unsafe_target
#     - cmd::run_silent
#     - error, fail, pass
###############################################################################
function dir::empty() {
    local dir="${1:-}"

    if [[ -z "${dir}" ]]; then
        error "dir::empty requires a directory path"
        return "${FAIL}"
    fi
    if ! dir::exists "${dir}"; then
        error "Directory not found: ${dir}"
        return "${FAIL}"
    fi
    if _dir_is_unsafe_target "${dir}"; then
        fail "Refusing to empty unsafe directory: ${dir}"
        return "${FAIL}"
    fi

    # If already empty, nothing to do
    if dir::is_empty "${dir}"; then
        return "${PASS}"
    fi

    # Remove everything inside, but not the directory itself
    if cmd::run_silent rm -rf "${dir}/"* "${dir}"/.[!.]* "${dir}"/..?* 2> /dev/null; then
        pass "Emptied directory: ${dir}"
        return "${PASS}"
    fi

    fail "Failed to empty directory: ${dir}"
    return "${FAIL}"
}

###############################################################################
# dir::rotate
#------------------------------------------------------------------------------
# Rotate backup directories, keeping only the newest N entries matching a
# pattern inside a parent directory.
#--------------------
# Usage:
#   dir::rotate "/backups" "myapp-*" 5
#
# Return Values:
#   PASS (0) on success
#   FAIL (1) on invalid args or failure
#--------------------
# Requirements:
#   Functions:
#     - dir::exists
#     - _dir_is_unsafe_target
#     - cmd::run_silent
#     - error, warn, pass
###############################################################################
function dir::rotate() {
    local parent="${1:-}"
    local pattern="${2:-*}"
    local keep="${3:-}"

    if [[ -z "${parent}" || -z "${keep}" ]]; then
        error "Usage: dir::rotate <parent_dir> <pattern> <keep>"
        return "${FAIL}"
    fi
    if ! dir::exists "${parent}"; then
        error "Parent directory not found: ${parent}"
        return "${FAIL}"
    fi
    if _dir_is_unsafe_target "${parent}"; then
        fail "Refusing to rotate in unsafe directory: ${parent}"
        return "${FAIL}"
    fi
    if ! [[ "${keep}" =~ ^[0-9]+$ ]]; then
        error "Keep value must be a positive integer: ${keep}"
        return "${FAIL}"
    fi

    # shellcheck disable=SC2010
    local entries
    mapfile -t entries < <(ls -1dt "${parent}/${pattern}" 2> /dev/null || true)

    local count="${#entries[@]}"
    if ((count <= keep)); then
        debug "Nothing to rotate in ${parent} (count=${count}, keep=${keep})"
        return "${PASS}"
    fi

    local i
    for ((i = keep; i < count; i++)); do
        local target="${entries[i]}"
        if [[ -e "${target}" ]]; then
            cmd::run_silent rm -rf "${target}" || warn "Failed to remove rotated entry: ${target}"
        fi
    done

    pass "Rotated entries in ${parent}, kept ${keep}, removed $((count - keep))"
    return "${PASS}"
}

###############################################################################
# dir::count_files
#------------------------------------------------------------------------------
# Count the number of files in a directory (non-recursive).
#--------------------
# Usage:
#   num=$(dir::count_files "/path/to/dir")
#
# Return Values:
#   PASS (0) on success; prints count
#   FAIL (1) if directory is missing
#--------------------
# Requirements:
#   Functions:
#     - dir::exists
#     - error
###############################################################################
function dir::count_files() {
    local dir="${1:-}"

    if [[ -z "${dir}" ]]; then
        error "dir::count_files requires a directory path"
        printf '0\n'
        return "${FAIL}"
    fi
    if ! dir::exists "${dir}"; then
        error "Directory not found: ${dir}"
        printf '0\n'
        return "${FAIL}"
    fi

    local count
    count=$(find "${dir}" -maxdepth 1 -type f 2> /dev/null | wc -l | awk '{print $1}')
    printf '%s\n' "${count}"
    return "${PASS}"
}

###############################################################################
# dir::count_dirs
#------------------------------------------------------------------------------
# Count the number of subdirectories in a directory (non-recursive).
#--------------------
# Usage:
#   num=$(dir::count_dirs "/path/to/dir")
#
# Return Values:
#   PASS (0) on success; prints count
#   FAIL (1) if directory is missing
#--------------------
# Requirements:
#   Functions:
#     - dir::exists
#     - error
###############################################################################
function dir::count_dirs() {
    local dir="${1:-}"

    if [[ -z "${dir}" ]]; then
        error "dir::count_dirs requires a directory path"
        printf '0\n'
        return "${FAIL}"
    fi
    if ! dir::exists "${dir}"; then
        error "Directory not found: ${dir}"
        printf '0\n'
        return "${FAIL}"
    fi

    local count
    count=$(find "${dir}" -maxdepth 1 -type d ! -path "${dir}" 2> /dev/null | wc -l | awk '{print $1}')
    printf '%s\n' "${count}"
    return "${PASS}"
}

#===============================================================================
# Self-Test
#===============================================================================

###############################################################################
# dir::self_test
#------------------------------------------------------------------------------
# Run basic self-tests for util_dir.sh to validate core functionality and
# safety behaviors in a temporary area.
#--------------------
# Usage:
#   dir::self_test
#
# Return Values:
#   PASS (0) if tests complete (does not guarantee full correctness)
#   FAIL (1) if critical preconditions fail (e.g., cannot create tmpdir)
#--------------------
# Requirements:
#   Functions:
#     - dir::tempdir
#     - dir::create
#     - dir::ensure_writable
#     - dir::empty
#     - dir::delete
#     - dir::count_files
#     - dir::count_dirs
#     - info, warn, pass, fail
###############################################################################
function dir::self_test() {
    info "Running util_dir.sh self-test..."

    local tmp
    if ! tmp="$(dir::tempdir)"; then
        fail "dir::tempdir failed; aborting self-test"
        return "${FAIL}"
    fi

    # Basic create + ensure_writable
    local testdir="${tmp}/test"
    dir::create "${testdir}" || warn "dir::create failed in self-test"
    dir::ensure_writable "${testdir}" || warn "dir::ensure_writable failed in self-test"

    # Create some files and dirs
    touch "${testdir}/a" "${testdir}/b" 2> /dev/null || true
    mkdir -p "${testdir}/sub1" "${testdir}/sub2" 2> /dev/null || true

    dir::count_files "${testdir}" > /dev/null || warn "dir::count_files failed in self-test"
    dir::count_dirs "${testdir}" > /dev/null || warn "dir::count_dirs failed in self-test"

    # Empty the directory and then delete
    dir::empty "${testdir}" || warn "dir::empty failed in self-test"
    dir::delete "${testdir}" || warn "dir::delete failed in self-test"

    # Clean up temp root
    dir::delete "${tmp}" || warn "Failed to delete temporary self-test dir: ${tmp}"

    pass "util_dir.sh self-test completed."
    return "${PASS}"
}
