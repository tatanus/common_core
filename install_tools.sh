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
# NAME        : install_tools.sh
# DESCRIPTION : Canonical external-tool bootstrapper for the
#               common_core -> bash_setup -> scripts -> pentest_setup stack.
#
#               Every command the stack shells out to but does NOT ship
#               itself is declared once in TOOL_SPECS below, together with
#               the apt and Homebrew package that provides it. The script
#               resolves the right package manager for the host, installs
#               what is missing, and verifies the result.
#
#               This lives in common_core because common_core is the bottom
#               of the load order: bash_setup's dotfiles, scripts/bash/*,
#               and pentest_setup's menus all assume these binaries exist,
#               and per the load-order contract that dependency belongs in
#               the earliest repo, not in a workaround downstream.
#
#               Pentest tooling (nmap, nuclei, netexec, ...) is deliberately
#               NOT handled here -- pentest_setup/config/lists.sh owns that
#               list and is later in the load order.
#
# AUTHOR      : Adam Compton
# DATE CREATED: 2026-09-01
# =============================================================================

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

# Raise the default log level BEFORE sourcing util.sh. common_core defaults to
# "warn", which silently swallows every info()/pass() call -- an installer that
# prints nothing on success is indistinguishable from one that did nothing.
export UTIL_LOG_LEVEL="${UTIL_LOG_LEVEL:-info}"

DRY_RUN="${DRY_RUN:-false}"
CHECK_ONLY="false"

# Package manager resolved in main(); one of: apt, brew
PKG_MANAGER=""

# eza-community signed apt repo. eza is not in the Debian/Kali base repos, so
# on apt hosts the repo must be configured before `apt install eza` can work.
# (macOS installs eza straight from Homebrew and needs none of this.)
readonly EZA_KEY_URL="https://raw.githubusercontent.com/eza-community/eza/main/deb.asc"
readonly EZA_KEYRING="/etc/apt/keyrings/gierens.gpg"
readonly EZA_SOURCES_LIST="/etc/apt/sources.list.d/gierens.list"

# Host OS resolved in main(); one of: linux, macos
HOST_OS=""

# Groups selected on the command line (empty array == all groups)
declare -a SELECTED_GROUPS=()

# All known groups, in install order.
declare -ra ALL_GROUPS=(core shell gnu dev)

###############################################################################
# GROUP_PLATFORMS
#------------------------------------------------------------------------------
# Which hosts a whole group is meaningful on. A group that does not apply is
# skipped before any of its records are examined, so `--group gnu` on Linux
# reports "not applicable on linux" instead of walking eleven records and
# printing a "no apt package" line for each.
#
# The gnu group exists only because macOS ships BSD userland: bash.aliases.sh
# aliases sed/grep to gsed/ggrep and util_platform.sh's platform::find_command
# looks for the g-prefixed binaries. On Linux those *are* the system tools, so
# there is nothing to install.
###############################################################################
declare -rA GROUP_PLATFORMS=(
    [core]="all"
    [shell]="all"
    [gnu]="macos"
    [dev]="all"
)

###############################################################################
# TOOL_SPECS
#------------------------------------------------------------------------------
# One record per tool, pipe-separated:
#
#   group | platforms | mode | commands | apt-package | brew-package | description
#
#   group     : one of ALL_GROUPS (see --list / --group)
#   platforms : "all", or a comma-separated subset of {linux, macos}. A record
#               that does not apply to the host is never probed, never
#               installed, and never reported as missing.
#   mode      : "any" -> satisfied when ANY listed command resolves
#               "all" -> satisfied only when EVERY listed command resolves
#   commands  : comma-separated command names to probe on PATH
#   apt       : package name for Debian/Kali, or "-" if unavailable there
#   brew      : formula name for macOS, or "-" if unavailable there
#
# The platforms column and the "-" package columns answer different questions,
# and conflating them is what made the first cut of this script noisy:
#
#   platforms=macos  -> "this tool is meaningless on Linux; say nothing"
#   apt="-"          -> "this tool IS wanted here, but apt cannot supply it;
#                        report honestly if it turns up missing"
#
# unzip is the clean example of the second case: macOS ships it, so there is no
# brew formula to install, but it is still a genuine requirement on both hosts.
###############################################################################
declare -ra TOOL_SPECS=(
    # --- core: assumed by every repo's install.sh / config.sh -----------------
    "core|all|any|git|git|git|Version control; pentest_setup REQUIRED_TOOLS"
    "core|all|any|curl|curl|curl|HTTP client; pentest_setup REQUIRED_TOOLS"
    "core|all|any|wget|wget|wget|Used to fetch signing keys and release tarballs"
    "core|all|any|gpg|gnupg|gnupg|Keyring import for signed apt repositories"
    "core|all|any|jq|jq|jq|JSON processor; cmd::exists jq across the stack"
    "core|all|any|tree|tree|tree|Directory visualizer; pentest_setup SUGGESTED_TOOLS"
    "core|all|any|unzip|unzip|-|Archive extraction (macOS ships unzip)"
    "core|all|any|rsync|rsync|rsync|Used by the file:: helpers and engagement sync"

    # --- shell: bash_setup RECOMMENDED_TOOLS + dotfile aliases ---------------
    "shell|all|any|eza|eza|eza|ls replacement; bash.aliases.sh + bash.funcs.sh ls2eza"
    "shell|all|any|fzf|fzf|fzf|Fuzzy finder; REQUIRED by pentest_setup's menu system"
    "shell|all|any|bat,batcat|bat|bat|Colorized cat; Debian names the binary batcat"
    "shell|all|any|ncat|ncat|nmap|Preferred nc; bash.aliases.sh aliases nc -> ncat"
    "shell|all|any|duf|duf|duf|Disk-usage report; used by the installers' summary"
    "shell|all|any|btop|btop|btop|Process viewer"
    "shell|all|any|tmux|tmux|tmux|Multiplexer; tmux.aliases.sh"
    "shell|all|any|screen|screen|screen|Multiplexer; screen.aliases.sh"
    "shell|all|any|dialog|dialog|dialog|TUI menus; cmd::exists dialog in util_menu.sh"
    "shell|all|any|proxychains4|proxychains4|proxychains-ng|Proxy prefix used by \${PROXY}"
    # X11/Wayland clipboard: Linux only. macOS uses pbpaste, which is built in,
    # so freezeCmd's clipboard path needs nothing installed there.
    "shell|linux|any|xclip,wl-paste|xclip|-|Clipboard read for freezeCmd"

    # --- gnu: macOS only (enforced by GROUP_PLATFORMS as well, so a future ----
    #     record added here cannot accidentally leak onto Linux).
    "gnu|macos|all|gsed|-|gnu-sed|GNU sed; platform::find_command sed gsed"
    "gnu|macos|all|ggrep|-|grep|GNU grep; bash.aliases.sh aliases grep -> ggrep"
    "gnu|macos|all|gawk|-|gawk|GNU awk; platform::find_command awk gawk"
    "gnu|macos|all|gtar|-|gnu-tar|GNU tar; platform::find_command tar gtar"
    "gnu|macos|all|gfind,gxargs|-|findutils|GNU find/xargs; platform::find_command"
    "gnu|macos|all|gdate,gstat,greadlink,gtimeout,gdircolors|-|coreutils|GNU coreutils; platform::check_gnu_tools"

    # --- dev: the gates CLAUDE.md mandates (make lint / fmt / test / style) --
    "dev|all|any|shellcheck|shellcheck|shellcheck|make lint"
    "dev|all|any|shfmt|shfmt|shfmt|make fmt (-i 4 -ci -sr)"
    "dev|all|any|bats|bats|bats-core|make test"
    "dev|all|any|go|golang-go|go|Toolchain for the go-installed tools below"
)

###############################################################################
# GO_TOOLS
#------------------------------------------------------------------------------
# command -> go module path. These have no apt/brew package we want to depend
# on, so they are installed with `go install` after the package phase.
#
# freeze is the one bash_setup actually documents this way: bash.funcs.sh's
# freezeCmd prints "go install github.com/charmbracelet/freeze@latest" when the
# binary is missing, so installing it any other way would drift from the
# in-repo instructions.
###############################################################################
declare -rA GO_TOOLS=(
    [freeze]="github.com/charmbracelet/freeze@latest"
)

###############################################################################
# GO_FALLBACK
#------------------------------------------------------------------------------
# command -> go module path, used ONLY when the packaged install left the
# command missing (older Debian has no shfmt package, for example).
###############################################################################
declare -rA GO_FALLBACK=(
    [shfmt]="mvdan.cc/sh/v3/cmd/shfmt@latest"
)

# -----------------------------------------------------------------------------
# Source common_core's util.sh
#
# Prefer the in-repo copy so the script works on a fresh `git clone`, before
# common_core's own install.sh has deployed lib/ to
# ~/.config/bash/lib/common_core/. Falls back to the deployed copy, then to
# minimal inline logging so the script still runs standalone.
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
if ! declare -F error > /dev/null 2>&1; then
    function error() { printf '[ERROR] %s\n' "$*" >&2; }
fi
if ! declare -F pass > /dev/null 2>&1; then
    function pass() { printf '[PASS ] %s\n' "$*" >&2; }
fi
if ! declare -F fail > /dev/null 2>&1; then
    function fail() { printf '[FAIL ] %s\n' "$*" >&2; }
fi
if ! declare -F debug > /dev/null 2>&1; then
    function debug() { :; }
fi

# PASS/FAIL come from util.sh; provide them if we are running standalone.
: "${PASS:=0}"
: "${FAIL:=1}"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

###############################################################################
# spec_field
#------------------------------------------------------------------------------
# Purpose  : Extract the Nth pipe-separated field from a TOOL_SPECS record.
# Usage    : spec_field "${record}" 3
# Arguments:
#   $1 : the record
#   $2 : 1-based field index
# Returns  : PASS; field written to stdout
###############################################################################
function spec_field() {
    local record="${1:-}" index="${2:-1}"
    local -a fields=()
    local IFS='|'
    read -ra fields <<< "${record}"
    printf '%s\n' "${fields[$((index - 1))]:-}"
    return "${PASS}"
}

###############################################################################
# have_command
#------------------------------------------------------------------------------
# Purpose  : Test whether a command resolves on PATH.
# Usage    : have_command gsed
# Returns  : PASS if found, FAIL otherwise
###############################################################################
function have_command() {
    command -v "${1:-}" > /dev/null 2>&1
}

###############################################################################
# detect_host_os
#------------------------------------------------------------------------------
# Purpose  : Resolve HOST_OS to "linux" or "macos". Prefers common_core's
#            os::detect (which normalizes via platform::detect_os) and falls
#            back to uname so the script still classifies correctly when run
#            standalone from a fresh clone.
# Returns  : PASS if the host is supported, FAIL otherwise
# Globals  : sets HOST_OS
###############################################################################
function detect_host_os() {
    if declare -F os::detect > /dev/null 2>&1; then
        HOST_OS="$(os::detect)"
    else
        case "$(uname -s 2> /dev/null)" in
            Darwin) HOST_OS="macos" ;;
            Linux) HOST_OS="linux" ;;
            *) HOST_OS="" ;;
        esac
    fi

    # os::detect reports WSL as its own platform; for packaging purposes WSL
    # is Debian userland under apt, so treat it as linux rather than bailing.
    if [[ "${HOST_OS}" == "wsl" ]]; then
        debug "WSL detected; treating as linux for packaging"
        HOST_OS="linux"
    fi

    case "${HOST_OS}" in
        linux | macos)
            info "Host OS: ${HOST_OS}"
            return "${PASS}"
            ;;
        *)
            fail "Unsupported host OS: '${HOST_OS:-unknown}' (need linux or macos)"
            return "${FAIL}"
            ;;
    esac
}

###############################################################################
# platform_applies
#------------------------------------------------------------------------------
# Purpose  : Test whether a platforms field covers the current HOST_OS.
# Usage    : platform_applies "macos"  /  platform_applies "all"
# Arguments:
#   $1 : platforms field ("all", or comma-separated linux/macos)
# Returns  : PASS if applicable to this host, FAIL otherwise
###############################################################################
function platform_applies() {
    local platforms="${1:-all}"
    local -a list=()
    local p

    [[ "${platforms}" == "all" ]] && return "${PASS}"

    local IFS=','
    read -ra list <<< "${platforms}"
    unset IFS

    for p in "${list[@]}"; do
        [[ "${p}" == "${HOST_OS}" ]] && return "${PASS}"
    done
    return "${FAIL}"
}

###############################################################################
# group_applies
#------------------------------------------------------------------------------
# Purpose  : Test whether an entire group is meaningful on this host, per
#            GROUP_PLATFORMS. Checked before any record in the group is read.
# Usage    : group_applies gnu
# Returns  : PASS if the group applies here, FAIL otherwise
###############################################################################
function group_applies() {
    local group="${1:-}"
    platform_applies "${GROUP_PLATFORMS[${group}]:-all}"
}

###############################################################################
# spec_satisfied
#------------------------------------------------------------------------------
# Purpose  : Decide whether a spec's commands are already present, honoring
#            the record's "any"/"all" mode.
# Usage    : spec_satisfied "any" "bat,batcat"
# Arguments:
#   $1 : mode ("any" or "all")
#   $2 : comma-separated command list
# Returns  : PASS if satisfied, FAIL otherwise
###############################################################################
function spec_satisfied() {
    local mode="${1:-any}" commands="${2:-}"
    local -a cmds=()
    local c
    local IFS=','
    read -ra cmds <<< "${commands}"
    unset IFS

    if [[ "${mode}" == "all" ]]; then
        for c in "${cmds[@]}"; do
            have_command "${c}" || return "${FAIL}"
        done
        return "${PASS}"
    fi

    for c in "${cmds[@]}"; do
        have_command "${c}" && return "${PASS}"
    done
    return "${FAIL}"
}

###############################################################################
# missing_commands
#------------------------------------------------------------------------------
# Purpose  : Print the commands from a spec that are absent from PATH.
# Usage    : missing_commands "gdate,gstat"
# Returns  : PASS; missing command names on stdout, one per line
###############################################################################
function missing_commands() {
    local commands="${1:-}"
    local -a cmds=()
    local c
    local IFS=','
    read -ra cmds <<< "${commands}"
    unset IFS

    for c in "${cmds[@]}"; do
        have_command "${c}" || printf '%s\n' "${c}"
    done
    return "${PASS}"
}

###############################################################################
# group_selected
#------------------------------------------------------------------------------
# Purpose  : Test whether a group should be processed this run.
# Usage    : group_selected gnu
# Returns  : PASS if selected (or if no --group filter was given)
###############################################################################
function group_selected() {
    local group="${1:-}" g

    if [[ "${#SELECTED_GROUPS[@]}" -eq 0 ]]; then
        return "${PASS}"
    fi

    for g in "${SELECTED_GROUPS[@]}"; do
        [[ "${g}" == "${group}" ]] && return "${PASS}"
    done
    return "${FAIL}"
}

###############################################################################
# detect_proxy
#------------------------------------------------------------------------------
# Purpose  : Set ${PROXY} based on actual Internet reachability. Delegates to
#            common_core's net::proxy_auto_detect when available; otherwise
#            leaves PROXY empty rather than guessing.
# Returns  : PASS always; PROXY is exported (possibly empty)
###############################################################################
function detect_proxy() {
    if [[ -n "${PROXY+x}" ]]; then
        export PROXY
        return "${PASS}"
    fi

    if declare -F net::proxy_auto_detect > /dev/null 2>&1; then
        net::proxy_auto_detect
        return "${PASS}"
    fi

    warn "net::proxy_auto_detect unavailable (common_core not sourced); PROXY=''"
    export PROXY=""
    return "${PASS}"
}

###############################################################################
# detect_pkg_manager
#------------------------------------------------------------------------------
# Purpose  : Resolve PKG_MANAGER from HOST_OS and enforce the privilege model
#            that manager requires.
#
#            apt  : common_core's apt::install shells out to `apt-get` with no
#                   sudo of its own, so the script must already be root.
#            brew : Homebrew refuses to run as root, so the script must NOT be.
#
#            The manager is chosen by OS, not by "whichever binary is on PATH
#            first". Probing order alone gets Linuxbrew hosts wrong: a Debian
#            box with Homebrew installed would be driven entirely through brew,
#            installing macOS formula names (bats-core, gnu-sed) on a system
#            whose packages are named bats and where sed is already GNU.
#
# Requires : detect_host_os must have run (HOST_OS set)
# Returns  : PASS if a usable manager was found, FAIL otherwise
# Globals  : sets PKG_MANAGER
###############################################################################
function detect_pkg_manager() {
    case "${HOST_OS}" in
        linux)
            if ! have_command apt-get; then
                fail "Linux host without apt-get; only Debian/Kali derivatives are supported."
                return "${FAIL}"
            fi
            PKG_MANAGER="apt"
            if [[ "${EUID:-65535}" -ne 0 && "${DRY_RUN}" != "true" && "${CHECK_ONLY}" != "true" ]]; then
                fail "apt installs require root (try: sudo $0)"
                return "${FAIL}"
            fi
            ;;
        macos)
            if ! have_command brew; then
                fail "macOS host without Homebrew. Install it first:"
                # shellcheck disable=SC2016  # Printed verbatim for the user to copy; must NOT expand.
                fail '    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
                return "${FAIL}"
            fi
            PKG_MANAGER="brew"
            if [[ "${EUID:-65535}" -eq 0 ]]; then
                fail "Homebrew must not be run as root. Re-run without sudo."
                return "${FAIL}"
            fi
            ;;
        *)
            fail "Cannot resolve a package manager for host OS '${HOST_OS:-unknown}'"
            return "${FAIL}"
            ;;
    esac

    info "Package manager: ${PKG_MANAGER}"
    return "${PASS}"
}

###############################################################################
# pkg_column
#------------------------------------------------------------------------------
# Purpose  : Return the package name for the active manager from a record.
# Usage    : pkg_column "${record}"
# Returns  : PASS; package name (or "-") on stdout
###############################################################################
function pkg_column() {
    local record="${1:-}"
    case "${PKG_MANAGER}" in
        apt) spec_field "${record}" 5 ;;
        brew) spec_field "${record}" 6 ;;
        *) printf '%s\n' "-" ;;
    esac
    return "${PASS}"
}

###############################################################################
# record_applies
#------------------------------------------------------------------------------
# Purpose  : Single gate deciding whether a TOOL_SPECS record is in scope for
#            this run: its group must be selected on the command line, its
#            group must be meaningful on this OS, and the record's own
#            platforms field must cover this OS.
# Usage    : record_applies "${record}"
# Returns  : PASS if the record should be processed, FAIL otherwise
###############################################################################
function record_applies() {
    local record="${1:-}"
    local group platforms

    group="$(spec_field "${record}" 1)"
    group_selected "${group}" || return "${FAIL}"
    group_applies "${group}" || return "${FAIL}"

    platforms="$(spec_field "${record}" 2)"
    platform_applies "${platforms}" || return "${FAIL}"

    return "${PASS}"
}

###############################################################################
# install_packages
#------------------------------------------------------------------------------
# Purpose  : Install a batch of packages through the active manager, preferring
#            common_core's apt::/brew:: helpers and falling back to a direct
#            call when running standalone.
# Usage    : install_packages git curl jq
# Returns  : PASS on success, FAIL otherwise
###############################################################################
function install_packages() {
    if [[ $# -eq 0 ]]; then
        return "${PASS}"
    fi

    local IFS=' '
    if [[ "${DRY_RUN}" == "true" ]]; then
        info "[DRY-RUN] install via ${PKG_MANAGER}: $*"
        return "${PASS}"
    fi

    case "${PKG_MANAGER}" in
        apt)
            if declare -F apt::ensure_installed > /dev/null 2>&1; then
                apt::ensure_installed "$@"
                return $?
            fi
            apt-get install -y "$@"
            return $?
            ;;
        brew)
            if declare -F brew::ensure_installed > /dev/null 2>&1; then
                brew::ensure_installed "$@"
                return $?
            fi
            brew install "$@"
            return $?
            ;;
        *)
            fail "install_packages: unknown package manager '${PKG_MANAGER}'"
            return "${FAIL}"
            ;;
    esac
}

###############################################################################
# go_install
#------------------------------------------------------------------------------
# Purpose  : `go install` a module, taking care to build into the *invoking*
#            user's GOPATH rather than root's when the script was started with
#            sudo -- otherwise the binary lands in /root/go/bin, off the user's
#            PATH, and the tool looks installed but is unusable.
# Usage    : go_install github.com/charmbracelet/freeze@latest
# Returns  : PASS on success, FAIL otherwise
###############################################################################
function go_install() {
    local module="${1:-}"

    if [[ -z "${module}" ]]; then
        error "go_install requires a module path"
        return "${FAIL}"
    fi

    if ! have_command go; then
        warn "go is not on PATH; skipping: ${module}"
        return "${FAIL}"
    fi

    local -a prefix=()
    if [[ "${EUID:-65535}" -eq 0 && -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        info "Running go install as ${SUDO_USER} (keeps the binary in their GOPATH)"
        prefix=(sudo -u "${SUDO_USER}" -H)
    elif [[ "${EUID:-65535}" -eq 0 ]]; then
        warn "Running go install as root; binary will land in root's GOPATH"
    fi

    if [[ -n "${PROXY:-}" ]]; then
        # PROXY is a space-separated command prefix, not a single token.
        local -a proxy_tokens=()
        IFS=$' \t\n' read -ra proxy_tokens <<< "${PROXY}"
        prefix=("${proxy_tokens[@]}" "${prefix[@]}")
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
        local IFS=' '
        info "[DRY-RUN] ${prefix[*]:-} go install ${module}"
        return "${PASS}"
    fi

    info "go install ${module}"
    if "${prefix[@]}" go install "${module}"; then
        pass "Installed: ${module}"
        return "${PASS}"
    fi

    fail "go install failed: ${module}"
    return "${FAIL}"
}

###############################################################################
# check_go_path
#------------------------------------------------------------------------------
# Purpose  : Warn when GOPATH/bin is not on PATH, which is the usual reason a
#            freshly `go install`ed tool still reports as missing.
# Returns  : PASS always
###############################################################################
function check_go_path() {
    have_command go || return "${PASS}"

    local gobin
    gobin="$(go env GOPATH 2> /dev/null)/bin" || return "${PASS}"

    if [[ ":${PATH}:" != *":${gobin}:"* ]]; then
        warn "${gobin} is not on PATH -- go-installed tools will not resolve."
        warn "Add it in bash_setup's dotfiles/path.env.sh, or export it manually:"
        warn "    export PATH=\"\${PATH}:${gobin}\""
    fi
    return "${PASS}"
}

# -----------------------------------------------------------------------------
# Reporting
# -----------------------------------------------------------------------------

###############################################################################
# show_usage
###############################################################################
function show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Installs and verifies the external commands that common_core, bash_setup,
scripts, and pentest_setup shell out to but do not ship themselves.
Supports apt (Debian/Kali) and Homebrew (macOS).

OPTIONS:
    -c, --check           Report what is missing; install nothing
    -n, --dry-run         Print what would be installed; change nothing
    -g, --group GROUPS    Comma-separated subset of: ${ALL_GROUPS[*]}
    -l, --list            List every declared tool and exit
        --no-proxy        Force PROXY="" for this run
        --proxy CMD       Use CMD as the proxy prefix (e.g. "proxychains4 -q")
    -h, --help            Show this message

GROUPS:
    core    [all]    git, curl, wget, gpg, jq, tree, unzip, rsync
    shell   [all]    eza, fzf, bat/batcat, ncat, duf, btop, tmux, screen,
                     dialog, proxychains4 (+ freeze via 'go install');
                     xclip/wl-paste on Linux only -- macOS uses pbpaste
    gnu     [macOS]  gsed, ggrep, gawk, gtar, gfind, gxargs, gdate, gstat,
                     greadlink, gtimeout, gdircolors. Skipped entirely on
                     Linux, where these ARE the system tools.
    dev     [all]    shellcheck, shfmt, bats, go -- the 'make lint/fmt/test' gates

PLATFORM BEHAVIOR:
    The package manager is chosen from the detected OS, not from whichever
    binary happens to be on PATH -- so a Linux host with Homebrew installed
    still installs Debian package names through apt. Tools that do not apply
    to the host are never probed and never reported as missing; run --list to
    see exactly which rows this machine will skip.

ENVIRONMENT:
    PROXY           Command prefix for network operations. Empty disables it;
                    unset triggers auto-detection.
    DRY_RUN         Set to "true" for --dry-run behavior.
    UTIL_LOG_LEVEL  Defaults to "info" here (common_core's own default is
                    "warn", which hides info/pass output).

EXAMPLES:
    ./$(basename "$0") --check              # audit only, no privileges needed
    sudo ./$(basename "$0")                 # Debian/Kali: install everything
    ./$(basename "$0")                      # macOS: install everything
    sudo ./$(basename "$0") -g core,dev     # just the toolchain gates
EOF
    return "${PASS}"
}

###############################################################################
# list_tools
#------------------------------------------------------------------------------
# Purpose  : Print the full declaration table, apt/brew columns included.
# Returns  : PASS always
###############################################################################
function list_tools() {
    local record group platforms mode commands apt_pkg brew_pkg desc marker

    printf '%-6s %-7s %-44s %-14s %-14s %s\n' \
        "GROUP" "OS" "COMMAND(S)" "APT" "BREW" "PURPOSE"
    printf '%-6s %-7s %-44s %-14s %-14s %s\n' \
        "-----" "--" "----------" "---" "----" "-------"

    for record in "${TOOL_SPECS[@]}"; do
        group="$(spec_field "${record}" 1)"
        platforms="$(spec_field "${record}" 2)"
        mode="$(spec_field "${record}" 3)"
        commands="$(spec_field "${record}" 4)"
        apt_pkg="$(spec_field "${record}" 5)"
        brew_pkg="$(spec_field "${record}" 6)"
        desc="$(spec_field "${record}" 7)"

        [[ "${mode}" == "all" ]] && commands="${commands} (all)"

        # Mark rows that this host will skip, so --list doubles as an
        # explanation of what a run here will and will not touch.
        marker=""
        if [[ -n "${HOST_OS}" ]] && ! record_applies_listing "${record}"; then
            marker="  [skipped on ${HOST_OS}]"
        fi

        printf '%-6s %-7s %-44s %-14s %-14s %s%s\n' \
            "${group}" "${platforms}" "${commands}" \
            "${apt_pkg}" "${brew_pkg}" "${desc}" "${marker}"
    done

    local cmd
    for cmd in "${!GO_TOOLS[@]}"; do
        printf '%-6s %-7s %-44s %-14s %-14s %s\n' \
            "shell" "all" "${cmd}" "go install" "go install" "${GO_TOOLS[${cmd}]}"
    done

    return "${PASS}"
}

###############################################################################
# record_applies_listing
#------------------------------------------------------------------------------
# Purpose  : Platform-only variant of record_applies, used by --list so the
#            "[skipped]" marker reflects the OS alone and is not muddied by a
#            --group filter the user also happened to pass.
# Returns  : PASS if the record applies to this host, FAIL otherwise
###############################################################################
function record_applies_listing() {
    local record="${1:-}"
    local group

    group="$(spec_field "${record}" 1)"
    group_applies "${group}" || return "${FAIL}"
    platform_applies "$(spec_field "${record}" 2)"
}

###############################################################################
# verify_tools
#------------------------------------------------------------------------------
# Purpose  : Probe every selected tool and print a per-tool status line.
# Returns  : PASS if nothing is missing, FAIL otherwise
###############################################################################
function verify_tools() {
    local record mode commands
    local -a still_missing=()
    local pkg_for_platform
    local examined=0

    for record in "${TOOL_SPECS[@]}"; do
        record_applies "${record}" || continue
        ((examined++))

        mode="$(spec_field "${record}" 3)"
        commands="$(spec_field "${record}" 4)"

        if spec_satisfied "${mode}" "${commands}"; then
            pass "${commands}"
            continue
        fi

        # A "-" in this platform's column means the tool is not obtainable
        # here; report it as skipped rather than as a failure.
        pkg_for_platform="$(pkg_column "${record}")"
        if [[ "${pkg_for_platform}" == "-" ]] && [[ -z "${GO_TOOLS[${commands}]:-}" ]]; then
            info "${commands} -- not packaged for ${PKG_MANAGER:-this platform}; skipped"
            continue
        fi

        local m
        while IFS= read -r m; do
            [[ -n "${m}" ]] && still_missing+=("${m}")
        done < <(missing_commands "${commands}")
    done

    # go-installed tools are verified the same way. They are platform-neutral
    # (go install works identically on both hosts), so only the group filter
    # and the shell group's own platform applicability gate them.
    local cmd
    if group_selected "shell" && group_applies "shell"; then
        for cmd in "${!GO_TOOLS[@]}"; do
            ((examined++))
            if have_command "${cmd}"; then
                pass "${cmd}"
            else
                still_missing+=("${cmd}")
            fi
        done
    fi

    if [[ "${#still_missing[@]}" -gt 0 ]]; then
        local IFS=' '
        fail "Still missing: ${still_missing[*]}"
        return "${FAIL}"
    fi

    # Distinguish "everything checked out" from "nothing was applicable here",
    # which otherwise both printed the same reassuring PASS line.
    if [[ "${examined}" -eq 0 ]]; then
        info "No tools applicable to ${HOST_OS} in the selected group(s); nothing checked."
        return "${PASS}"
    fi

    pass "All ${examined} applicable tool(s) present."
    return "${PASS}"
}

# -----------------------------------------------------------------------------
# Phases
# -----------------------------------------------------------------------------

###############################################################################
# refresh_package_lists
#------------------------------------------------------------------------------
# Purpose  : Refresh the package index once, up front, so a batched install
#            does not trigger a cache scan per package.
# Returns  : PASS on success, FAIL otherwise
###############################################################################
###############################################################################
# eza_wanted
#------------------------------------------------------------------------------
# Purpose  : True when eza is applicable + selected this run and not already
#            installed -- i.e. we are actually about to install it.
###############################################################################
function eza_wanted() {
    local record commands mode
    for record in "${TOOL_SPECS[@]}"; do
        commands="$(spec_field "${record}" 4)"
        [[ "${commands}" == "eza" ]] || continue
        record_applies "${record}" || return "${FAIL}"
        mode="$(spec_field "${record}" 3)"
        spec_satisfied "${mode}" "${commands}" && return "${FAIL}"
        return "${PASS}"
    done
    return "${FAIL}"
}

###############################################################################
# ensure_eza_repo
#------------------------------------------------------------------------------
# Purpose  : Configure the eza-community signed apt repository so `apt install
#            eza` resolves on Debian/Kali. No-op unless the manager is apt and
#            eza is actually being installed this run. Idempotent; honors
#            DRY_RUN and ${PROXY}. Writing the repo here (before the package
#            refresh in main) lets the subsequent `apt update` pick it up.
# Returns  : PASS on success or no-op, FAIL if the key import failed
###############################################################################
function ensure_eza_repo() {
    [[ "${PKG_MANAGER}" == "apt" ]] || return "${PASS}"
    eza_wanted || return "${PASS}"

    if [[ -f "${EZA_KEYRING}" && -f "${EZA_SOURCES_LIST}" ]]; then
        debug "eza-community repo already configured"
        return "${PASS}"
    fi
    if [[ "${DRY_RUN}" == "true" ]]; then
        info "[DRY-RUN] add eza-community apt repo -> ${EZA_SOURCES_LIST}"
        return "${PASS}"
    fi
    if ! have_command wget || ! have_command gpg; then
        warn "wget/gpg not available yet; skipping eza-community repo setup"
        return "${PASS}"
    fi

    info "Adding eza-community apt repository (eza is not in the base repos)..."
    mkdir -p /etc/apt/keyrings || {
        fail "mkdir /etc/apt/keyrings failed"
        return "${FAIL}"
    }
    # Fetch the signing key over the optional proxy, then dearmor locally.
    if [[ -n "${PROXY:-}" ]]; then
        # shellcheck disable=SC2086
        ${PROXY} wget -qO- "${EZA_KEY_URL}" | gpg --dearmor -o "${EZA_KEYRING}"
    else
        wget -qO- "${EZA_KEY_URL}" | gpg --dearmor -o "${EZA_KEYRING}"
    fi
    if [[ ! -s "${EZA_KEYRING}" ]]; then
        fail "Failed to import eza GPG key (keyring empty)"
        return "${FAIL}"
    fi
    printf 'deb [arch=amd64 signed-by=%s] http://deb.gierens.de stable main\n' "${EZA_KEYRING}" |
        tee "${EZA_SOURCES_LIST}" > /dev/null
    chmod 644 "${EZA_KEYRING}" "${EZA_SOURCES_LIST}"
    pass "eza-community repo configured"
    return "${PASS}"
}

function refresh_package_lists() {
    if [[ "${DRY_RUN}" == "true" ]]; then
        info "[DRY-RUN] refresh ${PKG_MANAGER} package lists"
        return "${PASS}"
    fi

    case "${PKG_MANAGER}" in
        apt)
            if declare -F apt::update > /dev/null 2>&1; then
                apt::update || {
                    fail "apt update failed"
                    return "${FAIL}"
                }
            else
                apt-get update || {
                    fail "apt-get update failed"
                    return "${FAIL}"
                }
            fi
            ;;
        brew)
            if declare -F brew::update > /dev/null 2>&1; then
                brew::update || warn "brew update failed; continuing"
            else
                brew update || warn "brew update failed; continuing"
            fi
            ;;
        *)
            # Unreachable: detect_pkg_manager only ever sets apt or brew.
            fail "refresh_package_lists: unknown package manager '${PKG_MANAGER}'"
            return "${FAIL}"
            ;;
    esac
    return "${PASS}"
}

###############################################################################
# install_tool_groups
#------------------------------------------------------------------------------
# Purpose  : Walk TOOL_SPECS, collect the packages needed for the tools that
#            are actually missing, and install them in one batched call.
# Returns  : PASS if the batch installed cleanly, FAIL otherwise
###############################################################################
function install_tool_groups() {
    local record group mode commands pkg
    local -a wanted=()

    for record in "${TOOL_SPECS[@]}"; do
        record_applies "${record}" || continue

        mode="$(spec_field "${record}" 3)"
        commands="$(spec_field "${record}" 4)"

        if spec_satisfied "${mode}" "${commands}"; then
            debug "Already satisfied: ${commands}"
            continue
        fi

        pkg="$(pkg_column "${record}")"
        if [[ "${pkg}" == "-" || -z "${pkg}" ]]; then
            info "No ${PKG_MANAGER} package for ${commands}; skipping"
            continue
        fi

        wanted+=("${pkg}")
    done

    if [[ "${#wanted[@]}" -eq 0 ]]; then
        info "Nothing to install from packages."
        return "${PASS}"
    fi

    # De-duplicate: findutils/coreutils style formulas back several commands.
    local -a unique=()
    local p seen
    for p in "${wanted[@]}"; do
        seen="false"
        local u
        for u in "${unique[@]:-}"; do
            [[ "${u}" == "${p}" ]] && {
                seen="true"
                break
            }
        done
        [[ "${seen}" == "false" ]] && unique+=("${p}")
    done

    local IFS=' '
    info "Installing (${PKG_MANAGER}): ${unique[*]}"
    if install_packages "${unique[@]}"; then
        pass "Package phase complete."
        return "${PASS}"
    fi

    fail "Package phase reported errors: ${unique[*]}"
    return "${FAIL}"
}

###############################################################################
# install_go_tools
#------------------------------------------------------------------------------
# Purpose  : Install the go-only tools, then retry any packaged tool that is
#            still missing but has a documented go fallback (e.g. shfmt on
#            distributions that do not package it).
# Returns  : PASS if every attempted install succeeded, FAIL otherwise
###############################################################################
function install_go_tools() {
    local status="${PASS}"
    local cmd

    if group_selected "shell" && group_applies "shell"; then
        for cmd in "${!GO_TOOLS[@]}"; do
            have_command "${cmd}" && {
                debug "Already installed: ${cmd}"
                continue
            }
            go_install "${GO_TOOLS[${cmd}]}" || status="${FAIL}"
        done
    fi

    if group_selected "dev" && group_applies "dev"; then
        for cmd in "${!GO_FALLBACK[@]}"; do
            have_command "${cmd}" && continue
            warn "${cmd} still missing after the package phase; trying go install"
            go_install "${GO_FALLBACK[${cmd}]}" || status="${FAIL}"
        done
    fi

    return "${status}"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

###############################################################################
# parse_args
#------------------------------------------------------------------------------
# Purpose  : Parse CLI options into the module-level configuration globals.
# Returns  : PASS on success; exits non-zero on a bad option
###############################################################################
function parse_args() {
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -c | --check)
                CHECK_ONLY="true"
                shift
                ;;
            -n | --dry-run)
                DRY_RUN="true"
                shift
                ;;
            -g | --group)
                if [[ -z "${2:-}" ]]; then
                    fail "--group requires an argument"
                    exit 2
                fi
                local IFS=','
                read -ra SELECTED_GROUPS <<< "${2}"
                unset IFS
                local g valid
                for g in "${SELECTED_GROUPS[@]}"; do
                    valid="false"
                    local known
                    for known in "${ALL_GROUPS[@]}"; do
                        [[ "${g}" == "${known}" ]] && valid="true"
                    done
                    if [[ "${valid}" == "false" ]]; then
                        fail "Unknown group: ${g} (valid: ${ALL_GROUPS[*]})"
                        exit 2
                    fi
                done
                shift 2
                ;;
            -l | --list)
                # Best-effort OS detection so the listing can mark which rows
                # this host will skip; an unsupported OS just omits the marker.
                detect_host_os > /dev/null 2>&1 || HOST_OS=""
                list_tools
                exit 0
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
    return "${PASS}"
}

###############################################################################
# warn_inapplicable_groups
#------------------------------------------------------------------------------
# Purpose  : Tell the user plainly when a group they asked for does not apply
#            to this host (e.g. `--group gnu` on Linux). Without this the run
#            would silently do nothing and look like a success.
# Returns  : PASS always
###############################################################################
function warn_inapplicable_groups() {
    local g

    for g in "${SELECTED_GROUPS[@]:-}"; do
        [[ -z "${g}" ]] && continue
        if ! group_applies "${g}"; then
            warn "Group '${g}' does not apply on ${HOST_OS} (it targets: ${GROUP_PLATFORMS[${g}]}); nothing to do for it."
        fi
    done
    return "${PASS}"
}

###############################################################################
# main
###############################################################################
function main() {
    parse_args "$@"

    detect_host_os || exit 1
    detect_pkg_manager || exit 1
    detect_proxy
    warn_inapplicable_groups

    local IFS=' '
    info "Groups:  ${SELECTED_GROUPS[*]:-${ALL_GROUPS[*]}}"
    info "Proxy:   '${PROXY:-(none)}'"
    info "Mode:    $([[ "${CHECK_ONLY}" == "true" ]] && echo check-only || echo install)"
    info "Dry-run: ${DRY_RUN}"
    unset IFS
    echo ""

    if [[ "${CHECK_ONLY}" == "true" ]]; then
        verify_tools
        local rc=$?
        check_go_path
        exit "${rc}"
    fi

    ensure_eza_repo || warn "eza-community repo setup failed; eza may not install"
    refresh_package_lists || exit 1
    install_tool_groups
    install_go_tools

    echo ""
    info "Verifying..."
    verify_tools
    local rc=$?
    check_go_path

    echo ""
    if [[ "${rc}" -eq "${PASS}" ]]; then
        pass "install_tools.sh completed."
    else
        warn "install_tools.sh completed with missing tools (see above)."
    fi
    exit "${rc}"
}

main "$@"
