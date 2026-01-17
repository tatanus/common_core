#!/usr/bin/env bash
###############################################################################
# NAME         : util_net.sh
# DESCRIPTION  : Cross-platform network management, diagnostics, and inspection
#                utilities for Linux, macOS, and WSL. Includes local/external
#                IP discovery, DHCP/static detection, proxy awareness, and
#                automatic repair capabilities.
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-10-29
###############################################################################
# EDIT HISTORY:
# DATE       | EDITED BY      | DESCRIPTION
# -----------|----------------|------------------------------------------------
# 2025-10-29 | Adam Compton   | Full feature implementation with DHCP/static
#            |                | detection, proxy awareness, caching, spinner,
#            |                | and diagnostic features.
# 2025-12-27 | Adam Compton   | Refactored to use array-based tui::show_spinner
# 2025-12-28 | Adam Compton   | Fixed cross-platform compatibility for macOS:
#            |                | - Use platform abstractions for network ops
#            |                | - Fixed ifconfig parsing for BSD/macOS format
#            |                | - Added macOS support to repair_connectivity
#            |                | - Use net::get_gateway in full_diagnostic
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Library Guard
#===============================================================================
if [[ -n "${UTIL_NETWORK_SH_LOADED:-}" ]]; then
    if (return 0 2> /dev/null); then
        return 0
    fi
else
    UTIL_NETWORK_SH_LOADED=1
fi

#===============================================================================
# Module Dependencies
#===============================================================================
if [[ "${UTIL_PLATFORM_SH_LOADED:-0}" -eq 0 ]]; then
    echo "ERROR: util_platform.sh must be loaded before util_net.sh" >&2
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
# Globals
#===============================================================================
: "${PASS:=0}"
: "${FAIL:=1}"
DEFAULT_PING_TARGET="8.8.8.8"
DEFAULT_DNS_TARGET="google.com"
DEFAULT_IP_SERVICES=("https://ifconfig.me/ip" "https://api.ipify.org" "https://ipecho.net/plain")

###############################################################################
# net::_get_dns_tool
#------------------------------------------------------------------------------
# Purpose  : Identify available DNS resolution tool
# Usage    : tool=$(net::_get_dns_tool)
# Returns  : Prints tool name (dig, host, getent, nslookup) or empty
###############################################################################
function net::_get_dns_tool() {
    if cmd::exists dig; then
        printf 'dig\n'
    elif cmd::exists host; then
        printf 'host\n'
    elif cmd::exists getent; then
        printf 'getent\n'
    elif cmd::exists nslookup; then
        printf 'nslookup\n'
    fi
}

###############################################################################
# net::_can_ping
#------------------------------------------------------------------------------
# Purpose  : Check if ping command is available and functional
# Usage    : net::_can_ping
# Returns  : PASS if ping available, FAIL otherwise
###############################################################################
function net::_can_ping() {
    if ! cmd::exists ping; then
        debug "ping command not available"
        return "${FAIL}"
    fi

    # Test that ping works (some systems restrict it)
    # Use platform-appropriate ping options
    if os::is_macos; then
        # macOS ping uses -c for count, -W is not available, use -t for timeout
        if ping -c1 -t1 127.0.0.1 > /dev/null 2>&1; then
            return "${PASS}"
        fi
    else
        # Linux ping
        if ping -c1 -W1 127.0.0.1 > /dev/null 2>&1; then
            return "${PASS}"
        fi
    fi

    debug "ping command exists but cannot execute (permissions?)"
    return "${FAIL}"
}

###############################################################################
# net::_ping_host
#------------------------------------------------------------------------------
# Purpose  : Ping a host with platform-appropriate options
# Usage    : net::_ping_host <ip> [timeout_seconds]
# Arguments:
#   $1 : IP address or hostname
#   $2 : Timeout in seconds (default: 3)
# Returns  : PASS if reachable, FAIL otherwise
###############################################################################
function net::_ping_host() {
    local target="${1:-}"
    local timeout="${2:-3}"

    if [[ -z "${target}" ]]; then
        return "${FAIL}"
    fi

    if os::is_macos; then
        # macOS: -c count, -t timeout (total seconds)
        ping -c1 -t"${timeout}" "${target}" > /dev/null 2>&1
    else
        # Linux: -c count, -W timeout (seconds to wait for response)
        ping -c1 -W"${timeout}" "${target}" > /dev/null 2>&1
    fi
}

#===============================================================================
# net::is_online
#------------------------------------------------------------------------------
# Purpose  : Check basic network connectivity (local or internet).
# Usage    : net::is_online [target]
# Returns  : PASS if reachable, FAIL otherwise.
###############################################################################
function net::is_online() {
    local target="${1:-${DEFAULT_PING_TARGET}}"
    local resolved_ip desc="Internet"

    if ! resolved_ip=$(net::resolve_target "${target}" 2> /dev/null); then
        fail "Unable to resolve: ${target}"
        return "${FAIL}"
    fi

    if net::is_local_ip "${resolved_ip}"; then
        desc="Local network"
    fi

    # Try ping first if available
    if net::_can_ping; then
        info "Checking ${desc} connectivity to ${resolved_ip} (ping)..."
        if net::_ping_host "${resolved_ip}" 3; then
            pass "${desc} connectivity verified."
            return "${PASS}"
        fi
    fi

    # Fallback: try TCP connection to common ports
    info "Checking ${desc} connectivity to ${resolved_ip} (TCP fallback)..."
    local test_ports=(80 443)
    for port in "${test_ports[@]}"; do
        if platform::timeout 3 bash -c ">/dev/tcp/${resolved_ip}/${port}" 2> /dev/null; then
            pass "${desc} connectivity verified (port ${port})."
            return "${PASS}"
        fi
    done

    fail "No ${desc} connectivity detected."
    return "${FAIL}"
}

###############################################################################
# net::resolve_target_ipv6
#------------------------------------------------------------------------------
# Purpose  : Resolve FQDN to IPv6 address
# Usage    : ipv6=$(net::resolve_target_ipv6 "example.com")
# Returns  : Prints IPv6 address or FAIL
###############################################################################
function net::resolve_target_ipv6() {
    local target="${1:-}"
    if [[ -z "${target}" ]]; then
        error "Usage: net::resolve_target_ipv6 <fqdn>"
        return "${FAIL}"
    fi

    local ip="" tool
    tool=$(net::_get_dns_tool)

    if [[ -z "${tool}" ]]; then
        error "No DNS resolution tool available"
        return "${FAIL}"
    fi

    case "${tool}" in
        dig)
            ip=$(dig +short "${target}" AAAA | grep -m1 '^[0-9a-f:]*:' || true)
            ;;
        host)
            ip=$(host -t AAAA "${target}" 2> /dev/null | awk '/has IPv6 address/ {print $5; exit}' || true)
            ;;
        getent)
            ip=$(getent ahosts "${target}" | awk '/STREAM/ && /:/ {print $1; exit}' || true)
            ;;
        *) ;; # Unsupported tool
    esac

    if [[ -n "${ip}" ]]; then
        debug "Resolved ${target} -> ${ip} (IPv6)"
        printf '%s\n' "${ip}"
        return "${PASS}"
    fi

    fail "Failed to resolve ${target} to IPv6"
    return "${FAIL}"
}

###############################################################################
# net::get_dns_servers
#------------------------------------------------------------------------------
# Purpose  : List configured DNS servers
# Usage    : net::get_dns_servers
# Returns  : Prints DNS server IPs, one per line
###############################################################################
function net::get_dns_servers() {
    local servers=""

    # Linux/WSL
    if [[ -f /etc/resolv.conf ]]; then
        servers=$(grep -E '^nameserver' /etc/resolv.conf | awk '{print $2}' || true)
    fi

    # macOS
    if os::is_macos && cmd::exists scutil; then
        servers=$(scutil --dns | grep 'nameserver\[' | awk '{print $3}' | sort -u || true)
    fi

    if [[ -n "${servers}" ]]; then
        printf '%s\n' "${servers}"
        return "${PASS}"
    fi

    warn "Unable to determine DNS servers"
    return "${FAIL}"
}

#===============================================================================
# net::resolve_target
#------------------------------------------------------------------------------
# Purpose  : Resolve an FQDN or IP to an IPv4 address.
# Usage    : ip=$(net::resolve_target "example.com")
# Returns  : Prints resolved IP on success, FAIL otherwise.
# Notes    : Does NOT use ${PROXY} - DNS tools must resolve locally.
###############################################################################
function net::resolve_target() {
    local target="${1:-}"
    if [[ -z "${target}" ]]; then
        error "Usage: net::resolve_target <fqdn_or_ip>"
        return "${FAIL}"
    fi

    # Already an IP?
    if [[ "${target}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        printf '%s\n' "${target}"
        return "${PASS}"
    fi

    local ip="" tool
    tool=$(net::_get_dns_tool)

    if [[ -z "${tool}" ]]; then
        error "No DNS resolution tool available (dig, host, getent, nslookup)"
        return "${FAIL}"
    fi

    case "${tool}" in
        dig)
            ip=$(dig +short "${target}" A | grep -m1 '^[0-9]' || true)
            ;;
        host)
            ip=$(host -t A "${target}" 2> /dev/null | awk '/has address/ {print $4; exit}' || true)
            ;;
        getent)
            ip=$(getent ahosts "${target}" | awk 'NR==1 {print $1}' || true)
            ;;
        nslookup)
            ip=$(nslookup "${target}" 2> /dev/null | awk '/^Address: / && !/127\.0\.0\.1/ {print $2; exit}' || true)
            ;;
        *) ;; # Unsupported tool
    esac

    if [[ -n "${ip}" && "${ip}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        debug "Resolved ${target} -> ${ip} (using ${tool})"
        printf '%s\n' "${ip}"
        return "${PASS}"
    fi

    fail "Failed to resolve ${target}"
    return "${FAIL}"
}

#===============================================================================
# net::is_local_ip
#------------------------------------------------------------------------------
# Purpose  : Determine if an IP is local/non-routable.
# Usage    : net::is_local_ip "192.168.1.1"
# Returns  : PASS if local, FAIL if public.
###############################################################################
function net::is_local_ip() {
    local ip="${1:-}"
    if [[ -z "${ip}" ]]; then
        error "Usage: net::is_local_ip <ip>"
        return "${FAIL}"
    fi

    if [[ "${ip}" =~ ^10\. ]] ||
        [[ "${ip}" =~ ^192\.168\. ]] ||
        [[ "${ip}" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] ||
        [[ "${ip}" =~ ^127\. ]] ||
        [[ "${ip}" =~ ^169\.254\. ]]; then
        debug "IP ${ip} classified as local."
        return "${PASS}"
    fi
    debug "IP ${ip} classified as public."
    return "${FAIL}"
}

#===============================================================================
# net::get_gateway
#------------------------------------------------------------------------------
# Purpose  : Get the system's default gateway IP.
# Usage    : gw=$(net::get_gateway)
# Returns  : Prints gateway IP or FAIL.
###############################################################################
function net::get_gateway() {
    local gw=""

    if os::is_macos; then
        # macOS: use route command
        gw=$(route -n get default 2> /dev/null | awk '/gateway/ {print $2; exit}' || true)
    elif cmd::exists ip; then
        # Linux: prefer ip command
        gw=$(ip route 2> /dev/null | awk '/default/ {print $3; exit}' || true)
    elif cmd::exists netstat; then
        # Fallback: netstat (works on most Unix systems)
        gw=$(netstat -rn 2> /dev/null | awk '/default|0\.0\.0\.0/ {print $2; exit}' || true)
    elif cmd::exists route; then
        # Another fallback: route command (Linux)
        gw=$(route -n 2> /dev/null | awk '/^0\.0\.0\.0/ {print $2; exit}' || true)
    fi

    if [[ -n "${gw}" ]]; then
        printf '%s\n' "${gw}"
        return "${PASS}"
    fi

    fail "Unable to determine default gateway."
    return "${FAIL}"
}

#===============================================================================
# net::list_interfaces
#------------------------------------------------------------------------------
# Purpose  : List all active (non-virtual) network interfaces.
# Usage    : net::list_interfaces
# Returns  : Prints list of active interfaces.
###############################################################################
function net::list_interfaces() {
    local interfaces=""

    if os::is_macos; then
        # macOS: use ifconfig and filter out virtual interfaces
        interfaces=$(ifconfig -l 2> /dev/null | tr ' ' '\n' | grep -vE '^(lo|bridge|p2p|awdl|llw|utun|gif|stf|XHC)' || true)
    elif cmd::exists ip; then
        # Linux: use ip command
        interfaces=$(ip -o link show 2> /dev/null | awk -F': ' '{print $2}' | grep -vE '^(lo|docker|virbr|vnet|tap|tun|br-|ip6tnl|sit)' || true)
    elif cmd::exists ifconfig; then
        # Fallback: ifconfig
        interfaces=$(ifconfig 2> /dev/null | awk '/^[a-zA-Z0-9]+:/ {print $1}' | sed 's/://' | grep -vE '^(lo|docker|virbr)' || true)
    fi

    if [[ -z "${interfaces}" ]]; then
        fail "No interfaces found."
        return "${FAIL}"
    fi

    printf '%s\n' "${interfaces}"
    return "${PASS}"
}

#===============================================================================
# net::get_interface_info
#------------------------------------------------------------------------------
# Purpose  : Display detailed info for a specific interface.
# Usage    : net::get_interface_info "eth0"
# Returns  : PASS if interface found, FAIL otherwise.
###############################################################################
function net::get_interface_info() {
    local iface="${1:-}"
    if [[ -z "${iface}" ]]; then
        error "Usage: net::get_interface_info <interface>"
        return "${FAIL}"
    fi

    local ip="" mac="" dhcp="" link_speed=""

    # Get IP and MAC using platform abstractions
    ip=$(platform::get_interface_ip "${iface}" 2> /dev/null || echo "unknown")
    mac=$(platform::get_interface_mac "${iface}" 2> /dev/null || echo "unknown")

    # Get DHCP/static method
    dhcp=$(net::get_ip_method "${iface}" 2> /dev/null || echo "Unknown")

    # Get link speed (Linux only with ethtool)
    if cmd::exists ethtool && ! os::is_macos; then
        link_speed=$(ethtool "${iface}" 2> /dev/null | awk '/Speed:/ {print $2}')
    elif os::is_macos && cmd::exists networksetup; then
        # macOS: try to get media info
        local hw_port
        hw_port=$(networksetup -listallhardwareports 2> /dev/null | awk -v dev="${iface}" '
            /^Hardware Port:/ { port=$3 }
            /^Device:/ && $2 == dev { print port; exit }
        ')
        if [[ -n "${hw_port}" ]]; then
            link_speed=$(networksetup -getMedia "${hw_port}" 2> /dev/null | head -1 || echo "unknown")
        fi
    fi

    printf "Interface: %s\nIP: %s\nMAC: %s\nMethod: %s\nSpeed: %s\n" \
        "${iface}" "${ip:-unknown}" "${mac:-unknown}" "${dhcp}" "${link_speed:-unknown}"
    return "${PASS}"
}

#===============================================================================
# net::check_port
#------------------------------------------------------------------------------
# Purpose  : Check if a remote or local port is open (TCP).
# Usage    : net::check_port "example.com" 443
# Returns  : PASS if port is open, FAIL otherwise.
###############################################################################
function net::check_port() {
    local target="${1:-}" port="${2:-}"

    if [[ -z "${target}" || -z "${port}" ]]; then
        error "Usage: net::check_port <host> <port>"
        return "${FAIL}"
    fi

    info "Checking port ${port} on ${target}..."

    # Use platform::timeout for cross-platform compatibility
    if platform::timeout 5 bash -c ">/dev/tcp/${target}/${port}" 2> /dev/null; then
        pass "Port ${port} is open on ${target}."
        return "${PASS}"
    fi

    fail "Port ${port} is closed or unreachable on ${target}."
    return "${FAIL}"
}

#===============================================================================
# net::get_ip_method
#------------------------------------------------------------------------------
# Purpose  : Determine if an interface uses DHCP or static IP assignment.
# Usage    : net::get_ip_method "eth0"
# Returns  : Prints "DHCP", "Static", or "Unknown"
###############################################################################
function net::get_ip_method() {
    local iface="${1:-}"
    if [[ -z "${iface}" ]]; then
        error "Usage: net::get_ip_method <interface>"
        return "${FAIL}"
    fi

    if os::is_linux || os::is_wsl; then
        # Try NetworkManager first
        if cmd::exists nmcli && cmd::exists systemctl && systemctl is-active NetworkManager &> /dev/null; then
            local prof method
            prof=$(nmcli -g GENERAL.CONNECTION device show "${iface}" 2> /dev/null || true)
            method=$(nmcli -g ipv4.method connection show "${prof}" 2> /dev/null || true)
            if [[ "${method}" == "auto" ]]; then
                printf "DHCP\n"
                return "${PASS}"
            elif [[ "${method}" == "manual" ]]; then
                printf "Static\n"
                return "${PASS}"
            fi
        fi

        # Try systemd-networkd
        if cmd::exists systemctl && systemctl is-active systemd-networkd &> /dev/null; then
            local network_file="/etc/systemd/network/*-${iface}.network"
            # shellcheck disable=SC2086
            if ls ${network_file} 1> /dev/null 2>&1; then
                if grep -qi "DHCP=yes" ${network_file} 2> /dev/null; then
                    printf "DHCP\n"
                    return "${PASS}"
                else
                    printf "Static\n"
                    return "${PASS}"
                fi
            fi
        fi

        # Fallback: check /etc/network/interfaces (Debian-style)
        if [[ -f /etc/network/interfaces ]]; then
            if grep -qE "iface ${iface}.*dhcp" /etc/network/interfaces 2> /dev/null; then
                printf "DHCP\n"
                return "${PASS}"
            elif grep -qE "iface ${iface}.*static" /etc/network/interfaces 2> /dev/null; then
                printf "Static\n"
                return "${PASS}"
            fi
        fi
    elif os::is_macos; then
        if cmd::exists networksetup; then
            # Find the hardware port name for this interface
            local ports hw_port=""
            ports=$(networksetup -listallhardwareports 2> /dev/null | awk '
                /^Hardware Port:/ { port=$0; sub(/^Hardware Port: /, "", port) }
                /^Device:/ { dev=$2; print dev "," port }')

            while IFS= read -r line; do
                local dev="${line%%,*}" port="${line#*,}"
                if [[ "${iface}" == "${dev}" ]]; then
                    hw_port="${port}"
                    break
                fi
            done <<< "${ports}"

            if [[ -n "${hw_port}" ]]; then
                local cfg
                cfg=$(networksetup -getinfo "${hw_port}" 2> /dev/null || true)
                if echo "${cfg}" | grep -q "DHCP Configuration"; then
                    printf "DHCP\n"
                    return "${PASS}"
                elif echo "${cfg}" | grep -q "Manual Configuration"; then
                    printf "Static\n"
                    return "${PASS}"
                fi
            fi
        fi
    fi

    printf "Unknown\n"
    return "${FAIL}"
}

#===============================================================================
# net::get_local_ips
#------------------------------------------------------------------------------
# Purpose  : Retrieve all active local interfaces with IPs and DHCP/static info.
# Usage    : net::get_local_ips
# Returns  : Prints a formatted list of interfaces and addresses.
###############################################################################
function net::get_local_ips() {
    info "Retrieving local network interfaces..."
    local iface ip dhcp result=""

    if os::is_macos; then
        # macOS: parse ifconfig output
        local current_iface=""
        while IFS= read -r line; do
            if [[ "${line}" =~ ^[a-zA-Z0-9]+: ]]; then
                current_iface="${line%%:*}"
            elif [[ "${line}" =~ inet[[:space:]]+([0-9.]+) ]] && [[ -n "${current_iface}" ]]; then
                ip="${BASH_REMATCH[1]}"
                # Skip loopback and link-local
                if [[ "${ip}" == "127.0.0.1" ]] || [[ "${ip}" =~ ^169\.254\. ]]; then
                    continue
                fi
                # Skip virtual interfaces
                case "${current_iface}" in
                    lo* | bridge* | p2p* | awdl* | llw* | utun* | gif* | stf* | XHC*) continue ;;
                    *) ;; # Non-virtual interface
                esac
                dhcp=$(net::get_ip_method "${current_iface}" 2> /dev/null || echo "Unknown")
                result+="${current_iface}: ${ip} (${dhcp})"$'\n'
            fi
        done < <(ifconfig 2> /dev/null)
    elif cmd::exists ip; then
        # Linux: use ip command
        local interfaces
        interfaces=$(ip -o addr show 2> /dev/null | awk '$3 == "inet" && $4 !~ /^127/ {print $2,$4}')
        while IFS= read -r line; do
            [[ -z "${line}" ]] && continue
            iface=$(echo "${line}" | awk '{print $1}')
            ip=$(echo "${line}" | awk '{print $2}' | cut -d'/' -f1)
            case "${iface}" in
                lo* | docker* | virbr* | vnet* | tun* | tap* | br-* | ip6tnl* | sit*) continue ;;
                *) ;; # Non-virtual interface
            esac
            dhcp=$(net::get_ip_method "${iface}" 2> /dev/null || echo "Unknown")
            result+="${iface}: ${ip} (${dhcp})"$'\n'
        done <<< "${interfaces}"
    elif cmd::exists ifconfig; then
        # Fallback: ifconfig (Linux style)
        local interfaces
        interfaces=$(ifconfig 2> /dev/null | awk '/^[a-zA-Z0-9]+:/ { iface=$1; next } /inet / && $2 != "127.0.0.1" { print iface,$2 }' | sed 's/://')
        while IFS= read -r line; do
            [[ -z "${line}" ]] && continue
            iface=$(echo "${line}" | awk '{print $1}')
            ip=$(echo "${line}" | awk '{print $2}')
            case "${iface}" in
                lo* | docker* | virbr* | vnet* | tun* | tap* | br-* | ip6tnl* | sit*) continue ;;
                *) ;; # Non-virtual interface
            esac
            dhcp=$(net::get_ip_method "${iface}" 2> /dev/null || echo "Unknown")
            result+="${iface}: ${ip} (${dhcp})"$'\n'
        done <<< "${interfaces}"
    else
        fail "No supported network tools (ip/ifconfig) found."
        return "${FAIL}"
    fi

    if [[ -z "${result}" ]]; then
        fail "No active interfaces found."
        return "${FAIL}"
    fi

    printf "%s" "${result}"
    return "${PASS}"
}

#===============================================================================
# net::get_external_ip
#------------------------------------------------------------------------------
# Purpose  : Retrieve external IP address (cached and proxy-aware).
# Usage    : net::get_external_ip
# Returns  : Prints external IP, PASS on success, FAIL otherwise.
###############################################################################
function net::get_external_ip() {
    local cache="${TMPDIR:-/tmp}/external_ip.cache"
    local ip="" now last_modified age url

    # Use platform abstraction for epoch time
    now=$(platform::date epoch)

    if ! net::is_online; then
        fail "Network offline - cannot retrieve external IP."
        return "${FAIL}"
    fi

    # Use cached IP if <10 minutes old
    if file::exists "${cache}"; then
        # Use platform abstraction for file mtime
        last_modified=$(platform::stat mtime "${cache}" 2> /dev/null || echo 0)
        age=$((now - last_modified))
        if ((age < 600)); then
            ip="$(< "${cache}")"
            if [[ "${ip}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                pass "External IP (cached): ${ip}"
                printf '%s\n' "${ip}"
                return "${PASS}"
            fi
        fi
    fi

    info "Fetching external IP via proxy chain..."
    for url in "${DEFAULT_IP_SERVICES[@]}"; do
        # Build command array with optional PROXY
        local -a cmd=()
        if [[ -n "${PROXY:-}" ]]; then
            read -ra cmd <<< "${PROXY}"
        fi
        cmd+=(curl -4 -fsSL --max-time 5 "${url}")

        if tui::show_spinner -- "${cmd[@]}" > /dev/null 2>&1; then
            ip=$("${cmd[@]}" 2> /dev/null || true)
            [[ "${ip}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && break
        fi
    done

    if [[ -z "${ip}" ]]; then
        fail "Failed to retrieve external IP."
        return "${FAIL}"
    fi

    echo "${ip}" > "${cache}"
    pass "External IP: ${ip}"
    printf '%s\n' "${ip}"
    return "${PASS}"
}

#===============================================================================
# net::repair_connectivity
#------------------------------------------------------------------------------
# Purpose  : Attempt self-healing of network issues (cross-platform).
# Usage    : net::repair_connectivity
# Returns  : PASS if restored, FAIL otherwise.
###############################################################################
function net::repair_connectivity() {
    info "Attempting self-healing network recovery..."

    # Use platform abstractions for network restart and DNS flush
    platform::network_restart || true
    platform::dns_flush || true

    # Test connectivity after repair attempt
    sleep 2
    if net::is_online; then
        pass "Connectivity restored."
        return "${PASS}"
    fi

    fail "Repair failed; manual intervention required."
    return "${FAIL}"
}

#===============================================================================
# net::full_diagnostic
#------------------------------------------------------------------------------
# Purpose  : Perform a complete diagnostic check on network connectivity.
# Usage    : net::full_diagnostic
# Returns  : PASS if all checks succeed, FAIL otherwise.
###############################################################################
function net::full_diagnostic() {
    info "Running full network diagnostic..."
    local status="${PASS}" gw target

    # Use cross-platform gateway detection
    gw=$(net::get_gateway 2> /dev/null || true)
    target="${gw:-${DEFAULT_PING_TARGET}}"

    net::is_online "${target}" || status="${FAIL}"
    net::get_local_ips > /dev/null || status="${FAIL}"
    net::get_external_ip > /dev/null || status="${FAIL}"

    if [[ "${status}" -eq "${PASS}" ]]; then
        pass "All network checks passed."
    else
        fail "Some checks failed."
    fi
    return "${status}"
}

###############################################################################
# net::self_test
#------------------------------------------------------------------------------
# Purpose  : Self-test for util_net.sh functionality
# Usage    : net::self_test
# Returns  : PASS (0) if all tests pass, FAIL (1) otherwise
# Globals  : None
###############################################################################
function net::self_test() {
    info "Running util_net.sh self-test..."

    local status="${PASS}"

    # Test 1: Check if we can detect online status
    if ! declare -F net::is_online > /dev/null 2>&1; then
        fail "net::is_online function not available"
        status="${FAIL}"
    else
        pass "net::is_online function available"
    fi

    # Test 2: Interface listing
    if ! net::list_interfaces > /dev/null 2>&1; then
        warn "net::list_interfaces failed (may be expected in some environments)"
    else
        pass "net::list_interfaces works"
    fi

    # Test 3: Gateway detection
    local gw
    if gw=$(net::get_gateway 2> /dev/null); then
        pass "net::get_gateway works (gateway: ${gw})"
    else
        debug "net::get_gateway failed (may be expected without network)"
    fi

    # Test 4: DNS tool detection
    local dns_tool
    if dns_tool=$(net::_get_dns_tool); then
        pass "DNS resolution tool available: ${dns_tool}"
    else
        warn "No DNS resolution tool found"
    fi

    # Test 5: Local IP detection
    if net::is_local_ip "192.168.1.1"; then
        pass "net::is_local_ip correctly identifies private IP"
    else
        fail "net::is_local_ip failed"
        status="${FAIL}"
    fi

    if [[ "${status}" -eq "${PASS}" ]]; then
        pass "util_net.sh self-test passed"
    else
        fail "util_net.sh self-test failed"
    fi

    return "${status}"
}
