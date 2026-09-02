#!/usr/bin/env bash

#===============================================================================
# Strict Mode (Bash-first, zsh best-effort)
#===============================================================================
if [[ -n "${ZSH_VERSION:-}" ]]; then
    emulate -L sh
    setopt NO_UNSET
    setopt PIPE_FAIL
    setopt NO_BEEP
fi

set -uo pipefail
IFS=$'\n\t'

# =============================================================================
# NAME        : system_maintenance.sh
# DESCRIPTION : Debian/Kali system-maintenance pass, split out of the old
#               install_extras.sh so tool INSTALLATION (install_tools.sh) and
#               system UPKEEP live in separate, single-purpose scripts.
#
#               Phases:
#                 1. apt update + apt upgrade   (refresh + patch the system)
#                 2. sweep stale /pentest/*     (remove legacy tool checkouts)
#                 3. apt cleanup                (clean / autoremove / autoclean)
#                 4. disk-usage report          (duf, if present)
#
#               None of this installs the interactive-shell tools -- that is
#               install_tools.sh's job. Run this when you want to bring a box
#               up to date and reclaim space, not when you are provisioning it.
#
# AUTHOR      : Adam Compton
# DATE CREATED: 2026-09-01
# =============================================================================

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

# Raise the default log level BEFORE sourcing util.sh. common_core defaults to
# "warn" (see util.sh's _UTIL_CURRENT_LOG_LEVEL), which would swallow every
# info()/pass() line and make a working run look like a no-op.
export UTIL_LOG_LEVEL="${UTIL_LOG_LEVEL:-info}"

DRY_RUN="${DRY_RUN:-false}"

# Which phases to run. All true by default; narrowed by CLI flags.
DO_UPGRADE="true"
DO_SWEEP="true"
DO_CLEANUP="true"

# Stale /pentest/ directories to remove. Carried verbatim from install_extras.sh
# (the commented-out entries in the original legacy snippet stay omitted).
STALE_PENTEST_DIRS=(
    /pentest/wireless/
    /pentest/exploitation/clusterd/
    /pentest/exploitation/dhtest/
    /pentest/exploitation/exploitdb/
    /pentest/exploitation/jexboss/
    /pentest/exploitation/tenable_poc/
    /pentest/exploitation/Timeroast/
    /pentest/intelligence-gathering/discover/
    /pentest/intelligence-gathering/ldapperlinux-exploit-suggester/
    /pentest/intelligence-gathering/linuxprivchecker/
    /pentest/intelligence-gathering/rawr/
    /pentest/intelligence-gathering/windows-exploit-suggester/
)

# -----------------------------------------------------------------------------
# Source common_core's util.sh (in-repo copy first so a fresh clone works)
# -----------------------------------------------------------------------------
if [[ -z "${UTILS_SH_LOADED:-}" ]]; then
    _SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -r "${_SCRIPT_DIR}/lib/util.sh" ]]; then
        # shellcheck source=/dev/null
        source "${_SCRIPT_DIR}/lib/util.sh"
    elif [[ -r "${HOME}/.config/bash/lib/common_core/util.sh" ]]; then
        # shellcheck source=/dev/null
        source "${HOME}/.config/bash/lib/common_core/util.sh"
    fi
    unset _SCRIPT_DIR
fi

if ! declare -F info > /dev/null 2>&1; then
    function info() { printf '[INFO ] %s\n' "$*" >&2; }
fi
if ! declare -F warn > /dev/null 2>&1; then
    function warn() { printf '[WARN ] %s\n' "$*" >&2; }
fi
if ! declare -F pass > /dev/null 2>&1; then
    function pass() { printf '[PASS ] %s\n' "$*" >&2; }
fi
if ! declare -F fail > /dev/null 2>&1; then
    function fail() { printf '[FAIL ] %s\n' "$*" >&2; }
fi

# -----------------------------------------------------------------------------
# Helpers (proxy / run / gating), mirrored from install_extras.sh so this
# script is self-contained.
# -----------------------------------------------------------------------------

###############################################################################
# detect_proxy
#------------------------------------------------------------------------------
# Purpose  : Set ${PROXY} based on actual Internet reachability. Delegates to
#            common_core's net::proxy_auto_detect when available; otherwise
#            leaves PROXY empty rather than guessing.
# Returns  : 0 always; PROXY is exported (possibly empty)
###############################################################################
function detect_proxy() {
    if [[ -n "${PROXY+x}" ]]; then
        export PROXY
        return 0
    fi

    if declare -F net::proxy_auto_detect > /dev/null 2>&1; then
        net::proxy_auto_detect
        return 0
    fi

    warn "net::proxy_auto_detect unavailable (common_core not sourced); PROXY=''"
    export PROXY=""
}

###############################################################################
# run
#------------------------------------------------------------------------------
# Purpose  : Echo + execute a command, honoring DRY_RUN and the dynamic
#            ${PROXY} prefix. When PROXY is empty the command runs directly;
#            otherwise PROXY is split into tokens and prepended.
# Usage    : run apt upgrade -y
# Returns  : exit code of the command (or 0 in dry-run)
###############################################################################
function run() {
    if [[ "${DRY_RUN}" == "true" ]]; then
        # Locally-scoped IFS so "$*" joins with spaces despite IFS=$'\n\t'.
        local IFS=' '
        printf '[DRY-RUN] %s %s\n' "${PROXY}" "$*" >&2
        return 0
    fi
    if [[ -n "${PROXY}" ]]; then
        # Word-splitting PROXY is intentional: it is a command prefix.
        # shellcheck disable=SC2086
        ${PROXY} "$@"
    else
        "$@"
    fi
}

###############################################################################
# require_root
#------------------------------------------------------------------------------
# Purpose  : Exit with FAIL if not running as root. Skipped under --dry-run.
###############################################################################
function require_root() {
    if [[ "${EUID:-65535}" -ne 0 ]]; then
        fail "system_maintenance.sh must run as root (try: sudo $0)"
        exit 1
    fi
}

###############################################################################
# require_apt_platform
#------------------------------------------------------------------------------
# Purpose  : Refuse to run anywhere apt is not the package manager. The upgrade
#            and cleanup phases are pure apt; the /pentest sweep is Linux
#            filesystem layout. On macOS the first `apt update` would fail after
#            a sudo prompt, so fail fast with a clear reason.
# Returns  : 0 on an apt host; exits 1 otherwise
###############################################################################
function require_apt_platform() {
    local host_os=""

    if declare -F os::detect > /dev/null 2>&1; then
        host_os="$(os::detect)"
    else
        case "$(uname -s 2> /dev/null)" in
            Darwin) host_os="macos" ;;
            Linux) host_os="linux" ;;
            *) host_os="unknown" ;;
        esac
    fi

    # WSL runs Debian userland under apt; treat it as linux.
    [[ "${host_os}" == "wsl" ]] && host_os="linux"

    if [[ "${host_os}" != "linux" ]] || ! command -v apt-get > /dev/null 2>&1; then
        fail "system_maintenance.sh is Debian/Kali-only (detected: ${host_os})."
        exit 1
    fi

    return 0
}

###############################################################################
# show_usage
###############################################################################
function show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Debian/Kali system-maintenance pass: apt update + upgrade, removal of stale
/pentest/* tool checkouts, apt cleanup, and a disk-usage report. Installs no
interactive-shell tools -- use install_tools.sh for that.

OPTIONS:
    -n, --dry-run     Print what would happen; do not modify the system
        --no-upgrade  Skip the apt update + upgrade phase
        --no-sweep    Skip the stale /pentest/* removal phase
        --no-cleanup  Skip the apt clean / autoremove / autoclean phase
        --no-proxy    Force PROXY="" (skip proxychains4 for this run)
        --proxy CMD   Use CMD as the proxy prefix (e.g. "proxychains4 -q")
    -h, --help        Show this message

ENVIRONMENT:
    PROXY             Override the proxy prefix. Empty disables proxying.
                      Unset triggers auto-detection.
    DRY_RUN           Set to "true" for --dry-run behavior.

EXAMPLES:
    sudo ./$(basename "$0")                   # full maintenance pass
    sudo ./$(basename "$0") --dry-run         # preview only
    sudo ./$(basename "$0") --no-upgrade      # just sweep + cleanup
    sudo PROXY="" ./$(basename "$0")          # direct, no proxychains
EOF
}

# -----------------------------------------------------------------------------
# Phases
# -----------------------------------------------------------------------------

###############################################################################
# update_and_upgrade
#------------------------------------------------------------------------------
# Purpose  : Refresh apt lists and upgrade installed packages. Prefers
#            common_core's apt:: helpers, falling back to direct apt calls.
# Returns  : 0 on success, 1 on failure
###############################################################################
function update_and_upgrade() {
    info "Updating apt package lists..."
    if declare -F apt::update > /dev/null 2>&1 && [[ "${DRY_RUN}" != "true" ]]; then
        apt::update || {
            fail "apt update failed"
            return 1
        }
    else
        run apt update || {
            fail "apt update failed"
            return 1
        }
    fi

    info "Upgrading installed packages..."
    if declare -F apt::upgrade > /dev/null 2>&1 && [[ "${DRY_RUN}" != "true" ]]; then
        apt::upgrade || {
            fail "apt upgrade failed"
            return 1
        }
    else
        run apt upgrade -y || {
            fail "apt upgrade failed"
            return 1
        }
    fi

    pass "System updated and upgraded."
}

###############################################################################
# sweep_stale_pentest_dirs
#------------------------------------------------------------------------------
# Purpose  : Remove legacy /pentest/* tool directories that are no longer used.
# Returns  : 0 always
###############################################################################
function sweep_stale_pentest_dirs() {
    info "Sweeping stale /pentest/ directories..."
    local removed=0 skipped=0 d
    for d in "${STALE_PENTEST_DIRS[@]}"; do
        if [[ ! -e "${d}" ]]; then
            ((skipped++))
            continue
        fi
        if [[ "${DRY_RUN}" == "true" ]]; then
            info "[DRY-RUN] rm -rf ${d}"
            ((removed++))
            continue
        fi
        rm -rf -- "${d}"
        info "Removed: ${d}"
        ((removed++))
    done
    pass "Sweep complete: ${removed} removed, ${skipped} not present"
}

###############################################################################
# apt_cleanup
#------------------------------------------------------------------------------
# Purpose  : Reclaim space via apt clean / autoremove / autoclean.
# Returns  : 0 always (individual failures warn, do not abort)
###############################################################################
function apt_cleanup() {
    info "apt cleanup..."
    run apt-get clean || warn "apt-get clean failed"
    run apt-get autoremove -y || warn "apt-get autoremove failed"
    run apt-get autoclean || warn "apt-get autoclean failed"
    pass "apt cleanup complete."
}

###############################################################################
# show_disk_usage
#------------------------------------------------------------------------------
# Purpose  : Print a final disk-usage report via duf, if installed.
# Returns  : 0 always
###############################################################################
function show_disk_usage() {
    info "Final disk-usage report (duf)..."
    if [[ "${DRY_RUN}" == "true" ]]; then
        info "[DRY-RUN] duf"
        return 0
    fi
    if command -v duf > /dev/null 2>&1; then
        duf
    else
        warn "duf not on PATH (install via install_tools.sh). Skipping."
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
function main() {
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -n | --dry-run)
                DRY_RUN=true
                shift
                ;;
            --no-upgrade)
                DO_UPGRADE=false
                shift
                ;;
            --no-sweep)
                DO_SWEEP=false
                shift
                ;;
            --no-cleanup)
                DO_CLEANUP=false
                shift
                ;;
            --no-proxy)
                PROXY=""
                shift
                ;;
            --proxy)
                if [[ -z "${2:-}" ]]; then
                    fail "--proxy requires an argument"
                    exit 2
                fi
                PROXY="${2}"
                shift 2
                ;;
            -h | --help)
                show_usage
                exit 0
                ;;
            *)
                fail "Unknown option: ${1}"
                show_usage
                exit 2
                ;;
        esac
    done

    # Platform gate before the root check so a macOS user gets a useful error
    # instead of a sudo prompt followed by one.
    require_apt_platform

    if [[ "${DRY_RUN}" != "true" ]]; then
        require_root
    fi

    detect_proxy

    info "PROXY prefix: '${PROXY:-(none)}'"
    info "Dry-run:      ${DRY_RUN}"
    info "Phases:       upgrade=${DO_UPGRADE} sweep=${DO_SWEEP} cleanup=${DO_CLEANUP}"
    echo ""

    local rc=0
    [[ "${DO_UPGRADE}" == "true" ]] && { update_and_upgrade || rc=1; }
    [[ "${DO_SWEEP}" == "true" ]] && sweep_stale_pentest_dirs
    [[ "${DO_CLEANUP}" == "true" ]] && apt_cleanup
    show_disk_usage

    echo ""
    if [[ "${rc}" -eq 0 ]]; then
        pass "system_maintenance.sh completed."
    else
        warn "system_maintenance.sh completed with errors (see above)."
    fi
    exit "${rc}"
}

main "$@"
