#!/usr/bin/env bash
###############################################################################
# NAME         : util_platform.sh
# DESCRIPTION  : Platform abstraction layer for OS-specific command variations.
#                Provides normalized interfaces to commands that differ between
#                GNU/Linux, BSD/macOS, and other Unix variants.
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-12-25
###############################################################################
# EDIT HISTORY:
# DATE        | EDITED BY      | DESCRIPTION
# ------------|----------------|-----------------------------------------------
# 2025-12-25  | Adam Compton   | Initial creation - command abstraction layer
# 2025-12-28  | Adam Compton   | Added platform::timeout, platform::dns_flush,
#             |                | platform::network_restart for cross-platform
#             |                | compatibility
# 2026-01-03  | Adam Compton   | MEDIUM: Fixed temp file race condition in
#             |                | self_test using mktemp instead of $$.
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Library Guard (with version check for helper functions)
#===============================================================================
# Version 2 added _platform_get_flag and _platform_get_cmd helpers
readonly _UTIL_PLATFORM_VERSION=2

if [[ -n "${UTIL_PLATFORM_SH_LOADED:-}" ]]; then
    # Check if we have the helper functions (version 2+)
    if declare -F _platform_get_flag &> /dev/null; then
        if (return 0 2> /dev/null); then
            return 0
        fi
    fi
    # Otherwise, continue loading to get the new helpers
fi
UTIL_PLATFORM_SH_LOADED=1

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
# Platform Detection Cache
#===============================================================================
declare -g PLATFORM_OS=""
declare -g PLATFORM_VARIANT="" # gnu, bsd, busybox, etc.
declare -g PLATFORM_INITIALIZED=0

#===============================================================================
# Command Mapping Tables
#===============================================================================
# Maps logical command names to actual binaries
declare -gA PLATFORM_CMD=(
    [sed]=""
    [stat]=""
    [date]=""
    [base64]=""
    [find]=""
    [xargs]=""
    [grep]=""
    [awk]=""
    [readlink]=""
    [md5]=""
    [sha256]=""
    [tar]=""
    [mktemp]=""
    [timeout]=""
)

# Command-specific flag mappings
declare -gA PLATFORM_FLAGS=(
    # stat flags
    [stat_size]=""
    [stat_mtime]=""
    [stat_atime]=""
    [stat_ctime]=""
    [stat_mode]=""

    # date flags
    [date_iso8601]=""
    [date_epoch]=""
    [date_rfc3339]=""

    # sed flags
    [sed_inplace]=""
    [sed_extended]=""

    # readlink flags
    [readlink_canonical]=""

    # find flags
    [find_mindepth]=""
    [find_maxdepth]=""

    # tar flags
    [tar_create]=""
    [tar_extract]=""
    [tar_list]=""
)

#===============================================================================
# Safe Array Access Helpers (for set -u compatibility)
#===============================================================================

###############################################################################
# _platform_get_flag
#------------------------------------------------------------------------------
# Purpose  : Safely get a flag from PLATFORM_FLAGS array (set -u safe)
# Usage    : flag=$(_platform_get_flag "stat_size")
# Arguments:
#   $1 : Key name
# Returns  : PASS if found, FAIL if not found
# Outputs  : Flag value or empty string
###############################################################################
function _platform_get_flag() {
    local key="$1"
    # Use indirect reference to avoid variable expansion issues under set -u
    local -n arr_ref=PLATFORM_FLAGS 2> /dev/null || {
        # Fallback for bash < 4.3 without nameref
        eval 'printf "%s" "${PLATFORM_FLAGS[$key]:-}"'
        return
    }
    printf "%s" "${arr_ref[$key]:-}"
}

###############################################################################
# _platform_get_cmd
#------------------------------------------------------------------------------
# Purpose  : Safely get a command from PLATFORM_CMD array (set -u safe)
# Usage    : cmd=$(_platform_get_cmd "stat" "stat")
# Arguments:
#   $1 : Key name
#   $2 : Default value
# Returns  : PASS always
# Outputs  : Command path or default
###############################################################################
function _platform_get_cmd() {
    local key="$1"
    local default="${2:-}"
    local result=""
    # Use indirect reference to avoid variable expansion issues under set -u
    local -n arr_ref=PLATFORM_CMD 2> /dev/null || {
        # Fallback for bash < 4.3 without nameref
        eval 'result="${PLATFORM_CMD[$key]:-}"'
        if [[ -n "${result}" ]]; then
            printf "%s" "${result}"
        else
            printf "%s" "${default}"
        fi
        return
    }
    result="${arr_ref[$key]:-}"
    if [[ -n "${result}" ]]; then
        printf "%s" "${result}"
    else
        printf "%s" "${default}"
    fi
}

#===============================================================================
# Platform Detection
#===============================================================================

###############################################################################
# platform::detect_os
#------------------------------------------------------------------------------
# Purpose  : Detect operating system type (cached)
# Usage    : platform::detect_os
# Returns  : PASS always; sets PLATFORM_OS
###############################################################################
function platform::detect_os() {
    if [[ -n "${PLATFORM_OS}" ]]; then
        return "${PASS}"
    fi

    local uname_s
    uname_s="$(uname -s 2> /dev/null || echo unknown)"

    case "${uname_s}" in
        Darwin*)
            PLATFORM_OS="macos"
            ;;
        Linux*)
            if [[ -r "/proc/version" ]] && grep -qi "microsoft\|wsl" /proc/version 2> /dev/null; then
                PLATFORM_OS="wsl"
            else
                PLATFORM_OS="linux"
            fi
            ;;
        FreeBSD*)
            PLATFORM_OS="freebsd"
            ;;
        OpenBSD*)
            PLATFORM_OS="openbsd"
            ;;
        NetBSD*)
            PLATFORM_OS="netbsd"
            ;;
        SunOS*)
            PLATFORM_OS="solaris"
            ;;
        CYGWIN* | MINGW* | MSYS*)
            PLATFORM_OS="windows"
            ;;
        *)
            PLATFORM_OS="unknown"
            ;;
    esac

    debug "Detected OS: ${PLATFORM_OS}"
    return "${PASS}"
}

###############################################################################
# platform::detect_variant
#------------------------------------------------------------------------------
# Purpose  : Detect command variant (GNU, BSD, BusyBox, etc.)
# Usage    : platform::detect_variant
# Returns  : PASS always; sets PLATFORM_VARIANT
###############################################################################
function platform::detect_variant() {
    if [[ -n "${PLATFORM_VARIANT}" ]]; then
        return "${PASS}"
    fi

    platform::detect_os

    case "${PLATFORM_OS}" in
        macos | *bsd)
            PLATFORM_VARIANT="bsd"
            ;;
        linux | wsl)
            # Check if using GNU coreutils or BusyBox
            if command -v stat > /dev/null 2>&1; then
                if stat --version 2>&1 | grep -q "GNU"; then
                    PLATFORM_VARIANT="gnu"
                elif stat --version 2>&1 | grep -qi "busybox"; then
                    PLATFORM_VARIANT="busybox"
                else
                    # Assume GNU on Linux
                    PLATFORM_VARIANT="gnu"
                fi
            else
                PLATFORM_VARIANT="gnu"
            fi
            ;;
        solaris)
            PLATFORM_VARIANT="solaris"
            ;;
        *)
            PLATFORM_VARIANT="unknown"
            ;;
    esac

    debug "Detected variant: ${PLATFORM_VARIANT}"
    return "${PASS}"
}

#===============================================================================
# Command Resolution
#===============================================================================

###############################################################################
# platform::find_command
#------------------------------------------------------------------------------
# Purpose  : Find best available version of a command
# Usage    : platform::find_command "sed"
# Arguments:
#   $1 : Command name
#   $2 : Preferred names (space-separated, optional)
# Returns  : PASS if found, FAIL otherwise
# Outputs  : Command path
###############################################################################
function platform::find_command() {
    local cmd="${1:-}"
    local preferred="${2:-}"

    if [[ -z "${cmd}" ]]; then
        error "platform::find_command requires command name"
        return "${FAIL}"
    fi

    # Check preferred names first (e.g., "gsed gnutls-sed")
    if [[ -n "${preferred}" ]]; then
        for pref in ${preferred}; do
            if command -v "${pref}" > /dev/null 2>&1; then
                command -v "${pref}"
                return "${PASS}"
            fi
        done
    fi

    # Fall back to standard name
    if command -v "${cmd}" > /dev/null 2>&1; then
        command -v "${cmd}"
        return "${PASS}"
    fi

    debug "Command not found: ${cmd}"
    return "${FAIL}"
}

###############################################################################
# platform::setup_commands
#------------------------------------------------------------------------------
# Purpose  : Initialize platform-specific command mappings
# Usage    : platform::setup_commands
# Returns  : PASS if successful, FAIL if critical commands missing
###############################################################################
function platform::setup_commands() {
    # FIX: Check array length because arrays are not exported to subshells (e.g. $(...))
    if [[ ${PLATFORM_INITIALIZED} -eq 1 ]] && [[ ${#PLATFORM_CMD[@]} -gt 0 ]]; then
        return "${PASS}"
    fi

    platform::detect_os
    platform::detect_variant

    local status="${PASS}"

    case "${PLATFORM_VARIANT}" in
        gnu)
            PLATFORM_CMD[sed]="$(platform::find_command sed)"
            PLATFORM_CMD[stat]="$(platform::find_command stat)"
            PLATFORM_CMD[date]="$(platform::find_command date)"
            PLATFORM_CMD[base64]="$(platform::find_command base64)"
            PLATFORM_CMD[find]="$(platform::find_command find)"
            PLATFORM_CMD[xargs]="$(platform::find_command xargs)"
            PLATFORM_CMD[grep]="$(platform::find_command grep)"
            PLATFORM_CMD[awk]="$(platform::find_command awk)"
            PLATFORM_CMD[readlink]="$(platform::find_command readlink)"
            PLATFORM_CMD[tar]="$(platform::find_command tar)"
            PLATFORM_CMD[mktemp]="$(platform::find_command mktemp)"
            PLATFORM_CMD[timeout]="$(platform::find_command timeout)"

            # GNU-specific flags
            PLATFORM_FLAGS[stat_size]="-c%s"
            PLATFORM_FLAGS[stat_mtime]="-c%Y"
            PLATFORM_FLAGS[stat_atime]="-c%X"
            PLATFORM_FLAGS[stat_ctime]="-c%Z"
            PLATFORM_FLAGS[stat_mode]="-c%a"
            PLATFORM_FLAGS[date_iso8601]="-Iseconds"
            PLATFORM_FLAGS[date_epoch]="+%s"
            PLATFORM_FLAGS[date_rfc3339]="--rfc-3339=seconds"
            PLATFORM_FLAGS[sed_inplace]="-i"
            PLATFORM_FLAGS[sed_extended]="-E"
            PLATFORM_FLAGS[readlink_canonical]="-f"
            ;;

        bsd)
            # On macOS, prefer GNU versions if installed via Homebrew
            PLATFORM_CMD[sed]="$(platform::find_command sed "gsed")"
            PLATFORM_CMD[stat]="$(platform::find_command stat "gstat")"
            PLATFORM_CMD[date]="$(platform::find_command date "gdate")"
            PLATFORM_CMD[base64]="$(platform::find_command base64 "gbase64")"
            PLATFORM_CMD[find]="$(platform::find_command find "gfind")"
            PLATFORM_CMD[xargs]="$(platform::find_command xargs "gxargs")"
            PLATFORM_CMD[grep]="$(platform::find_command grep "ggrep")"
            PLATFORM_CMD[awk]="$(platform::find_command awk "gawk")"
            PLATFORM_CMD[readlink]="$(platform::find_command readlink "greadlink")"
            PLATFORM_CMD[tar]="$(platform::find_command tar "gtar")"
            PLATFORM_CMD[mktemp]="$(platform::find_command mktemp)"
            PLATFORM_CMD[timeout]="$(platform::find_command timeout "gtimeout")"

            # Determine if we got GNU or BSD versions
            if [[ "${PLATFORM_CMD[stat]}" == *"gstat"* ]] || "${PLATFORM_CMD[stat]}" --version 2>&1 | grep -q "GNU"; then
                # GNU flags
                PLATFORM_FLAGS[stat_size]="-c%s"
                PLATFORM_FLAGS[stat_mtime]="-c%Y"
                PLATFORM_FLAGS[stat_atime]="-c%X"
                PLATFORM_FLAGS[stat_ctime]="-c%Z"
                PLATFORM_FLAGS[stat_mode]="-c%a"
            else
                # BSD flags
                PLATFORM_FLAGS[stat_size]="-f%z"
                PLATFORM_FLAGS[stat_mtime]="-f%m"
                PLATFORM_FLAGS[stat_atime]="-f%a"
                PLATFORM_FLAGS[stat_ctime]="-f%c"
                PLATFORM_FLAGS[stat_mode]="-f%p"
            fi

            if [[ "${PLATFORM_CMD[date]}" == *"gdate"* ]] || "${PLATFORM_CMD[date]}" --version 2>&1 | grep -q "GNU"; then
                # GNU date
                PLATFORM_FLAGS[date_iso8601]="-Iseconds"
                PLATFORM_FLAGS[date_epoch]="+%s"
                PLATFORM_FLAGS[date_rfc3339]="--rfc-3339=seconds"
            else
                # BSD date
                PLATFORM_FLAGS[date_iso8601]="-u +%Y-%m-%dT%H:%M:%S%z"
                PLATFORM_FLAGS[date_epoch]="+%s"
                PLATFORM_FLAGS[date_rfc3339]="-u +%Y-%m-%d %H:%M:%S%z"
            fi

            if [[ "${PLATFORM_CMD[sed]}" == *"gsed"* ]]; then
                PLATFORM_FLAGS[sed_inplace]="-i"
                PLATFORM_FLAGS[sed_extended]="-E"
            else
                PLATFORM_FLAGS[sed_inplace]="-i ''"
                PLATFORM_FLAGS[sed_extended]="-E"
            fi

            if [[ "${PLATFORM_CMD[readlink]}" == *"greadlink"* ]]; then
                PLATFORM_FLAGS[readlink_canonical]="-f"
            else
                # BSD readlink doesn't have -f, need workaround
                PLATFORM_FLAGS[readlink_canonical]=""
            fi
            ;;

        busybox)
            # BusyBox has limited options
            PLATFORM_CMD[sed]="$(platform::find_command sed)"
            PLATFORM_CMD[stat]="$(platform::find_command stat)"
            PLATFORM_CMD[date]="$(platform::find_command date)"
            PLATFORM_CMD[base64]="$(platform::find_command base64)"
            PLATFORM_CMD[find]="$(platform::find_command find)"
            PLATFORM_CMD[xargs]="$(platform::find_command xargs)"
            PLATFORM_CMD[grep]="$(platform::find_command grep)"
            PLATFORM_CMD[awk]="$(platform::find_command awk)"
            PLATFORM_CMD[readlink]="$(platform::find_command readlink)"
            PLATFORM_CMD[tar]="$(platform::find_command tar)"
            PLATFORM_CMD[mktemp]="$(platform::find_command mktemp)"
            PLATFORM_CMD[timeout]="$(platform::find_command timeout)"

            PLATFORM_FLAGS[stat_size]="-c%s"
            PLATFORM_FLAGS[stat_mtime]="-c%Y"
            PLATFORM_FLAGS[date_epoch]="+%s"
            PLATFORM_FLAGS[sed_inplace]="-i"
            PLATFORM_FLAGS[readlink_canonical]="-f"
            ;;

        *)
            warn "Unknown platform variant: ${PLATFORM_VARIANT}"
            status="${FAIL}"
            ;;
    esac

    # Verify critical commands
    local -a critical_cmds=(sed stat date find grep awk)
    for cmd in "${critical_cmds[@]}"; do
        if [[ -z "${PLATFORM_CMD[${cmd}]}" ]]; then
            error "Critical command not found: ${cmd}"
            status="${FAIL}"
        fi
    done

    if [[ ${status} -eq "${PASS}" ]]; then
        PLATFORM_INITIALIZED=1
        pass "Platform commands initialized for ${PLATFORM_VARIANT}"
    else
        fail "Platform initialization failed"
    fi

    return "${status}"
}

#===============================================================================
# Abstracted Command Wrappers
#===============================================================================

###############################################################################
# platform::stat
#------------------------------------------------------------------------------
# Purpose  : Get file statistics in platform-independent way
# Usage    : platform::stat <format> <file>
# Arguments:
#   $1 : Format (size, mtime, atime, ctime, mode)
#   $2 : File path
# Returns  : PASS if successful, FAIL otherwise
# Outputs  : Requested statistic
###############################################################################
function platform::stat() {
    local format="${1:-}"
    local file="${2:-}"

    if [[ -z "${format}" || -z "${file}" ]]; then
        error "Usage: platform::stat <format> <file>"
        return "${FAIL}"
    fi

    if [[ ! -e "${file}" ]]; then
        error "File not found: ${file}"
        return "${FAIL}"
    fi

    platform::setup_commands || return "${FAIL}"

    # FIX: Use helper functions for set -u safe array access
    local flag
    flag="$(_platform_get_flag "stat_${format}")"

    if [[ -z "${flag}" ]]; then
        error "Unknown stat format: ${format}"
        return "${FAIL}"
    fi

    local stat_cmd
    stat_cmd="$(_platform_get_cmd stat stat)"
    "${stat_cmd}" "${flag}" "${file}" 2> /dev/null || {
        error "stat failed for ${file}"
        return "${FAIL}"
    }

    return "${PASS}"
}

###############################################################################
# platform::date
#------------------------------------------------------------------------------
# Purpose  : Format date in platform-independent way
# Usage    : platform::date <format> [epoch_seconds]
# Arguments:
#   $1 : Format (iso8601, epoch, rfc3339, from_epoch, or custom format string)
#   $2 : Epoch seconds (for from_epoch) or optional
# Returns  : PASS if successful, FAIL otherwise
# Outputs  : Formatted date string
###############################################################################
function platform::date() {
    local format="${1:-}"
    local epoch="${2:-}"

    if [[ -z "${format}" ]]; then
        error "Usage: platform::date <format> [epoch]"
        return "${FAIL}"
    fi

    platform::setup_commands || return "${FAIL}"

    # FIX: Use helper function for set -u safe array access
    local date_cmd
    date_cmd="$(_platform_get_cmd date date)"
    local date_args=()

    # Handle special 'from_epoch' case
    if [[ "${format}" == "from_epoch" ]]; then
        if [[ -z "${epoch}" ]]; then
            error "from_epoch requires epoch seconds"
            return "${FAIL}"
        fi
        if [[ "${PLATFORM_VARIANT:-}" == "bsd" ]] && [[ "${date_cmd}" != *"gdate"* ]]; then
            # BSD date
            "${date_cmd}" -r "${epoch}" 2> /dev/null
        else
            # GNU date
            "${date_cmd}" -d "@${epoch}" 2> /dev/null
        fi
        return $?
    fi

    # Check if format is a predefined key
    local predefined_flag
    predefined_flag="$(_platform_get_flag "date_${format}")"

    if [[ -n "${predefined_flag}" ]]; then
        # Use predefined format
        if [[ -n "${epoch}" ]]; then
            if [[ "${PLATFORM_VARIANT:-}" == "bsd" ]] && [[ "${date_cmd}" != *"gdate"* ]]; then
                # BSD date with epoch
                date_args=(-r "${epoch}" "${predefined_flag}")
            else
                # GNU date with epoch
                date_args=(-d "@${epoch}" "${predefined_flag}")
            fi
        else
            date_args=("${predefined_flag}")
        fi
    else
        # Custom format string
        if [[ -n "${epoch}" ]]; then
            if [[ "${PLATFORM_VARIANT:-}" == "bsd" ]] && [[ "${date_cmd}" != *"gdate"* ]]; then
                date_args=(-r "${epoch}" "${format}")
            else
                date_args=(-d "@${epoch}" "${format}")
            fi
        else
            date_args=("${format}")
        fi
    fi

    "${date_cmd}" "${date_args[@]}" 2> /dev/null || {
        error "date formatting failed"
        return "${FAIL}"
    }

    return "${PASS}"
}

###############################################################################
# platform::sed_inplace
#------------------------------------------------------------------------------
# Purpose  : Perform in-place sed editing (handles BSD vs GNU differences)
# Usage    : platform::sed_inplace <pattern> <file>
# Arguments:
#   $1 : sed expression
#   $2 : file path
# Returns  : PASS if successful, FAIL otherwise
###############################################################################
function platform::sed_inplace() {
    local pattern="${1:-}"
    local file="${2:-}"

    if [[ -z "${pattern}" || -z "${file}" ]]; then
        error "Usage: platform::sed_inplace <pattern> <file>"
        return "${FAIL}"
    fi

    if [[ ! -f "${file}" ]]; then
        error "File not found: ${file}"
        return "${FAIL}"
    fi

    platform::setup_commands || return "${FAIL}"

    local sed_cmd="${PLATFORM_CMD[sed]}"

    if [[ "${PLATFORM_VARIANT}" == "bsd" ]] && [[ "${sed_cmd}" != *"gsed"* ]]; then
        # BSD sed requires argument to -i
        "${sed_cmd}" -i '' "${pattern}" "${file}"
    else
        # GNU sed
        "${sed_cmd}" -i "${pattern}" "${file}"
    fi

    return $?
}

###############################################################################
# platform::readlink_canonical
#------------------------------------------------------------------------------
# Purpose  : Get canonical/absolute path (handles BSD vs GNU differences)
# Usage    : platform::readlink_canonical <path>
# Arguments:
#   $1 : path
# Returns  : PASS if successful, FAIL otherwise
# Outputs  : Canonical path
###############################################################################
function platform::readlink_canonical() {
    local path="${1:-}"

    if [[ -z "${path}" ]]; then
        error "Usage: platform::readlink_canonical <path>"
        return "${FAIL}"
    fi

    platform::setup_commands || return "${FAIL}"

    local readlink_cmd="${PLATFORM_CMD[readlink]}"

    if [[ "${PLATFORM_VARIANT}" == "bsd" ]] && [[ "${readlink_cmd}" != *"greadlink"* ]]; then
        # BSD doesn't have -f, use Python/Perl workaround
        if command -v python3 > /dev/null 2>&1; then
            python3 -c "import os; print(os.path.realpath('${path}'))"
        elif command -v perl > /dev/null 2>&1; then
            perl -MCwd -e "print Cwd::abs_path('${path}')"
        else
            # Last resort: cd and pwd
            if [[ -d "${path}" ]]; then
                (cd "${path}" && pwd)
            else
                (cd "$(dirname "${path}")" && echo "$(pwd)/$(basename "${path}")")
            fi
        fi
    else
        # GNU readlink or greadlink
        "${readlink_cmd}" -f "${path}"
    fi

    return $?
}

###############################################################################
# platform::mktemp
#------------------------------------------------------------------------------
# Purpose  : Create temporary file/directory (handles differences)
# Usage    : platform::mktemp [-d] [template]
# Arguments:
#   -d : Create directory instead of file
#   template : Optional template (e.g., /tmp/foo.XXXXXX)
# Returns  : PASS if successful, FAIL otherwise
# Outputs  : Path to created temp file/dir
###############################################################################
function platform::mktemp() {
    local is_dir=0
    local template=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d)
                is_dir=1
                shift
                ;;
            *)
                template="$1"
                shift
                ;;
        esac
    done

    platform::setup_commands || return "${FAIL}"

    local mktemp_cmd="${PLATFORM_CMD[mktemp]}"
    local args=()

    [[ ${is_dir} -eq 1 ]] && args+=(-d)
    [[ -n "${template}" ]] && args+=("${template}")

    "${mktemp_cmd}" "${args[@]}" || {
        error "mktemp failed"
        return "${FAIL}"
    }

    return "${PASS}"
}

###############################################################################
# platform::timeout
#------------------------------------------------------------------------------
# Purpose  : Run a command with timeout (handles GNU timeout vs macOS)
# Usage    : platform::timeout <seconds> <command> [args...]
# Arguments:
#   $1 : Timeout in seconds
#   $@ : Command and arguments to run
# Returns  : Exit code of command, or 124 on timeout
# Notes    : On macOS without gtimeout, uses bash-native implementation
###############################################################################
function platform::timeout() {
    local seconds="${1:-}"
    shift

    if [[ -z "${seconds}" || $# -eq 0 ]]; then
        error "Usage: platform::timeout <seconds> <command> [args...]"
        return "${FAIL}"
    fi

    platform::setup_commands || return "${FAIL}"

    local timeout_cmd="${PLATFORM_CMD[timeout]:-}"

    # Try GNU timeout (gtimeout on macOS with coreutils)
    if [[ -n "${timeout_cmd}" ]]; then
        "${timeout_cmd}" "${seconds}" "$@"
        return $?
    fi

    # Bash-native timeout fallback for macOS without coreutils
    debug "Using bash-native timeout implementation"

    # Run command in background
    "$@" &
    local cmd_pid=$!

    # Start watchdog in background
    (
        sleep "${seconds}"
        kill -TERM "${cmd_pid}" 2> /dev/null
        sleep 1
        kill -KILL "${cmd_pid}" 2> /dev/null
    ) &
    local watchdog_pid=$!

    # Wait for command
    wait "${cmd_pid}" 2> /dev/null
    local ret=$?

    # Kill watchdog if command finished first
    kill "${watchdog_pid}" 2> /dev/null
    wait "${watchdog_pid}" 2> /dev/null

    return "${ret}"
}

###############################################################################
# platform::dns_flush
#------------------------------------------------------------------------------
# Purpose  : Flush DNS cache (cross-platform)
# Usage    : platform::dns_flush
# Returns  : PASS if successful, FAIL otherwise
# Notes    : Works on Linux (systemd-resolve/resolvectl) and macOS (dscacheutil)
###############################################################################
function platform::dns_flush() {
    platform::detect_os

    debug "Flushing DNS cache on ${PLATFORM_OS}..."

    case "${PLATFORM_OS}" in
        macos)
            # macOS DNS flush
            if command -v dscacheutil > /dev/null 2>&1; then
                sudo dscacheutil -flushcache 2> /dev/null || true
            fi
            # Also restart mDNSResponder
            if command -v killall > /dev/null 2>&1; then
                sudo killall -HUP mDNSResponder 2> /dev/null || true
            fi
            pass "DNS cache flushed (macOS)"
            return "${PASS}"
            ;;
        linux | wsl)
            # Try systemd-resolved first
            if command -v resolvectl > /dev/null 2>&1; then
                resolvectl flush-caches 2> /dev/null && {
                    pass "DNS cache flushed (resolvectl)"
                    return "${PASS}"
                }
            fi
            # Older systemd
            if command -v systemd-resolve > /dev/null 2>&1; then
                systemd-resolve --flush-caches 2> /dev/null && {
                    pass "DNS cache flushed (systemd-resolve)"
                    return "${PASS}"
                }
            fi
            # nscd (older systems)
            if command -v nscd > /dev/null 2>&1; then
                sudo nscd -i hosts 2> /dev/null && {
                    pass "DNS cache flushed (nscd)"
                    return "${PASS}"
                }
            fi
            warn "No DNS cache flush method found on Linux"
            return "${FAIL}"
            ;;
        freebsd | openbsd | netbsd)
            # BSD systems with unbound
            if command -v unbound-control > /dev/null 2>&1; then
                sudo unbound-control flush_all 2> /dev/null && {
                    pass "DNS cache flushed (unbound)"
                    return "${PASS}"
                }
            fi
            warn "No DNS cache flush method found on BSD"
            return "${FAIL}"
            ;;
        *)
            warn "DNS cache flush not supported on ${PLATFORM_OS}"
            return "${FAIL}"
            ;;
    esac
}

###############################################################################
# platform::network_restart
#------------------------------------------------------------------------------
# Purpose  : Restart network services (cross-platform)
# Usage    : platform::network_restart [interface]
# Arguments:
#   $1 : Network interface (optional, restarts all if not specified)
# Returns  : PASS if successful, FAIL otherwise
# Notes    : Works on Linux (systemd/NetworkManager) and macOS
###############################################################################
function platform::network_restart() {
    local iface="${1:-}"

    platform::detect_os

    debug "Restarting network on ${PLATFORM_OS}..."

    case "${PLATFORM_OS}" in
        macos)
            if [[ -n "${iface}" ]]; then
                # Restart specific interface
                if command -v ifconfig > /dev/null 2>&1; then
                    sudo ifconfig "${iface}" down 2> /dev/null
                    sleep 1
                    sudo ifconfig "${iface}" up 2> /dev/null
                    pass "Interface ${iface} restarted"
                    return "${PASS}"
                fi
            else
                # Toggle Wi-Fi if available
                if command -v networksetup > /dev/null 2>&1; then
                    local wifi_device
                    wifi_device=$(networksetup -listallhardwareports | awk '/Wi-Fi|AirPort/{getline; print $2}')
                    if [[ -n "${wifi_device}" ]]; then
                        networksetup -setairportpower "${wifi_device}" off 2> /dev/null
                        sleep 2
                        networksetup -setairportpower "${wifi_device}" on 2> /dev/null
                        pass "Wi-Fi restarted"
                        return "${PASS}"
                    fi
                fi
                warn "Could not restart network on macOS"
                return "${FAIL}"
            fi
            ;;
        linux | wsl)
            # Try NetworkManager first
            if command -v systemctl > /dev/null 2>&1; then
                if systemctl is-active NetworkManager > /dev/null 2>&1; then
                    sudo systemctl restart NetworkManager 2> /dev/null && {
                        pass "NetworkManager restarted"
                        return "${PASS}"
                    }
                fi
                # Try networking service
                if systemctl is-active networking > /dev/null 2>&1; then
                    sudo systemctl restart networking 2> /dev/null && {
                        pass "Networking service restarted"
                        return "${PASS}"
                    }
                fi
                # Try systemd-networkd
                if systemctl is-active systemd-networkd > /dev/null 2>&1; then
                    sudo systemctl restart systemd-networkd 2> /dev/null && {
                        pass "systemd-networkd restarted"
                        return "${PASS}"
                    }
                fi
            fi
            # Fallback to service command
            if command -v service > /dev/null 2>&1; then
                sudo service networking restart 2> /dev/null && {
                    pass "Networking service restarted"
                    return "${PASS}"
                }
            fi
            # Last resort: toggle interface directly
            if [[ -n "${iface}" ]] && command -v ip > /dev/null 2>&1; then
                sudo ip link set "${iface}" down 2> /dev/null
                sleep 1
                sudo ip link set "${iface}" up 2> /dev/null
                pass "Interface ${iface} restarted"
                return "${PASS}"
            fi
            warn "Could not restart network on Linux"
            return "${FAIL}"
            ;;
        freebsd)
            if command -v service > /dev/null 2>&1; then
                sudo service netif restart 2> /dev/null && {
                    pass "Network interface restarted"
                    return "${PASS}"
                }
            fi
            return "${FAIL}"
            ;;
        *)
            warn "Network restart not supported on ${PLATFORM_OS}"
            return "${FAIL}"
            ;;
    esac
}

###############################################################################
# platform::checksum
#------------------------------------------------------------------------------
# Purpose  : Calculate file checksum (handles md5/sha256 differences)
# Usage    : platform::checksum <algorithm> <file>
# Arguments:
#   $1 : Algorithm (md5, sha1, sha256, sha512)
#   $2 : File path
# Returns  : PASS if successful, FAIL otherwise
# Outputs  : Checksum hash
###############################################################################
function platform::checksum() {
    local algo="${1:-}"
    local file="${2:-}"

    if [[ -z "${algo}" || -z "${file}" ]]; then
        error "Usage: platform::checksum <algorithm> <file>"
        return "${FAIL}"
    fi

    if [[ ! -f "${file}" ]]; then
        error "File not found: ${file}"
        return "${FAIL}"
    fi

    case "${algo}" in
        md5)
            if command -v md5sum > /dev/null 2>&1; then
                md5sum "${file}" | awk '{print $1}'
            elif command -v md5 > /dev/null 2>&1; then
                md5 -q "${file}"
            else
                error "No MD5 command available"
                return "${FAIL}"
            fi
            ;;
        sha256)
            if command -v sha256sum > /dev/null 2>&1; then
                sha256sum "${file}" | awk '{print $1}'
            elif command -v shasum > /dev/null 2>&1; then
                shasum -a 256 "${file}" | awk '{print $1}'
            else
                error "No SHA256 command available"
                return "${FAIL}"
            fi
            ;;
        sha1)
            if command -v sha1sum > /dev/null 2>&1; then
                sha1sum "${file}" | awk '{print $1}'
            elif command -v shasum > /dev/null 2>&1; then
                shasum -a 1 "${file}" | awk '{print $1}'
            else
                error "No SHA1 command available"
                return "${FAIL}"
            fi
            ;;
        sha512)
            if command -v sha512sum > /dev/null 2>&1; then
                sha512sum "${file}" | awk '{print $1}'
            elif command -v shasum > /dev/null 2>&1; then
                shasum -a 512 "${file}" | awk '{print $1}'
            else
                error "No SHA512 command available"
                return "${FAIL}"
            fi
            ;;
        *)
            error "Unknown algorithm: ${algo}"
            return "${FAIL}"
            ;;
    esac

    return "${PASS}"
}

###############################################################################
# platform::get_interface_ip
#------------------------------------------------------------------------------
# Purpose  : Get IP address of a network interface (cross-platform)
# Usage    : platform::get_interface_ip <interface>
# Arguments:
#   $1 : Interface name (e.g., eth0, en0)
# Returns  : PASS if successful, FAIL otherwise
# Outputs  : IP address
###############################################################################
function platform::get_interface_ip() {
    local iface="${1:-}"

    if [[ -z "${iface}" ]]; then
        error "Usage: platform::get_interface_ip <interface>"
        return "${FAIL}"
    fi

    platform::detect_os

    local ip=""

    case "${PLATFORM_OS}" in
        macos)
            # macOS ifconfig format: inet 192.168.1.100 netmask 0xffffff00
            ip=$(ifconfig "${iface}" 2> /dev/null | awk '/inet / && !/inet6/ {print $2}')
            ;;
        linux | wsl)
            # Try ip command first (modern Linux)
            if command -v ip > /dev/null 2>&1; then
                ip=$(ip -4 addr show "${iface}" 2> /dev/null | awk '/inet / {print $2}' | cut -d'/' -f1)
            elif command -v ifconfig > /dev/null 2>&1; then
                # Linux ifconfig format: inet 192.168.1.100  netmask 255.255.255.0
                # or older: inet addr:192.168.1.100
                ip=$(ifconfig "${iface}" 2> /dev/null | awk '/inet / {
                    if ($2 ~ /^addr:/) {
                        split($2, a, ":")
                        print a[2]
                    } else {
                        print $2
                    }
                }')
            fi
            ;;
        freebsd | openbsd | netbsd)
            ip=$(ifconfig "${iface}" 2> /dev/null | awk '/inet / && !/inet6/ {print $2}')
            ;;
        *)
            error "Unsupported platform: ${PLATFORM_OS}"
            return "${FAIL}"
            ;;
    esac

    if [[ -n "${ip}" ]]; then
        printf '%s\n' "${ip}"
        return "${PASS}"
    fi

    error "Could not get IP for interface: ${iface}"
    return "${FAIL}"
}

###############################################################################
# platform::get_interface_mac
#------------------------------------------------------------------------------
# Purpose  : Get MAC address of a network interface (cross-platform)
# Usage    : platform::get_interface_mac <interface>
# Arguments:
#   $1 : Interface name (e.g., eth0, en0)
# Returns  : PASS if successful, FAIL otherwise
# Outputs  : MAC address
###############################################################################
function platform::get_interface_mac() {
    local iface="${1:-}"

    if [[ -z "${iface}" ]]; then
        error "Usage: platform::get_interface_mac <interface>"
        return "${FAIL}"
    fi

    platform::detect_os

    local mac=""

    case "${PLATFORM_OS}" in
        macos)
            # macOS: ether aa:bb:cc:dd:ee:ff
            mac=$(ifconfig "${iface}" 2> /dev/null | awk '/ether / {print $2}')
            ;;
        linux | wsl)
            # Try ip command first
            if command -v ip > /dev/null 2>&1; then
                mac=$(ip link show "${iface}" 2> /dev/null | awk '/link\/ether/ {print $2}')
            elif command -v ifconfig > /dev/null 2>&1; then
                # Linux ifconfig: ether aa:bb:cc:dd:ee:ff or HWaddr aa:bb:cc:dd:ee:ff
                mac=$(ifconfig "${iface}" 2> /dev/null | awk '/ether |HWaddr/ {print $2}')
            fi
            ;;
        freebsd | openbsd | netbsd)
            mac=$(ifconfig "${iface}" 2> /dev/null | awk '/ether / {print $2}')
            ;;
        *)
            error "Unsupported platform: ${PLATFORM_OS}"
            return "${FAIL}"
            ;;
    esac

    if [[ -n "${mac}" ]]; then
        printf '%s\n' "${mac}"
        return "${PASS}"
    fi

    error "Could not get MAC for interface: ${iface}"
    return "${FAIL}"
}

#===============================================================================
# Platform Information
#===============================================================================

###############################################################################
# platform::info
#------------------------------------------------------------------------------
# Purpose  : Display platform detection information
# Usage    : platform::info
# Returns  : PASS always
###############################################################################
function platform::info() {
    platform::setup_commands

    printf "Platform Information:\n"
    printf "  OS: %s\n" "${PLATFORM_OS}"
    printf "  Variant: %s\n" "${PLATFORM_VARIANT}"
    printf "\nCommand Mappings:\n"

    local cmd
    for cmd in sed stat date base64 find grep awk readlink timeout; do
        printf "  %-12s: %s\n" "${cmd}" "${PLATFORM_CMD[${cmd}]:-NOT FOUND}"
    done

    return "${PASS}"
}

###############################################################################
# platform::check_gnu_tools
#------------------------------------------------------------------------------
# Purpose  : Check if GNU tools are available (useful for macOS)
# Usage    : platform::check_gnu_tools
# Returns  : PASS if all GNU tools found, FAIL otherwise
###############################################################################
function platform::check_gnu_tools() {
    if [[ "${PLATFORM_OS}" != "macos" ]]; then
        debug "Not macOS, skipping GNU tools check"
        return "${PASS}"
    fi

    local -a gnu_tools=(gsed gstat gdate gfind ggrep gawk greadlink gtar gtimeout)
    local missing=0

    info "Checking for GNU tools on macOS..."

    for tool in "${gnu_tools[@]}"; do
        if command -v "${tool}" > /dev/null 2>&1; then
            pass "Found: ${tool}"
        else
            warn "Missing: ${tool}"
            ((missing++))
        fi
    done

    if [[ ${missing} -gt 0 ]]; then
        warn "Install missing tools with: brew install coreutils findutils gnu-sed gnu-tar grep gawk"
        return "${FAIL}"
    fi

    pass "All GNU tools available"
    return "${PASS}"
}

#===============================================================================
# Self-Test
#===============================================================================

###############################################################################
# platform::self_test
#------------------------------------------------------------------------------
# Purpose  : Test platform abstraction functions
# Usage    : platform::self_test
# Returns  : PASS if all tests pass, FAIL otherwise
###############################################################################
function platform::self_test() {
    info "Running platform::self_test..."

    local status="${PASS}"

    # Test 1: Platform detection
    platform::detect_os
    platform::detect_variant
    if [[ -z "${PLATFORM_OS}" || -z "${PLATFORM_VARIANT}" ]]; then
        fail "Platform detection failed"
        status="${FAIL}"
    else
        pass "Platform detected: ${PLATFORM_OS} (${PLATFORM_VARIANT})"
    fi

    # Test 2: Command setup
    if ! platform::setup_commands; then
        fail "Command setup failed"
        status="${FAIL}"
    else
        pass "Commands initialized"
    fi

    # Test 3: stat wrapper
    # SECURITY FIX: Use mktemp instead of predictable $$
    local test_file
    if ! test_file=$(mktemp "/tmp/platform_test.XXXXXX"); then
        fail "Could not create temp file for testing"
        return "${FAIL}"
    fi

    # SECURITY FIX: Set restrictive permissions immediately
    chmod 600 "${test_file}" || {
        rm -f -- "${test_file}"
        fail "Could not set temp file permissions"
        return "${FAIL}"
    }

    # Use trap to ensure cleanup on any exit path
    # Note: Double quotes ensure test_file is expanded NOW, not when trap fires
    trap "rm -f -- '${test_file}' 2>/dev/null" RETURN

    printf 'test\n' > "${test_file}"

    local size
    if size=$(platform::stat size "${test_file}"); then
        pass "platform::stat works (size=${size})"
    else
        fail "platform::stat failed"
        status="${FAIL}"
    fi

    # Test 4: date wrapper
    local date_str
    if date_str=$(platform::date iso8601); then
        pass "platform::date works (${date_str})"
    else
        fail "platform::date failed"
        status="${FAIL}"
    fi

    # Test 5: checksum
    local hash
    if hash=$(platform::checksum md5 "${test_file}"); then
        pass "platform::checksum works (${hash})"
    else
        fail "platform::checksum failed"
        status="${FAIL}"
    fi

    # Test 6: timeout (quick test)
    if platform::timeout 2 sleep 0.1 2> /dev/null; then
        pass "platform::timeout works"
    else
        warn "platform::timeout may not be available"
    fi

    # Cleanup handled by trap RETURN

    if [[ ${status} -eq "${PASS}" ]]; then
        pass "platform::self_test completed successfully"
    else
        fail "platform::self_test encountered failures"
    fi

    return "${status}"
}

# Auto-initialize on load
platform::setup_commands || warn "Platform initialization incomplete"
