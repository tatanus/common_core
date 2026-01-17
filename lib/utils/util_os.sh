#!/usr/bin/env bash
###############################################################################
# NAME         : util_os.sh
# DESCRIPTION  : Operating system detection and environment inspection helpers.
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-10-27
###############################################################################
# EDIT HISTORY:
# DATE        | EDITED BY      | DESCRIPTION
# ------------|----------------|-----------------------------------------------
# 2025-10-27  | Adam Compton   | Initial generation (style-guide compliant)
# 2025-12-25  | Adam Compton   | Corrected: Removed PASS/FAIL defs, added
#             |                | logging fallbacks, removed os::is_root
#             |                | (moved to util.sh), standardized errors
# 2025-12-28  | Adam Compton   | Fixed: Replaced grep -P with sed for macOS
#             |                | compatibility, improved WSL2 detection
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Library Guard
#===============================================================================
if [[ -n "${UTIL_OS_SH_LOADED:-}" ]]; then
    if (return 0 2> /dev/null); then
        return 0
    fi
else
    UTIL_OS_SH_LOADED=1
fi

#===============================================================================
# Module Dependencies
#===============================================================================
if [[ "${UTIL_PLATFORM_SH_LOADED:-0}" -eq 0 ]]; then
    echo "ERROR: util_platform.sh must be loaded before util_os.sh" >&2
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
# OS Detection and Information Functions
#===============================================================================

###############################################################################
# os::detect
#------------------------------------------------------------------------------
# Purpose  : Detect the current operating system.
# Usage    : os::detect
# Returns  : Prints one of: linux, macos, wsl, windows, or unknown
# Requires:
#   Functions: file::is_readable (from util_file.sh), debug
#   Commands: uname, grep
###############################################################################
function os::detect() {
    # Delegate to platform module
    platform::detect_os
    printf '%s\n' "${PLATFORM_OS}"
    return "${PASS}"
}

###############################################################################
# os::is_linux
#------------------------------------------------------------------------------
# Purpose  : Check if running on Linux.
# Usage    : os::is_linux && info "Running Linux"
# Returns  : PASS (0) if Linux, FAIL (1) otherwise
# Requires:
#   Functions: os::detect
###############################################################################
function os::is_linux() {
    [[ "$(os::detect)" == "linux" ]] && return "${PASS}" || return "${FAIL}"
}

###############################################################################
# os::is_macos
#------------------------------------------------------------------------------
# Purpose  : Check if running on macOS.
# Usage    : os::is_macos && info "Running macOS"
# Returns  : PASS (0) if macOS, FAIL (1) otherwise
# Requires:
#   Functions: os::detect
###############################################################################
function os::is_macos() {
    [[ "$(os::detect)" == "macos" ]] && return "${PASS}" || return "${FAIL}"
}

###############################################################################
# os::is_wsl
#------------------------------------------------------------------------------
# Purpose  : Check if running under Windows Subsystem for Linux.
# Usage    : os::is_wsl && info "Running under WSL"
# Returns  : PASS (0) if WSL, FAIL (1) otherwise
# Requires:
#   Functions: os::detect
###############################################################################
function os::is_wsl() {
    if [[ "$(os::detect)" == "wsl" ]]; then
        return "${PASS}"
    fi

    # Additional WSL detection checks
    if [[ -f /proc/sys/kernel/osrelease ]]; then
        # Check for WSL2 or microsoft in osrelease
        if grep -qiE "WSL2|microsoft" /proc/sys/kernel/osrelease 2> /dev/null; then
            return "${PASS}"
        fi
    fi

    # Check /proc/version as fallback
    if [[ -f /proc/version ]]; then
        if grep -qiE "microsoft|WSL" /proc/version 2> /dev/null; then
            return "${PASS}"
        fi
    fi

    return "${FAIL}"
}

###############################################################################
# os::get_distro
#------------------------------------------------------------------------------
# Purpose  : Get Linux distribution name.
# Usage    : os::get_distro
# Returns  : Prints distribution name, or "unknown" if undetectable
# Requires:
#   Functions: os::is_macos, os::is_wsl, os::is_linux, cmd::exists, debug
#   Commands: grep, cut, tr, lsb_release (optional)
#   Files: /etc/os-release (optional)
###############################################################################
function os::get_distro() {
    local distro="unknown"

    if os::is_macos; then
        printf '%s\n' "macos"
        return "${PASS}"
    elif os::is_wsl || os::is_linux; then
        if [[ -r "/etc/os-release" ]]; then
            distro="$(grep -E '^ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')"
        elif cmd::exists lsb_release; then
            distro="$(lsb_release -si 2> /dev/null | tr '[:upper:]' '[:lower:]' || true)"
        elif [[ -r "/etc/debian_version" ]]; then
            distro="debian"
        elif [[ -r "/etc/redhat-release" ]]; then
            distro="rhel"
        elif [[ -r "/etc/arch-release" ]]; then
            distro="arch"
        fi
    fi

    debug "os::get_distro: detected distro: ${distro}"
    printf '%s\n' "${distro:-unknown}"
    return "${PASS}"
}

###############################################################################
# os::get_version
#------------------------------------------------------------------------------
# Purpose  : Get OS version.
# Usage    : os::get_version
# Returns  : Prints OS version string, or "unknown"
# Requires:
#   Functions: os::is_macos, os::is_linux, os::is_wsl, os::detect,
#              cmd::exists, debug
#   Commands: sw_vers (macOS), grep, cut, tr, lsb_release (optional),
#             cmd.exe (Windows)
#   Files: /etc/os-release (optional)
###############################################################################
function os::get_version() {
    local version="unknown"

    if os::is_macos; then
        if cmd::exists sw_vers; then
            version="$(sw_vers -productVersion 2> /dev/null || true)"
        fi
    elif os::is_linux || os::is_wsl; then
        if [[ -r "/etc/os-release" ]]; then
            version="$(grep -E '^VERSION_ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')"
        elif cmd::exists lsb_release; then
            version="$(lsb_release -sr 2> /dev/null || true)"
        fi
    elif [[ "$(os::detect)" == "windows" ]]; then
        if cmd::exists cmd.exe; then
            # Use sed instead of grep -P for cross-platform compatibility
            # Extract version number from: Microsoft Windows [Version 10.0.19041.1234]
            version="$(cmd.exe /c ver 2> /dev/null | sed -n 's/.*\[Version \([^]]*\)\].*/\1/p' || true)"
        fi
    fi

    debug "os::get_version: detected version: ${version}"
    printf '%s\n' "${version:-unknown}"
    return "${PASS}"
}

###############################################################################
# os::get_arch
#------------------------------------------------------------------------------
# Purpose  : Get normalized CPU architecture.
# Usage    : os::get_arch
# Returns  : Prints architecture (amd64, arm64, 386, armhf, etc.)
# Requires:
#   Functions: debug
#   Commands: uname
###############################################################################
function os::get_arch() {
    local arch
    arch="$(uname -m 2> /dev/null || printf 'unknown')"

    case "${arch}" in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        arm64) arch="arm64" ;;
        i[3-6]86) arch="386" ;;
        armv7l) arch="armhf" ;;
        armv6l) arch="armv6" ;;
        ppc64le) arch="ppc64le" ;;
        s390x) arch="s390x" ;;
        *) arch="unsupported" ;;
    esac

    debug "os::get_arch: detected architecture: ${arch}"
    printf '%s\n' "${arch}"
    return "${PASS}"
}

###############################################################################
# os::is_arm
#------------------------------------------------------------------------------
# Purpose  : Check if system architecture is ARM-based.
# Usage    : os::is_arm && info "ARM detected"
# Returns  : PASS (0) if ARM, FAIL (1) otherwise
# Requires:
#   Functions: os::get_arch
###############################################################################
function os::is_arm() {
    local arch
    arch="$(os::get_arch)"
    [[ "${arch}" =~ ^(arm64|armhf|armv6|aarch64)$ ]] && return "${PASS}" || return "${FAIL}"
}

###############################################################################
# os::is_x86
#------------------------------------------------------------------------------
# Purpose  : Check if system architecture is x86-based.
# Usage    : os::is_x86 && info "x86 detected"
# Returns  : PASS (0) if x86/amd64, FAIL (1) otherwise
# Requires:
#   Functions: os::get_arch
###############################################################################
function os::is_x86() {
    local arch
    arch="$(os::get_arch)"
    [[ "${arch}" =~ ^(amd64|386|x86_64|i[3-6]86)$ ]] && return "${PASS}" || return "${FAIL}"
}

###############################################################################
# os::get_shell
#------------------------------------------------------------------------------
# Purpose  : Get current shell name.
# Usage    : os::get_shell
# Returns  : Prints shell name (bash, zsh, etc.) or "unknown"
# Requires:
#   Functions: cmd::exists (optional), debug
#   Commands: ps (optional), awk
###############################################################################
function os::get_shell() {
    local shell_name="unknown"

    if [[ -n "${SHELL:-}" ]]; then
        shell_name="$(file::get_basename "${SHELL}")"
    elif cmd::exists ps; then
        shell_name="$(ps -p "$$" -o comm= 2> /dev/null | awk -F/ '{print $NF}')"
    fi

    debug "os::get_shell: detected shell: ${shell_name}"
    printf '%s\n' "${shell_name:-unknown}"
    return "${PASS}"
}

###############################################################################
# os::is_root
#------------------------------------------------------------------------------
# Purpose  : Check if running as root user.
# Usage    : os::is_root && info "Running as root"
# Returns  : PASS (0) if root, FAIL (1) otherwise
###############################################################################
function os::is_root() {
    [[ "${EUID:-$(id -u)}" -eq 0 ]] && return "${PASS}" || return "${FAIL}"
}

###############################################################################
# os::require_root
#------------------------------------------------------------------------------
# Purpose  : Require root privileges, exit if not root.
# Usage    : os::require_root "Custom message"
# Arguments:
#   $1 : Optional custom error message
# Returns  : Exits 1 if not root, PASS (0) if root
# Requires:
#   Functions: os::is_root, error
###############################################################################
function os::require_root() {
    local msg="${1:-This script must be run as root}"
    if ! os::is_root; then
        error "os::require_root: ${msg}"
        return "${FAIL}"
    fi
    return "${PASS}"
}

###############################################################################
# os::get_kernel_version
#------------------------------------------------------------------------------
# Purpose  : Get the kernel version string.
# Usage    : os::get_kernel_version
# Returns  : Prints kernel version
###############################################################################
function os::get_kernel_version() {
    local kernel_version
    kernel_version="$(uname -r 2> /dev/null || echo 'unknown')"
    debug "os::get_kernel_version: ${kernel_version}"
    printf '%s\n' "${kernel_version}"
    return "${PASS}"
}

###############################################################################
# os::get_hostname
#------------------------------------------------------------------------------
# Purpose  : Get the system hostname.
# Usage    : os::get_hostname
# Returns  : Prints hostname
###############################################################################
function os::get_hostname() {
    local hostname_str

    if cmd::exists hostname; then
        hostname_str="$(hostname 2> /dev/null || true)"
    elif [[ -r /etc/hostname ]]; then
        hostname_str="$(cat /etc/hostname 2> /dev/null || true)"
    else
        hostname_str="$(uname -n 2> /dev/null || echo 'unknown')"
    fi

    debug "os::get_hostname: ${hostname_str}"
    printf '%s\n' "${hostname_str:-unknown}"
    return "${PASS}"
}

###############################################################################
# os::get_uptime
#------------------------------------------------------------------------------
# Purpose  : Get system uptime in seconds.
# Usage    : os::get_uptime
# Returns  : Prints uptime in seconds
###############################################################################
function os::get_uptime() {
    local uptime_secs=""

    if os::is_macos; then
        # macOS: use sysctl
        local boot_time
        boot_time=$(sysctl -n kern.boottime 2> /dev/null | awk '{print $4}' | tr -d ',')
        if [[ -n "${boot_time}" ]]; then
            local now
            now=$(date +%s)
            uptime_secs=$((now - boot_time))
        fi
    elif [[ -r /proc/uptime ]]; then
        # Linux: read from /proc/uptime
        uptime_secs=$(awk '{print int($1)}' /proc/uptime 2> /dev/null)
    fi

    if [[ -n "${uptime_secs}" ]]; then
        printf '%s\n' "${uptime_secs}"
        return "${PASS}"
    fi

    printf '0\n'
    return "${FAIL}"
}

###############################################################################
# os::get_memory_total
#------------------------------------------------------------------------------
# Purpose  : Get total system memory in bytes.
# Usage    : os::get_memory_total
# Returns  : Prints total memory in bytes
###############################################################################
function os::get_memory_total() {
    local mem_bytes=""

    if os::is_macos; then
        # macOS: use sysctl
        mem_bytes=$(sysctl -n hw.memsize 2> /dev/null)
    elif [[ -r /proc/meminfo ]]; then
        # Linux: read from /proc/meminfo (value is in kB)
        local mem_kb
        mem_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo 2> /dev/null)
        if [[ -n "${mem_kb}" ]]; then
            mem_bytes=$((mem_kb * 1024))
        fi
    fi

    if [[ -n "${mem_bytes}" ]]; then
        printf '%s\n' "${mem_bytes}"
        return "${PASS}"
    fi

    printf '0\n'
    return "${FAIL}"
}

###############################################################################
# os::get_cpu_count
#------------------------------------------------------------------------------
# Purpose  : Get number of CPU cores.
# Usage    : os::get_cpu_count
# Returns  : Prints CPU core count
###############################################################################
function os::get_cpu_count() {
    local cpu_count=""

    if os::is_macos; then
        # macOS: use sysctl
        cpu_count=$(sysctl -n hw.ncpu 2> /dev/null)
    elif [[ -r /proc/cpuinfo ]]; then
        # Linux: count processors
        cpu_count=$(grep -c '^processor' /proc/cpuinfo 2> /dev/null)
    elif cmd::exists nproc; then
        cpu_count=$(nproc 2> /dev/null)
    fi

    if [[ -n "${cpu_count}" ]]; then
        printf '%s\n' "${cpu_count}"
        return "${PASS}"
    fi

    printf '1\n'
    return "${FAIL}"
}

###############################################################################
# os::str
#------------------------------------------------------------------------------
# Purpose  : Print a concise OS descriptor string: "<OS> <Version> <Arch>"
# Usage    : os::str
# Returns  : Prints the combined string
# Requires:
#   Functions: os::detect, os::get_version, os::get_arch, debug
###############################################################################
function os::str() {
    local os_type version arch
    os_type="$(os::detect)"
    version="$(os::get_version)"
    arch="$(os::get_arch)"
    printf '%s %s %s\n' "${os_type}" "${version}" "${arch}"
    debug "os::str: OS summary: ${os_type} ${version} ${arch}"
    return "${PASS}"
}

###############################################################################
# os::self_test
#------------------------------------------------------------------------------
# Purpose  : Self-test for util_os.sh functionality
# Usage    : os::self_test
# Returns  : PASS (0) if all tests pass, FAIL (1) otherwise
# Globals  : None
###############################################################################
function os::self_test() {
    info "Running util_os.sh self-test..."

    local status="${PASS}"

    # Test 1: OS detection
    local detected_os
    if detected_os=$(os::detect 2> /dev/null); then
        pass "os::detect works (OS: ${detected_os})"
    else
        fail "os::detect failed"
        status="${FAIL}"
    fi

    # Test 2: Architecture detection
    local detected_arch
    if detected_arch=$(os::get_arch 2> /dev/null); then
        pass "os::get_arch works (Arch: ${detected_arch})"
    else
        fail "os::get_arch failed"
        status="${FAIL}"
    fi

    # Test 3: Shell detection
    local detected_shell
    if detected_shell=$(os::get_shell 2> /dev/null); then
        pass "os::get_shell works (Shell: ${detected_shell})"
    else
        fail "os::get_shell failed"
        status="${FAIL}"
    fi

    # Test 4: String representation
    local os_str
    if os_str=$(os::str 2> /dev/null); then
        pass "os::str works (${os_str})"
    else
        fail "os::str failed"
        status="${FAIL}"
    fi

    # Test 5: Distro detection
    local distro
    if distro=$(os::get_distro 2> /dev/null); then
        pass "os::get_distro works (Distro: ${distro})"
    else
        fail "os::get_distro failed"
        status="${FAIL}"
    fi

    # Test 6: CPU count
    local cpu_count
    if cpu_count=$(os::get_cpu_count 2> /dev/null); then
        pass "os::get_cpu_count works (CPUs: ${cpu_count})"
    else
        warn "os::get_cpu_count failed"
    fi

    if [[ "${status}" -eq "${PASS}" ]]; then
        pass "util_os.sh self-test passed"
    else
        fail "util_os.sh self-test failed"
    fi

    return "${status}"
}
