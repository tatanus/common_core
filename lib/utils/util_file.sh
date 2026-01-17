#!/usr/bin/env bash
###############################################################################
# NAME         : util_file.sh
# DESCRIPTION  : File operations, safety checks, and manipulation utilities.
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-10-27
###############################################################################
# EDIT HISTORY:
# DATE        | EDITED BY      | DESCRIPTION
# ------------|----------------|-----------------------------------------------
# 2025-10-27  | Adam Compton   | Initial generation (style-guide compliant)
# 2025-11-20  | Adam Compton   | Merged utils_files.sh, added Home-Safe policy,
#             |                | legacy wrappers, backups, and self-test
# 2025-12-25  | Adam Compton   | Corrected: Removed PASS/FAIL defs, added
#             |                | logging fallbacks, standardized error messages
#             |                | COMPLETE version with all functions
# 2026-01-03  | Adam Compton   | HIGH: Hardened path traversal detection with
#             |                | null byte check, URL-encoding detection, and
#             |                | realpath normalization.
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Library Guard
#===============================================================================
if [[ -n "${UTIL_FILE_SH_LOADED:-}" ]]; then
    if (return 0 2> /dev/null); then
        return 0
    fi
else
    UTIL_FILE_SH_LOADED=1
fi

#===============================================================================
# Module Dependencies
#===============================================================================
if [[ "${UTIL_PLATFORM_SH_LOADED:-0}" -eq 0 ]]; then
    echo "ERROR: util_platform.sh must be loaded before util_file.sh" >&2
    return 1
fi

if [[ "${UTIL_CONFIG_SH_LOADED:-0}" -eq 0 ]]; then
    echo "ERROR: util_config.sh must be loaded before util_file.sh" >&2
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
# file::_is_safe_path
#------------------------------------------------------------------------------
# Purpose  : Enforce "Home-Safe File Policy" for write/modify operations.
# Usage    : file::_is_safe_path "/tmp/foo"
# Arguments:
#   $1 : Path to validate (required)
# Returns  : PASS (0) if path is safe, FAIL (1) if dangerous
# Requires:
#   Functions: error, warn, debug
#   Environment: HOME
# Security : Validates against path traversal, null bytes, URL encoding,
#            symlink escape, and system directory access.
###############################################################################
function file::_is_safe_path() {
    local path="${1:-}"

    # Check if safety checks are enabled
    if ! config::get_bool "file.safe_mode"; then
        debug "file::_is_safe_path: safety checks disabled"
        return "${PASS}"
    fi

    # Empty or whitespace-only
    if [[ -z "${path//[[:space:]]/}" ]]; then
        error "file::_is_safe_path: empty or whitespace path"
        return "${FAIL}"
    fi

    # Note: Null byte check removed - bash variables cannot contain null bytes
    # (they are automatically stripped during variable assignment), so the check
    # was causing false positives without providing actual security benefit.

    # SECURITY FIX: Reject URL-encoded traversal patterns
    # %2e = '.', %2f = '/', %5c = '\'
    local path_lower="${path,,}"
    if [[ "${path_lower}" == *"%2e"* || "${path_lower}" == *"%2f"* || "${path_lower}" == *"%5c"* ]]; then
        error "file::_is_safe_path: URL-encoded characters detected"
        return "${FAIL}"
    fi

    # Normalize simple forms
    if [[ "${path}" == "." ]]; then
        # Current directory allowed
        return "${PASS}"
    fi

    # Resolve HOME for checks
    local home="${HOME:-}"

    # SECURITY FIX: Normalize path using realpath to detect traversal
    local normalized=""
    if command -v realpath > /dev/null 2>&1; then
        # Use realpath -m to handle non-existent paths
        if normalized=$(realpath -m -- "${path}" 2> /dev/null); then
            # Check if normalized path attempts to escape to system directories
            case "${normalized}" in
                "/" | "/home" | "/root" | "/etc" | "/bin" | "/sbin" | "/usr" | "/usr/"* | "/lib" | "/lib64" | "/boot" | "/opt" | "/var" | "/var/"*)
                    error "file::_is_safe_path: normalized to system directory: ${normalized}"
                    return "${FAIL}"
                    ;;
                "${home}" | "${home}/")
                    error "file::_is_safe_path: normalized to HOME directory: ${normalized}"
                    return "${FAIL}"
                    ;;
                *) ;;
            esac
        fi
    fi

    # SECURITY FIX: Check for symlink that points outside allowed areas
    if [[ -L "${path}" ]]; then
        local link_target
        if link_target=$(readlink -f -- "${path}" 2> /dev/null); then
            # Recursive check on the target (but avoid infinite loop)
            if [[ "${link_target}" != "${path}" ]]; then
                debug "file::_is_safe_path: checking symlink target: ${link_target}"
                case "${link_target}" in
                    "/" | "/home" | "/root" | "/etc" | "/bin" | "/sbin" | "/usr" | "/usr/"* | "/lib" | "/lib64" | "/boot" | "/opt" | "/var" | "/var/"*)
                        error "file::_is_safe_path: symlink points to system directory: ${link_target}"
                        return "${FAIL}"
                        ;;
                    *) ;;
                esac
            fi
        fi
    fi

    # Absolute dangerous roots and system locations
    case "${path}" in
        "/" | "/home" | "/root" | "/etc" | "/bin" | "/sbin" | "/usr" | "/usr/"* | "/lib" | "/lib64" | "/boot" | "/opt" | "/var" | "/var/"*)
            error "file::_is_safe_path: sensitive system dir: ${path}"
            return "${FAIL}"
            ;;
        "${home}" | "${home}/")
            error "file::_is_safe_path: HOME directory: ${path}"
            return "${FAIL}"
            ;;
        *) ;;
    esac

    # Paths containing parent traversal
    if [[ "${path}" == *".."* ]]; then
        error "file::_is_safe_path: path traversal detected: ${path}"
        return "${FAIL}"
    fi

    # Otherwise treat as safe
    debug "file::_is_safe_path: path allowed: ${path}"
    return "${PASS}"
}

###############################################################################
# file::_safe_target_pair
#------------------------------------------------------------------------------
# Purpose  : Check that one or two target paths are safe for modification.
# Usage    : file::_safe_target_pair "/tmp/a" "/tmp/b"
# Arguments:
#   $1 : First path (required)
#   $2 : Second path (optional)
# Returns  : PASS (0) if all provided targets are safe, FAIL (1) otherwise
# Requires:
#   Functions: file::_is_safe_path
###############################################################################
function file::_safe_target_pair() {
    local p1="${1:-}"
    local p2="${2:-}"

    file::_is_safe_path "${p1}" || return "${FAIL}"
    if [[ -n "${p2}" ]]; then
        file::_is_safe_path "${p2}" || return "${FAIL}"
    fi

    return "${PASS}"
}

###############################################################################
# file::_rotate_backup
#------------------------------------------------------------------------------
# Purpose  : Rotate an existing file into filename.old-N style.
# Usage    : file::_rotate_backup "/tmp/file.txt"
# Arguments:
#   $1 : File path to rotate (required)
# Returns  : PASS (0) on success or if file doesn't exist, FAIL (1) on error
# Requires:
#   Functions: file::_is_safe_path, pass, fail, debug
###############################################################################
function file::_rotate_backup() {
    local target="${1:-}"

    if [[ ! -e "${target}" ]]; then
        debug "file::_rotate_backup: no existing file to rotate: ${target}"
        return "${PASS}"
    fi

    file::_is_safe_path "${target}" || return "${FAIL}"

    local n=0 backup
    while :; do
        backup="${target}.old-${n}"
        [[ -e "${backup}" ]] || break
        ((n++))
    done

    file::_is_safe_path "${backup}" || return "${FAIL}"

    if mv -- "${target}" "${backup}"; then
        pass "Rotated ${target} -> ${backup}"
        return "${PASS}"
    fi

    fail "file::_rotate_backup: failed to rotate: ${target}"
    return "${FAIL}"
}

###############################################################################
# file::_stat_get_size
#------------------------------------------------------------------------------
# Purpose  : Cross-platform file size retrieval
# Usage    : size=$(file::_stat_get_size "/path/to/file")
# Returns  : Prints size in bytes
###############################################################################
function file::_stat_get_size() {
    local file="${1:-}"
    [[ -z "${file}" || ! -f "${file}" ]] && printf '0\n' && return "${FAIL}"

    # Use platform abstraction
    platform::stat size "${file}" 2> /dev/null || printf '0\n'
}

#===============================================================================
# File Existence and Permissions
#===============================================================================

###############################################################################
# file::exists
#------------------------------------------------------------------------------
# Purpose  : Check if a file exists.
# Usage    : file::exists "/path/to/file"
# Arguments:
#   $1 : File path (required)
# Returns  : PASS (0) if file exists, FAIL (1) otherwise
# Requires:
#   Functions: debug
###############################################################################
function file::exists() {
    local file="${1:-}"
    if [[ -z "${file}" ]]; then
        debug "file::exists: no file path provided"
        return "${FAIL}"
    fi

    if [[ -f "${file}" ]]; then
        debug "File exists: ${file}"
        return "${PASS}"
    fi
    debug "File not found: ${file}"
    return "${FAIL}"
}

###############################################################################
# file::is_readable
#------------------------------------------------------------------------------
# Purpose  : Check if a file is readable.
# Usage    : file::is_readable "/path/to/file"
# Arguments:
#   $1 : File path (required)
# Returns  : PASS (0) if readable, FAIL (1) otherwise
# Requires:
#   Functions: debug, error
###############################################################################
function file::is_readable() {
    local file="${1:-}"
    if [[ -z "${file}" ]]; then
        error "file::is_readable: no file path provided"
        return "${FAIL}"
    fi

    if [[ -r "${file}" ]]; then
        debug "File readable: ${file}"
        return "${PASS}"
    fi
    debug "File not readable: ${file}"
    return "${FAIL}"
}

###############################################################################
# file::is_writable
#------------------------------------------------------------------------------
# Purpose  : Check if a file is writable.
# Usage    : file::is_writable "/path/to/file"
# Arguments:
#   $1 : File path (required)
# Returns  : PASS (0) if writable, FAIL (1) otherwise
# Requires:
#   Functions: debug, error
###############################################################################
function file::is_writable() {
    local file="${1:-}"
    if [[ -z "${file}" ]]; then
        error "file::is_writable: no file path provided"
        return "${FAIL}"
    fi

    if [[ -w "${file}" ]]; then
        debug "File writable: ${file}"
        return "${PASS}"
    fi
    debug "File not writable: ${file}"
    return "${FAIL}"
}

###############################################################################
# file::is_executable
#------------------------------------------------------------------------------
# Purpose  : Check if a file is executable.
# Usage    : file::is_executable "/path/to/file"
# Arguments:
#   $1 : File path (required)
# Returns  : PASS (0) if executable, FAIL (1) otherwise
# Requires:
#   Functions: debug, error
###############################################################################
function file::is_executable() {
    local file="${1:-}"
    if [[ -z "${file}" ]]; then
        error "file::is_executable: no file path provided"
        return "${FAIL}"
    fi

    if [[ -x "${file}" ]]; then
        debug "File executable: ${file}"
        return "${PASS}"
    fi
    debug "File not executable: ${file}"
    return "${FAIL}"
}

#===============================================================================
# File Metadata Operations
#===============================================================================

###############################################################################
# file::get_size
#------------------------------------------------------------------------------
# Purpose  : Get file size in bytes.
# Usage    : size=$(file::get_size "/path/to/file")
# Arguments:
#   $1 : File path (required)
# Returns  : PASS (0) if size obtained, FAIL (1) otherwise
# Outputs  : File size in bytes
# Requires:
#   Functions: file::exists, error, debug
#   Commands: stat
###############################################################################
function file::get_size() {
    local file="${1:-}"
    if [[ -z "${file}" ]]; then
        error "file::get_size: no file path provided"
        printf '0\n'
        return "${FAIL}"
    fi

    if ! file::exists "${file}"; then
        error "file::get_size: file does not exist: ${file}"
        printf '0\n'
        return "${FAIL}"
    fi

    # Use platform abstraction
    local size
    if size=$(platform::stat size "${file}" 2> /dev/null); then
        debug "File size: ${file} = ${size} bytes"
        printf '%s\n' "${size}"
        return "${PASS}"
    fi

    error "file::get_size: failed to get size for ${file}"
    printf '0\n'
    return "${FAIL}"
}

###############################################################################
# file::is_non_empty
#------------------------------------------------------------------------------
# Purpose  : Check if a file exists and is non-empty.
# Usage    : file::is_non_empty "/path/to/file"
# Arguments:
#   $1 : File path (required)
# Returns  : PASS (0) if file exists and size > 0, FAIL (1) otherwise
# Requires:
#   Functions: file::exists, file::get_size, pass, fail, error
###############################################################################
function file::is_non_empty() {
    local file_path="${1:-}"

    if [[ -z "${file_path}" ]]; then
        error "file::is_non_empty: no file path provided"
        return "${FAIL}"
    fi

    if ! file::exists "${file_path}"; then
        fail "file::is_non_empty: file does not exist: ${file_path}"
        return "${FAIL}"
    fi

    local size
    size=$(file::get_size "${file_path}" 2> /dev/null || echo "0")
    if [[ -z "${size}" || "${size}" -le 0 ]]; then
        fail "file::is_non_empty: file is empty: ${file_path}"
        return "${FAIL}"
    fi

    pass "File exists and is non-empty: ${file_path}"
    return "${PASS}"
}

###############################################################################
# file::get_extension
#------------------------------------------------------------------------------
# Purpose  : Get file extension (text after last dot).
# Usage    : ext=$(file::get_extension "/path/file.txt")
# Arguments:
#   $1 : File path (required)
# Returns  : PASS (0) always
# Outputs  : Extension or empty string
###############################################################################
function file::get_extension() {
    local file="${1:-}"
    local ext="${file##*.}"
    [[ "${ext}" == "${file}" ]] && printf '\n' || printf '%s\n' "${ext}"
    return "${PASS}"
}

###############################################################################
# file::get_basename
#------------------------------------------------------------------------------
# Purpose  : Get filename component without directory path.
# Usage    : name=$(file::get_basename "/path/to/file.txt")
# Arguments:
#   $1 : File path (required)
# Returns  : PASS (0) always
# Outputs  : Basename of file
###############################################################################
function file::get_basename() {
    local file="${1:-}"
    printf '%s\n' "$(basename "${file}")"
    return "${PASS}"
}

###############################################################################
# file::get_dirname
#------------------------------------------------------------------------------
# Purpose  : Get directory component of a file path.
# Usage    : dir=$(file::get_dirname "/path/to/file.txt")
# Arguments:
#   $1 : File path (required)
# Returns  : PASS (0) always
# Outputs  : Directory path
###############################################################################
function file::get_dirname() {
    local file="${1:-}"
    printf '%s\n' "$(dirname "${file}")"
    return "${PASS}"
}

###############################################################################
# file::generate_filename
#------------------------------------------------------------------------------
# Purpose  : Generate unique timestamped filename.
# Usage    : fname=$(file::generate_filename "toolname" ["special"])
# Arguments:
#   $1 : Basename (required)
#   $2 : Special tag (optional)
# Returns  : PASS (0) on success, FAIL (1) on error
# Outputs  : Generated filename
# Requires:
#   Functions: debug, fail, error
#   Commands: date, tr
###############################################################################
function file::generate_filename() {
    local basename="${1:-}"
    local special="${2:-}"

    if [[ -z "${basename}" ]]; then
        error "file::generate_filename: basename argument is required"
        return "${FAIL}"
    fi

    local date_time sanitized_basename sanitized_special
    date_time=$(date --utc +"%Y-%m-%d_%H-%M-%S" 2> /dev/null || date -u +"%Y-%m-%d_%H-%M-%S") || {
        fail "file::generate_filename: failed to get current UTC date/time"
        printf '\n'
        return "${FAIL}"
    }

    sanitized_basename=$(printf '%s' "${basename}" | tr -c '[:alnum:]' '_')
    sanitized_special=$(printf '%s' "${special}" | tr -c '[:alnum:]' '_')

    local filename
    if [[ -n "${sanitized_special}" ]]; then
        filename="${sanitized_basename}_${sanitized_special}_${date_time}.tee"
    else
        filename="${sanitized_basename}_${date_time}.tee"
    fi

    debug "Generated filename: ${filename}"
    printf '%s\n' "${filename}"
    return "${PASS}"
}

#===============================================================================
# File Content Manipulation and Backups
#===============================================================================

###############################################################################
# file::backup
#------------------------------------------------------------------------------
# Purpose  : Create a timestamped .bak backup of a file.
# Usage    : file::backup "/path/to/file"
# Arguments:
#   $1 : File path (required)
# Returns  : PASS (0) on success, FAIL (1) on error
# Requires:
#   Functions: file::exists, file::_is_safe_path, cmd::run_silent,
#              info, fail, error
#   Commands: cp, date
###############################################################################
function file::backup() {
    local file="${1:-}"
    if [[ -z "${file}" ]]; then
        error "file::backup: no file path provided"
        return "${FAIL}"
    fi

    if ! file::exists "${file}"; then
        error "file::backup: cannot backup missing file: ${file}"
        return "${FAIL}"
    fi

    file::_is_safe_path "${file}" || return "${FAIL}"

    # Use config for backup suffix
    local suffix
    suffix=$(config::get "file.backup_suffix" ".bak")
    local backup="${file}${suffix}"

    file::_is_safe_path "${backup}" || return "${FAIL}"

    if command -v cmd::run_silent > /dev/null 2>&1; then
        if cmd::run_silent cp -p "${file}" "${backup}"; then
            info "Backup created: ${backup}"
            return "${PASS}"
        fi
    else
        if cp -p "${file}" "${backup}" > /dev/null 2>&1; then
            info "Backup created: ${backup}"
            return "${PASS}"
        fi
    fi

    fail "file::backup: failed to create backup: ${file}"
    return "${FAIL}"
}

###############################################################################
# file::copy
#------------------------------------------------------------------------------
# Purpose  : Copy file with optional backup rotation if destination exists.
# Usage    : file::copy "/src/file" "/dest/file"
# Arguments:
#   $1 : Source file path (required)
#   $2 : Destination file path (required)
# Returns  : PASS (0) on success, FAIL (1) on error
# Requires:
#   Functions: file::_is_safe_path, file::_rotate_backup, cmd::run_silent,
#              pass, fail, error
#   Commands: cp
###############################################################################
function file::copy() {
    local src="${1:-}"
    local dest="${2:-}"

    if [[ -z "${src}" || -z "${dest}" ]]; then
        error "file::copy: usage: <src> <dest>"
        return "${FAIL}"
    fi

    file::_is_safe_path "${dest}" || return "${FAIL}"

    # If destination exists, rotate it
    file::_rotate_backup "${dest}" || return "${FAIL}"

    if command -v cmd::run_silent > /dev/null 2>&1; then
        if cmd::run_silent cp -p "${src}" "${dest}"; then
            pass "Copied: ${src} -> ${dest}"
            return "${PASS}"
        fi
    else
        if cp -p "${src}" "${dest}" > /dev/null 2>&1; then
            pass "Copied: ${src} -> ${dest}"
            return "${PASS}"
        fi
    fi

    fail "file::copy: failed to copy: ${src}"
    return "${FAIL}"
}

###############################################################################
# file::copy_list_from_array
#------------------------------------------------------------------------------
# Purpose  : Copy a list of files from array by name.
# Usage    : file::copy_list_from_array "/src" "/dest" "ARRAY_NAME" ["prefix"] ["suffix"]
# Arguments:
#   $1 : Source root directory (required)
#   $2 : Destination directory (required)
#   $3 : Array variable name (required)
#   $4 : Prefix for destination files (optional)
#   $5 : Suffix for destination files (optional)
# Returns  : PASS (0) if all files copied, FAIL (1) otherwise
# Requires:
#   Functions: file::exists, file::copy, fail, warn, pass, debug, error
###############################################################################
function file::copy_list_from_array() {
    local src_root="${1:-}"
    local dest_dir="${2:-}"
    local array_name="${3:-}"
    local prefix="${4:-}"
    local suffix="${5:-}"

    if [[ -z "${src_root}" || -z "${dest_dir}" || -z "${array_name}" ]]; then
        error "file::copy_list_from_array: usage: <src_root> <dest_dir> <ARRAY_NAME> [prefix] [suffix]"
        return "${FAIL}"
    fi

    if [[ ! -d "${src_root}" ]]; then
        fail "file::copy_list_from_array: source directory not found: ${src_root}"
        return "${FAIL}"
    fi
    if [[ ! -d "${dest_dir}" ]]; then
        fail "file::copy_list_from_array: destination directory not found: ${dest_dir}"
        return "${FAIL}"
    fi

    declare -n names_ref="${array_name}" || {
        warn "file::copy_list_from_array: array not defined or empty: ${array_name}"
        return "${PASS}"
    }

    local name src_path dest_path
    local overall_status="${PASS}"

    for name in "${names_ref[@]}"; do
        [[ -n "${name}" ]] || continue
        src_path="${src_root}/${name}"
        dest_path="${dest_dir}/${prefix}${name}${suffix}"

        if ! file::exists "${src_path}"; then
            warn "file::copy_list_from_array: source file missing: ${src_path}"
            overall_status="${FAIL}"
            continue
        fi

        if file::copy "${src_path}" "${dest_path}"; then
            debug "Copied ${src_path} -> ${dest_path}"
        else
            overall_status="${FAIL}"
        fi
    done

    if [[ "${overall_status}" -eq "${PASS}" ]]; then
        pass "All files copied successfully to ${dest_dir}"
    else
        warn "Some files failed to copy to ${dest_dir}"
    fi

    return "${overall_status}"
}

###############################################################################
# file::move
#------------------------------------------------------------------------------
# Purpose  : Move (rename) a file with Home-Safe checks.
# Usage    : file::move "/src/file" "/dest/file"
# Arguments:
#   $1 : Source file path (required)
#   $2 : Destination file path (required)
# Returns  : PASS (0) on success, FAIL (1) on error
# Requires:
#   Functions: file::_safe_target_pair, cmd::run_silent, pass, fail, error
#   Commands: mv
###############################################################################
function file::move() {
    local src="${1:-}"
    local dest="${2:-}"

    if [[ -z "${src}" || -z "${dest}" ]]; then
        error "file::move: usage: <src> <dest>"
        return "${FAIL}"
    fi

    file::_safe_target_pair "${src}" "${dest}" || return "${FAIL}"

    if command -v cmd::run_silent > /dev/null 2>&1; then
        if cmd::run_silent mv -f "${src}" "${dest}"; then
            pass "Moved: ${src} -> ${dest}"
            return "${PASS}"
        fi
    else
        if mv -f "${src}" "${dest}" > /dev/null 2>&1; then
            pass "Moved: ${src} -> ${dest}"
            return "${PASS}"
        fi
    fi

    fail "file::move: failed to move: ${src}"
    return "${FAIL}"
}

###############################################################################
# file::delete
#------------------------------------------------------------------------------
# Purpose  : Delete a file safely with Home-Safe enforcement.
# Usage    : file::delete "/path/to/file"
# Arguments:
#   $1 : File path (required)
# Returns  : PASS (0) if deleted or file missing, FAIL (1) on error
# Requires:
#   Functions: file::exists, file::_is_safe_path, cmd::run_silent,
#              pass, warn, fail, error
#   Commands: rm
###############################################################################
function file::delete() {
    local file="${1:-}"

    if [[ -z "${file}" ]]; then
        error "file::delete: no file path provided"
        return "${FAIL}"
    fi

    if ! file::exists "${file}"; then
        warn "File not found, skipping delete: ${file}"
        return "${PASS}"
    fi

    file::_is_safe_path "${file}" || return "${FAIL}"

    if command -v cmd::run_silent > /dev/null 2>&1; then
        if cmd::run_silent rm -f "${file}"; then
            pass "Deleted: ${file}"
            return "${PASS}"
        fi
    else
        if rm -f "${file}" > /dev/null 2>&1; then
            pass "Deleted: ${file}"
            return "${PASS}"
        fi
    fi

    fail "file::delete: failed to delete: ${file}"
    return "${FAIL}"
}

###############################################################################
# file::touch
#------------------------------------------------------------------------------
# Purpose  : Create file if it doesn't exist (or update mtime).
# Usage    : file::touch "/path/to/file"
# Arguments:
#   $1 : File path (required)
# Returns  : PASS (0) on success, FAIL (1) on error
# Requires:
#   Functions: file::_is_safe_path, cmd::run_silent, pass, fail, error
#   Commands: touch
###############################################################################
function file::touch() {
    local file="${1:-}"

    if [[ -z "${file}" ]]; then
        error "file::touch: no file path provided"
        return "${FAIL}"
    fi

    file::_is_safe_path "${file}" || return "${FAIL}"

    if command -v cmd::run_silent > /dev/null 2>&1; then
        if cmd::run_silent touch "${file}"; then
            pass "Touched: ${file}"
            return "${PASS}"
        fi
    else
        if touch "${file}" > /dev/null 2>&1; then
            pass "Touched: ${file}"
            return "${PASS}"
        fi
    fi

    fail "file::touch: failed to touch: ${file}"
    return "${FAIL}"
}

###############################################################################
# file::append
#------------------------------------------------------------------------------
# Purpose  : Append content to a file.
# Usage    : file::append "/path/to/file" "content"
# Arguments:
#   $1 : File path (required)
#   $2 : Content to append (required)
# Returns  : PASS (0) on success, FAIL (1) on error
# Requires:
#   Functions: file::_is_safe_path, fail, error, pass
###############################################################################
function file::append() {
    local file="${1:-}"
    local content="${2:-}"

    if [[ -z "${file}" ]]; then
        error "file::append: no file path provided"
        return "${FAIL}"
    fi

    file::_is_safe_path "${file}" || return "${FAIL}"

    printf '%s\n' "${content}" >> "${file}" || {
        fail "file::append: failed to append to ${file}"
        return "${FAIL}"
    }

    pass "Appended to: ${file}"
    return "${PASS}"
}

###############################################################################
# file::mktemp
#------------------------------------------------------------------------------
# Purpose  : Create a temporary file and print its path.
# Usage    : tmp=$(file::mktemp ["/tmp/foo.XXXXXX"])
# Arguments:
#   $1 : Template pattern (optional, default: /tmp/file.XXXXXX)
# Returns  : PASS (0) on success, FAIL (1) on failure
# Outputs  : Path to temporary file
# Requires:
#   Functions: fail
#   Commands: mktemp
###############################################################################
function file::mktemp() {
    local template="${1:-/tmp/file.XXXXXX}"
    local tmp=""

    # Use platform abstraction
    if ! tmp="$(platform::mktemp "${template}" 2> /dev/null)"; then
        fail "file::mktemp: failed to create temporary file using template '${template}'"
        return "${FAIL}"
    fi

    printf '%s\n' "${tmp}"
    return "${PASS}"
}

###############################################################################
# file::prepend
#------------------------------------------------------------------------------
# Purpose  : Prepend content to a file.
# Usage    : file::prepend "/path/to/file" "content"
# Arguments:
#   $1 : File path (required)
#   $2 : Content to prepend (required)
# Returns  : PASS (0) on success, FAIL (1) on error
# Requires:
#   Functions: file::exists, file::_is_safe_path, file::mktemp,
#              pass, fail, error
#   Commands: cat, mv
###############################################################################
function file::prepend() {
    local file="${1:-}"
    local content="${2:-}"

    if [[ -z "${file}" ]]; then
        fail "file::prepend: no file specified"
        return "${FAIL}"
    fi
    if ! file::exists "${file}"; then
        fail "file::prepend: file does not exist: ${file}"
        return "${FAIL}"
    fi

    local tmp=""
    if ! tmp="$(file::mktemp "/tmp/file_prepend.XXXXXX")"; then
        fail "file::prepend: failed to create temporary file"
        return "${FAIL}"
    fi

    {
        printf '%s' "${content}"
        cat "${file}"
    } > "${tmp}"

    if ! mv "${tmp}" "${file}"; then
        fail "file::prepend: failed to move temporary file into place for ${file}"
        rm -f "${tmp}"
        return "${FAIL}"
    fi

    pass "Prepended content to ${file}"
    return "${PASS}"
}

###############################################################################
# file::replace_line
#------------------------------------------------------------------------------
# Purpose  : Replace occurrences of a pattern with new content (global).
# Usage    : file::replace_line "/path/to/file" "pattern" "new content"
# Arguments:
#   $1 : File path (required)
#   $2 : Pattern to replace (required)
#   $3 : New content (required)
# Returns  : PASS (0) if replacement succeeds, FAIL (1) otherwise
# Requires:
#   Functions: file::exists, file::_is_safe_path, fail, pass, error
#   Commands: sed
###############################################################################
function file::replace_line() {
    local file="${1:-}"
    local pattern="${2:-}"
    local new="${3:-}"

    if [[ -z "${file}" ]]; then
        error "file::replace_line: no file path provided"
        return "${FAIL}"
    fi

    if ! file::exists "${file}"; then
        error "file::replace_line: file does not exist: ${file}"
        return "${FAIL}"
    fi
    if [[ -z "${pattern}" ]]; then
        error "file::replace_line: requires a pattern"
        return "${FAIL}"
    fi

    file::_is_safe_path "${file}" || return "${FAIL}"

    # Use platform abstraction for sed
    if platform::sed_inplace "s|${pattern}|${new}|g" "${file}"; then
        pass "Replaced line(s) in ${file}"
        return "${PASS}"
    fi

    fail "file::replace_line: failed to replace line(s) in ${file}"
    return "${FAIL}"
}

###############################################################################
# file::replace_env_vars
#------------------------------------------------------------------------------
# Purpose  : Replace placeholders (--VAR_NAME--) with env variable values.
# Usage    : file::replace_env_vars "/path/to/file"
# Arguments:
#   $1 : File path (required)
# Returns  : PASS (0) if all replacements succeed, FAIL (1) otherwise
# Requires:
#   Functions: file::is_readable, file::is_writable, file::replace_line,
#              file::_is_safe_path, info, warn, fail, debug, error
#   Commands: grep
###############################################################################
function file::replace_env_vars() {
    local file_path="${1:-}"

    if [[ -z "${file_path}" ]]; then
        error "file::replace_env_vars: no file path provided"
        return "${FAIL}"
    fi

    if ! file::is_readable "${file_path}" || ! file::is_writable "${file_path}"; then
        fail "file::replace_env_vars: file not accessible for modification: ${file_path}"
        return "${FAIL}"
    fi

    file::_is_safe_path "${file_path}" || return "${FAIL}"

    local placeholders
    placeholders=$(grep -oE -- "--[A-Z0-9_]+--" "${file_path}" 2> /dev/null | sort -u || true)

    if [[ -z "${placeholders}" ]]; then
        info "No placeholders found in: ${file_path}"
        return "${PASS}"
    fi

    local status="${PASS}" placeholder var_name

    for placeholder in ${placeholders}; do
        var_name="${placeholder//--/}"

        if [[ -z "${!var_name:-}" ]]; then
            warn "file::replace_env_vars: skipping replacement: environment variable '${var_name}' not set"
            status="${FAIL}"
            continue
        fi

        if file::replace_line "${file_path}" "${placeholder}" "${!var_name}"; then
            debug "Replaced ${placeholder} -> ${!var_name}"
        else
            fail "file::replace_env_vars: replacement failed for ${placeholder} in ${file_path}"
            status="${FAIL}"
        fi
    done

    if [[ "${status}" -eq "${PASS}" ]]; then
        pass "All environment placeholders replaced in: ${file_path}"
    else
        warn "Some placeholders were skipped or failed in: ${file_path}"
    fi

    return "${status}"
}

###############################################################################
# file::contains
#------------------------------------------------------------------------------
# Purpose  : Check if file contains a string or pattern.
# Usage    : file::contains "/path/to/file" "pattern"
# Arguments:
#   $1 : File path (required)
#   $2 : Pattern to search (required)
# Returns  : PASS (0) if found, FAIL (1) otherwise
# Requires:
#   Functions: debug, error
#   Commands: grep
###############################################################################
function file::contains() {
    local file="${1:-}"
    local pattern="${2:-}"

    if [[ -z "${file}" || -z "${pattern}" ]]; then
        error "file::contains: usage: <file> <pattern>"
        return "${FAIL}"
    fi

    if grep -q "${pattern}" "${file}" 2> /dev/null; then
        debug "Pattern found in: ${file}"
        return "${PASS}"
    fi
    debug "Pattern not found in: ${file}"
    return "${FAIL}"
}

###############################################################################
# file::count_lines
#------------------------------------------------------------------------------
# Purpose  : Count the number of lines in a file.
# Usage    : count=$(file::count_lines "/path/to/file")
# Arguments:
#   $1 : File path (required)
# Returns  : PASS (0) if count printed, FAIL (1) if file missing
# Outputs  : Line count
# Requires:
#   Functions: file::exists, error
#   Commands: wc
###############################################################################
function file::count_lines() {
    local file="${1:-}"
    if [[ -z "${file}" ]]; then
        error "file::count_lines: no file path provided"
        printf '0\n'
        return "${FAIL}"
    fi

    if ! file::exists "${file}"; then
        printf '0\n'
        return "${FAIL}"
    fi
    local count
    count=$(wc -l < "${file}" | tr -d ' ')
    printf '%s\n' "${count}"
    return "${PASS}"
}

###############################################################################
# file::get_checksum
#------------------------------------------------------------------------------
# Purpose  : Compute a file checksum using specified algorithm.
# Usage    : sum=$(file::get_checksum "/path/to/file" "sha256")
# Arguments:
#   $1 : File path (required)
#   $2 : Algorithm (optional, default: sha256)
# Returns  : PASS (0) if checksum printed, FAIL (1) on error
# Outputs  : Checksum hash
# Requires:
#   Functions: file::exists, cmd::exists, error
#   Commands: <algo>sum (e.g., sha256sum)
###############################################################################
function file::get_checksum() {
    local file="${1:-}"
    local algo="${2:-}"

    # Use config default if not specified
    if [[ -z "${algo}" ]]; then
        algo=$(config::get "file.checksum_algo" "sha256")
    fi

    if [[ -z "${file}" ]]; then
        error "file::get_checksum: no file path provided"
        return "${FAIL}"
    fi

    if ! file::exists "${file}"; then
        error "file::get_checksum: file not found: ${file}"
        return "${FAIL}"
    fi

    # Use platform abstraction
    platform::checksum "${algo}" "${file}"
}

###############################################################################
# file::compare
#------------------------------------------------------------------------------
# Purpose  : Compare two files for byte-for-byte equality.
# Usage    : file::compare "/file1" "/file2"
# Arguments:
#   $1 : First file path (required)
#   $2 : Second file path (required)
# Returns  : PASS (0) if identical, FAIL (1) otherwise
# Requires:
#   Functions: file::exists, pass, fail, error
#   Commands: cmp
###############################################################################
function file::compare() {
    local f1="${1:-}"
    local f2="${2:-}"

    if [[ -z "${f1}" || -z "${f2}" ]]; then
        error "file::compare: usage: <file1> <file2>"
        return "${FAIL}"
    fi

    if ! file::exists "${f1}" || ! file::exists "${f2}"; then
        error "file::compare: one or both files do not exist"
        return "${FAIL}"
    fi

    if cmp -s "${f1}" "${f2}"; then
        pass "Files are identical: ${f1}, ${f2}"
        return "${PASS}"
    fi

    fail "Files differ: ${f1}, ${f2}"
    return "${FAIL}"
}

###############################################################################
# file::restore_old_backup
#------------------------------------------------------------------------------
# Purpose  : Restore the highest-numbered <filename>.old-N backup.
# Usage    : file::restore_old_backup "/path/to/file"
# Arguments:
#   $1 : File path (required)
# Returns  : PASS (0) if restored or no backups exist, FAIL (1) on error
# Requires:
#   Functions: file::_is_safe_path, pass, fail, info, error
#   Commands: ls, sort, mv
###############################################################################
function file::restore_old_backup() {
    local filename="${1:-}"

    if [[ -z "${filename}" ]]; then
        fail "file::restore_old_backup: no filename provided"
        return "${FAIL}"
    fi

    file::_is_safe_path "${filename}" || return "${FAIL}"

    local backups=()
    mapfile -t backups < <(ls "${filename}.old-"* 2> /dev/null || true)

    if [[ ${#backups[@]} -eq 0 ]]; then
        info "No .old-N backups found for ${filename}. Nothing to restore."
        return "${PASS}"
    fi

    local highest_backup
    highest_backup=$(printf "%s\n" "${backups[@]}" | sort -V | tail -n 1)

    file::_is_safe_path "${highest_backup}" || return "${FAIL}"

    if mv "${highest_backup}" "${filename}"; then
        pass "Restored ${highest_backup} to ${filename}"
        return "${PASS}"
    fi

    fail "file::restore_old_backup: failed to restore ${highest_backup} to ${filename}"
    return "${FAIL}"
}

#===============================================================================
# Self-Test
#===============================================================================

###############################################################################
# file::self_test
#------------------------------------------------------------------------------
# Purpose  : Run basic self-tests for util_file.sh functionality.
# Usage    : file::self_test
# Returns  : PASS (0) if all checks pass, FAIL (1) if any test fails
# Requires:
#   Functions: file::*, info, pass, fail
#   Commands: echo
###############################################################################
function file::self_test() {
    info "Running util_file.sh self-test..."

    local tmp base test_file backup_file rc="${PASS}"

    base="util_file_test_$$"
    tmp="/tmp/${base}.txt"

    # Create and test existence
    echo "hello" > "${tmp}" || {
        fail "file::self_test: failed to create test file: ${tmp}"
        return "${FAIL}"
    }

    file::exists "${tmp}" || {
        fail "file::exists failed"
        rc="${FAIL}"
    }
    file::is_non_empty "${tmp}" || {
        fail "file::is_non_empty failed"
        rc="${FAIL}"
    }

    # Backup
    file::backup "${tmp}" || {
        fail "file::backup failed"
        rc="${FAIL}"
    }

    # Append
    file::append "${tmp}" "world" || {
        fail "file::append failed"
        rc="${FAIL}"
    }

    # Count lines
    file::count_lines "${tmp}" > /dev/null || {
        fail "file::count_lines failed"
        rc="${FAIL}"
    }

    # Copy and compare
    backup_file="/tmp/${base}_copy.txt"
    file::copy "${tmp}" "${backup_file}" || {
        fail "file::copy failed"
        rc="${FAIL}"
    }
    file::compare "${tmp}" "${backup_file}" || {
        fail "file::compare failed"
        rc="${FAIL}"
    }

    # Cleanup
    file::delete "${tmp}" || {
        fail "file::delete failed on ${tmp}"
        rc="${FAIL}"
    }
    file::delete "${backup_file}" || {
        fail "file::delete failed on ${backup_file}"
        rc="${FAIL}"
    }

    # Clean up any .bak files
    rm -f /tmp/"${base}"*.bak 2> /dev/null || true

    if [[ "${rc}" -eq "${PASS}" ]]; then
        pass "util_file.sh self-test passed."
    else
        fail "util_file.sh self-test encountered failures."
    fi

    return "${rc}"
}
