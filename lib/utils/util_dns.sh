#!/usr/bin/env bash
###############################################################################
# NAME         : util_dns.sh
# DESCRIPTION  : DNS record lookup helpers (A/AAAA/CNAME/NS/MX/TXT/SRV/SPF) and
#                small parsing helpers (SPF includes, registrable root domain).
#                Thin wrappers over `dig` that emit plain, one-record-per-line
#                output; callers compose/format (e.g. JSON) as needed. Extracted
#                so recon tooling across the stack shares one implementation
#                instead of re-deriving these lookups.
# AUTHOR       : Adam Compton
# DATE CREATED : 2026-09-17
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Library Guard
#===============================================================================
if [[ -n "${UTIL_DNS_SH_LOADED:-}" ]]; then
    if (return 0 2> /dev/null); then
        return 0
    fi
else
    UTIL_DNS_SH_LOADED=1
fi

#===============================================================================
# Logging fallbacks (only if loaded standalone, before common_core's logger)
#===============================================================================
if ! declare -F error > /dev/null 2>&1; then
    function error() { printf '[ERROR] %s\n' "$*" >&2; }
fi
if ! declare -F debug > /dev/null 2>&1; then
    function debug() { :; }
fi

#===============================================================================
# Globals
#===============================================================================
: "${PASS:=0}"
: "${FAIL:=1}"

# Default resolver used when a caller does not pass one. Override via the
# environment (e.g. DNS_DEFAULT_SERVER="10.0.0.10" for internal engagements).
: "${DNS_DEFAULT_SERVER:=8.8.8.8}"

#===============================================================================
# Internal helpers
#===============================================================================

###############################################################################
# dns::_have_dig
#------------------------------------------------------------------------------
# Purpose  : Verify `dig` is available (via cmd::exists when present).
# Returns  : PASS if dig is on PATH, FAIL otherwise.
###############################################################################
function dns::_have_dig() {
    if declare -F cmd::exists > /dev/null 2>&1; then
        cmd::exists dig && return "${PASS}"
    elif command -v dig > /dev/null 2>&1; then
        return "${PASS}"
    fi
    error "dns: 'dig' is required but was not found on PATH"
    return "${FAIL}"
}

#===============================================================================
# Public API
#===============================================================================

###############################################################################
# dns::query
#------------------------------------------------------------------------------
# Purpose  : Low-level `dig +short` wrapper. Emits one record per line with the
#            trailing dot stripped.
# Usage    : dns::query <TYPE> <name> [server]
# Returns  : PASS on success (records on stdout), FAIL on bad usage / no dig.
###############################################################################
function dns::query() {
    local type="${1:-}" name="${2:-}" server="${3:-${DNS_DEFAULT_SERVER}}"
    if [[ -z "${type}" || -z "${name}" ]]; then
        error "dns::query: usage: dns::query <TYPE> <name> [server]"
        return "${FAIL}"
    fi
    dns::_have_dig || return "${FAIL}"
    dig +short "@${server}" "${name}" "${type}" 2> /dev/null | sed 's/\.$//'
}

# Typed convenience wrappers (plain, one record per line).
function dns::a() { dns::query A "$@"; }
function dns::aaaa() { dns::query AAAA "$@"; }
function dns::cname() { dns::query CNAME "$@"; }
function dns::ns() { dns::query NS "$@"; }

###############################################################################
# dns::mx : mail hosts (numeric priority dropped).
###############################################################################
function dns::mx() {
    dns::query MX "$@" | awk '{print $NF}'
}

###############################################################################
# dns::txt : TXT records with dig's surrounding quotes removed.
###############################################################################
function dns::txt() {
    dns::query TXT "$@" | sed 's/"//g'
}

###############################################################################
# dns::srv : SRV target hosts (last field of "prio weight port target").
###############################################################################
function dns::srv() {
    dns::query SRV "$@" | awk '{print $NF}'
}

###############################################################################
# dns::spf : the domain's SPF policy TXT record(s) (v=spf1 ...).
###############################################################################
function dns::spf() {
    dns::txt "$@" | grep -E '^v=spf1' || true
}

###############################################################################
# dns::spf_includes
#------------------------------------------------------------------------------
# Purpose  : Extract the `include:` hosts from an SPF string. Reads the SPF
#            from $1, or from stdin when no argument is given.
# Usage    : dns::spf_includes "v=spf1 include:a.com -all"
#            dns::spf example.com | dns::spf_includes
###############################################################################
function dns::spf_includes() {
    local spf="${1:-}"
    [[ -z "${spf}" ]] && spf="$(cat)"
    printf '%s\n' "${spf}" | grep -oE 'include:[^ ]+' | cut -d: -f2 | sort -u
}

###############################################################################
# dns::root_domain
#------------------------------------------------------------------------------
# Purpose  : Naive registrable domain (last two labels). NOTE: does not
#            special-case multi-label public suffixes (e.g. co.uk).
# Usage    : dns::root_domain sub.example.com   -> example.com
###############################################################################
function dns::root_domain() {
    local domain="${1:-}"
    if [[ -z "${domain}" ]]; then
        error "dns::root_domain: domain required"
        return "${FAIL}"
    fi
    awk -F. '{n = NF; if (n >= 2) print $(n - 1)"."$n; else print $0}' <<< "${domain}"
}

###############################################################################
# dns::self_test : deterministic (no-network) checks of the parsing helpers.
###############################################################################
function dns::self_test() {
    local rc=0
    [[ "$(dns::root_domain sub.host.example.com)" == "example.com" ]] || rc=1
    [[ "$(dns::root_domain example.com)" == "example.com" ]] || rc=1
    [[ "$(printf 'v=spf1 include:a.com include:b.net -all' | dns::spf_includes)" == "$(printf 'a.com\nb.net')" ]] || rc=1
    if ((rc == 0)); then
        debug "dns::self_test passed"
    else
        error "dns::self_test failed"
    fi
    return "${rc}"
}
