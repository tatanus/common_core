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
# NAME        : install_extras.sh
# DESCRIPTION : Installs the optional tools that bash_setup's interactive
#               shell expects (eza, fzf, freeze, bat, duf, btop) and adds the
#               eza-community apt repository with a signed-by keyring.
#               Complements install.sh (which deploys the dotfiles); this is
#               the system-side tool setup.
#
#               System MAINTENANCE (apt upgrade, stale /pentest/* sweep, apt
#               cleanup, disk report) is NOT here -- see system_maintenance.sh.
#
#               NOTE: tool installation now overlaps install_tools.sh, which
#               covers the same tools cross-platform (apt + Homebrew) from a
#               single declarative table. install_tools.sh is the preferred
#               entrypoint; this script is retained for the eza-community repo
#               setup it still owns.
# AUTHOR      : Adam Compton
# DATE CREATED: 2026-06-29
# =============================================================================

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

# PROXY: dynamic command prefix, matching the stack-wide convention used in
# pentest_setup/config/config.sh and scripts/bash/wireless.sh.
# Auto-detection happens later in main(), AFTER common_core is sourced and
# CLI flags are parsed. The detection probes actual Internet reachability
# rather than just checking whether proxychains4 is installed. See
# `net::proxy_auto_detect` in common_core/lib/utils/util_net.sh.
#
# Override at runtime:
#   --no-proxy           force PROXY=""
#   --proxy CMD          set PROXY=CMD verbatim
#   PROXY=... ./install_extras.sh   environment override (also honored)

# Raise the default log level BEFORE sourcing util.sh. common_core defaults to
# "warn" (see util.sh's _UTIL_CURRENT_LOG_LEVEL), which silently swallows every
# info()/pass() call below -- this script previously ran to completion printing
# nothing at all on success.
export UTIL_LOG_LEVEL="${UTIL_LOG_LEVEL:-info}"

DRY_RUN="${DRY_RUN:-false}"

# Tools to install via apt (single batched call -> one cache scan, not six).
APT_TOOLS=(
    eza
    fzf
    bat
    ncat # bash.aliases.sh aliases nc -> ncat; was declared in bash_setup's
    # RECOMMENDED_TOOLS but never actually installed by anything.
    duf
    btop
)

# Tools installed via `go install <module>@version`.
GO_TOOLS=(
    "github.com/charmbracelet/freeze@latest"
)

# NOTE: the STALE_PENTEST_DIRS list moved to system_maintenance.sh along with
# the sweep that consumes it -- one canonical copy, no drift.

# eza-community signed apt repo metadata
EZA_KEY_URL="https://raw.githubusercontent.com/eza-community/eza/main/deb.asc"
EZA_KEYRING="/etc/apt/keyrings/gierens.gpg"
EZA_SOURCES_LIST="/etc/apt/sources.list.d/gierens.list"

# -----------------------------------------------------------------------------
# Source common_core's util.sh for the proxy / net / log helpers.
#
# install_extras.sh lives at the root of the common_core repo (sibling of
# install.sh + lib/), so prefer the in-repo copy -- that way the script
# works on a fresh `git clone` BEFORE the user has run common_core's own
# install.sh to deploy lib/ to ~/.config/bash/lib/common_core/. Falls back
# to the deployed copy if running from somewhere else, and finally to
# minimal inline fallbacks if neither is reachable (e.g. someone
# `curl ... | bash`'d the raw file).
# -----------------------------------------------------------------------------
if [[ -z "${UTILS_SH_LOADED:-}" ]]; then
    _SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -r "${_SCRIPT_DIR}/lib/util.sh" ]]; then
        # In-repo copy (fresh clone, no deploy required)
        # shellcheck source=/dev/null
        source "${_SCRIPT_DIR}/lib/util.sh"
    elif [[ -r "${HOME}/.config/bash/lib/common_core/util.sh" ]]; then
        # Deployed copy
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
if ! declare -F error > /dev/null 2>&1; then
    function error() { printf '[ERROR] %s\n' "$*" >&2; }
fi
if ! declare -F pass > /dev/null 2>&1; then
    function pass() { printf '[PASS ] %s\n' "$*" >&2; }
fi
if ! declare -F fail > /dev/null 2>&1; then
    function fail() { printf '[FAIL ] %s\n' "$*" >&2; }
fi

###############################################################################
# detect_proxy
#------------------------------------------------------------------------------
# Purpose  : Set ${PROXY} based on actual Internet reachability. Delegates
#            to common_core's `net::proxy_auto_detect` if available; falls
#            back to an inline implementation so install_extras.sh can run
#            standalone (e.g. on a machine where bash_setup install.sh has
#            not yet deployed common_core).
# Returns  : 0 always; PROXY is exported (possibly empty).
###############################################################################
function detect_proxy() {
    if declare -F net::proxy_auto_detect > /dev/null 2>&1; then
        net::proxy_auto_detect
        return 0
    fi

    # --- Inline fallback (mirrors net::proxy_auto_detect in common_core) ---
    if [[ -n "${PROXY+x}" ]]; then
        export PROXY
        return 0
    fi

    # Direct-Internet probe (TCP/443 on anycast endpoints, 2s timeout each)
    local host
    for host in 1.1.1.1 8.8.8.8 9.9.9.9; do
        if timeout 2 bash -c ">/dev/tcp/${host}/443" 2> /dev/null; then
            export PROXY=""
            info "Direct Internet reachable; PROXY left empty"
            return 0
        fi
    done

    # proxychains4 installed AND has a real ProxyList entry?
    if command -v proxychains4 > /dev/null 2>&1; then
        local conf usable=0
        for conf in /etc/proxychains4.conf /etc/proxychains.conf \
            "${HOME}/.proxychains/proxychains.conf"; do
            [[ -r "${conf}" ]] || continue
            if awk '
                /^\s*\[ProxyList\]/ { in_list = 1; next }
                in_list && /^\s*\[/  { in_list = 0; next }
                in_list && /^\s*(socks4|socks5|http|raw)\b/ { print; exit 0 }
            ' "${conf}" | grep -q .; then
                usable=1
                break
            fi
        done
        if ((usable == 1)); then
            export PROXY="proxychains4 -q"
            info "Direct Internet unreachable; using PROXY='${PROXY}'"
            return 0
        fi
    fi

    warn "Direct Internet unreachable AND proxychains4 not usable; continuing with PROXY=''"
    export PROXY=""
}

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

###############################################################################
# run
#------------------------------------------------------------------------------
# Purpose  : Echo + execute a command, honoring DRY_RUN and the dynamic
#            ${PROXY} prefix. When PROXY is empty the command runs directly;
#            otherwise PROXY is split into tokens and prepended.
# Usage    : run apt install -y curl
# Arguments: command and arguments to execute
# Returns  : exit code of the command (or 0 in dry-run)
###############################################################################
function run() {
    if [[ "${DRY_RUN}" == "true" ]]; then
        # Use a locally-scoped IFS so "$*" joins args with spaces even though
        # the project-wide IFS=$'\n\t' would otherwise join them with newlines.
        local IFS=' '
        printf '[DRY-RUN] %s %s\n' "${PROXY}" "$*" >&2
        return 0
    fi
    if [[ -n "${PROXY}" ]]; then
        # Word-splitting PROXY into the command line is intentional -- it is
        # a space-separated command prefix, not a single token.
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
        fail "install_extras.sh must run as root (try: sudo $0)"
        exit 1
    fi
}

###############################################################################
# require_apt_platform
#------------------------------------------------------------------------------
# Purpose  : Refuse to run anywhere apt is not the package manager.
#
#            Every phase in this script is Debian-specific: apt update, a
#            /etc/apt/keyrings GPG import, a /etc/apt/sources.list.d deb line,
#            and apt tool installs. On macOS the first `apt update` would simply
#            fail "command not found" after the script had already demanded a
#            sudo password -- so fail fast, with a pointer to the cross-platform
#            script instead.
#
# Returns  : PASS on an apt host; exits 1 otherwise
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
        fail "install_extras.sh is Debian/Kali-only (detected: ${host_os})."
        fail "For a cross-platform tool install, use:"
        fail "    ./install_tools.sh --check     # see what is missing"
        fail "    ./install_tools.sh             # install it"
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

Installs the optional tools that bash_setup's interactive shell expects
(eza, fzf, freeze, bat, duf, btop) and adds the eza-community signed apt
repository. System maintenance (apt upgrade, stale /pentest/* sweep, apt
cleanup) now lives in system_maintenance.sh.

OPTIONS:
    -n, --dry-run     Print what would happen; do not modify the system
    --no-proxy        Force PROXY="" (skip proxychains4 for this run)
    --proxy CMD       Use CMD as the proxy prefix (e.g. "proxychains4 -q")
    -h, --help        Show this message

ENVIRONMENT:
    PROXY             Override the proxy prefix. Empty disables proxying.
                      Unset triggers auto-detection of proxychains4.
    DRY_RUN           Set to "true" for --dry-run behavior.

EXAMPLES:
    sudo PROXY="" ./install_extras.sh        # direct, no proxychains
    sudo ./install_extras.sh --dry-run       # preview only
    sudo ./install_extras.sh                 # default: auto-detect proxychains
EOF
}

# -----------------------------------------------------------------------------
# Phases
# -----------------------------------------------------------------------------

function update_system() {
    info "Updating apt package lists..."
    run apt update || {
        fail "apt update failed"
        return 1
    }

    # NB: the `apt upgrade` pass moved to system_maintenance.sh. Provisioning
    # tools should not silently upgrade every installed package as a side
    # effect; that is a maintenance decision the operator makes explicitly.

    info "Ensuring gpg is installed (needed for keyring import)..."
    run apt install -y gpg || {
        fail "apt install gpg failed"
        return 1
    }
}

function add_eza_repo() {
    info "Adding eza-community apt repository..."

    if [[ -f "${EZA_KEYRING}" && -f "${EZA_SOURCES_LIST}" ]]; then
        info "eza repo already configured; skipping."
        return 0
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
        info "[DRY-RUN] mkdir -p /etc/apt/keyrings"
        info "[DRY-RUN] ${PROXY} wget -qO- ${EZA_KEY_URL} | gpg --dearmor -o ${EZA_KEYRING}"
        info "[DRY-RUN] write deb-line to ${EZA_SOURCES_LIST}"
        info "[DRY-RUN] apt update"
        return 0
    fi

    mkdir -p /etc/apt/keyrings || {
        fail "mkdir /etc/apt/keyrings failed"
        return 1
    }

    # Fetch the signing key over the (optional) proxy, then dearmor LOCALLY.
    # Splitting fetch from dearmor keeps the keyring import out of the proxied
    # pipeline so a pipefail on either side surfaces clearly.
    if [[ -n "${PROXY}" ]]; then
        # shellcheck disable=SC2086
        ${PROXY} wget -qO- "${EZA_KEY_URL}" | gpg --dearmor -o "${EZA_KEYRING}"
    else
        wget -qO- "${EZA_KEY_URL}" | gpg --dearmor -o "${EZA_KEYRING}"
    fi
    if [[ ! -s "${EZA_KEYRING}" ]]; then
        fail "Failed to fetch / import eza GPG key (keyring empty)"
        return 1
    fi

    printf 'deb [arch=amd64 signed-by=%s] http://deb.gierens.de stable main\n' "${EZA_KEYRING}" |
        tee "${EZA_SOURCES_LIST}" > /dev/null

    chmod 644 "${EZA_KEYRING}" "${EZA_SOURCES_LIST}"
    pass "eza repo configured"

    info "Refreshing apt cache with new repository..."
    run apt update || {
        fail "apt update (post-repo) failed"
        return 1
    }
}

function install_apt_tools() {
    if [[ "${#APT_TOOLS[@]}" -eq 0 ]]; then
        info "No apt tools to install."
        return 0
    fi
    info "Installing apt tools: ${APT_TOOLS[*]}"
    run apt install -y "${APT_TOOLS[@]}" || {
        fail "Failed to install apt tools: ${APT_TOOLS[*]}"
        return 1
    }
    pass "Installed (apt): ${APT_TOOLS[*]}"
}

function install_go_tools() {
    if [[ "${#GO_TOOLS[@]}" -eq 0 ]]; then
        return 0
    fi

    if ! command -v go > /dev/null 2>&1; then
        warn "go is not on PATH; skipping go install: ${GO_TOOLS[*]}"
        return 0
    fi

    # This script requires root, but `go install` writes to the *invoking*
    # user's GOPATH. Running it as root drops the binary in /root/go/bin, off
    # the user's PATH -- so freeze would report as installed yet be unusable.
    # Drop back to the sudo caller when we know who they are.
    local -a as_user=()
    if [[ "${EUID:-65535}" -eq 0 && -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        info "Running go install as ${SUDO_USER} (keeps binaries in their GOPATH)"
        as_user=(sudo -u "${SUDO_USER}" -H)
    elif [[ "${EUID:-65535}" -eq 0 ]]; then
        warn "Running go install as root; binaries will land in root's GOPATH"
    fi

    local tool
    for tool in "${GO_TOOLS[@]}"; do
        info "go install ${tool}"
        run "${as_user[@]}" go install "${tool}" || {
            fail "go install ${tool} failed"
            return 1
        }
    done
    pass "Installed (go): ${GO_TOOLS[*]}"
}

# NOTE: The stale-/pentest/* sweep, the `apt upgrade` pass, apt cleanup, and
# the disk-usage report used to live here. They are system MAINTENANCE, not
# tool installation, and now live in a single-purpose sibling script,
# system_maintenance.sh, so there is exactly one copy of the stale-dir list to
# keep current. Run that after this if you want to patch and tidy the box.

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
            --no-proxy)
                # Explicit empty (overrides any env value and disables detect).
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

    # Platform gate first: checking the OS before demanding root means a macOS
    # user gets a useful error instead of a sudo prompt followed by one.
    require_apt_platform

    if [[ "${DRY_RUN}" != "true" ]]; then
        require_root
    fi

    # Pick PROXY based on actual Internet reachability rather than just
    # "is proxychains4 installed". Honors PROXY explicitly set above.
    detect_proxy

    info "PROXY prefix: '${PROXY:-(none)}'"
    info "Dry-run:      ${DRY_RUN}"
    echo ""

    update_system
    add_eza_repo
    install_apt_tools
    install_go_tools

    echo ""
    pass "install_extras.sh completed."
    info "For system maintenance (apt upgrade, /pentest sweep, cleanup) run: system_maintenance.sh"
}

main "$@"
