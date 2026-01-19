# util_net.sh - Network Utilities

Cross-platform network management, diagnostics, and inspection utilities for Linux, macOS, and WSL.

## Overview

This module provides:
- Connectivity checking
- IP address discovery (local and external)
- Port checking
- DNS resolution (IPv4 and IPv6)
- Network interface listing and information
- DHCP/Static detection
- Network diagnostics and repair utilities

## Dependencies

- `util_cmd.sh`
- `util_platform.sh`
- `util_tui.sh`

## Functions

### Connectivity

#### net::is_online

Check basic network connectivity (local or internet).

```bash
# Default: check internet connectivity
if net::is_online; then
    echo "Internet connected"
else
    echo "Offline"
fi

# Check specific target
if net::is_online "192.168.1.1"; then
    echo "Gateway reachable"
fi
```

**Arguments:**
- `$1` (optional) - Target IP or hostname (default: 8.8.8.8)

**Returns:** `PASS` (0) if reachable, `FAIL` (1) if offline

#### net::is_local_ip

Determine if an IP address is local/non-routable (private, loopback, or link-local).

```bash
if net::is_local_ip "192.168.1.100"; then
    echo "This is a private IP"
fi

if net::is_local_ip "8.8.8.8"; then
    echo "This won't print - 8.8.8.8 is public"
fi
```

**Arguments:**
- `$1` - IP address to check

**Returns:** `PASS` (0) if local/private, `FAIL` (1) if public

**Recognized ranges:** 10.x.x.x, 192.168.x.x, 172.16-31.x.x, 127.x.x.x, 169.254.x.x

### IP Addresses

#### net::get_local_ips

Retrieve all active local interfaces with their IPs and DHCP/static info.

```bash
net::get_local_ips
# Example output:
# en0: 192.168.1.100 (DHCP)
# en1: 10.0.0.50 (Static)
```

**Outputs:** Formatted list of interfaces with IP addresses and assignment method

**Returns:** `PASS` (0) on success, `FAIL` (1) if no interfaces found

#### net::get_external_ip

Get the external/public IP address (cached and proxy-aware).

```bash
ip=$(net::get_external_ip)
echo "External IP: ${ip}"
```

**Outputs:** External IP address

**Returns:** `PASS` (0) on success, `FAIL` (1) if offline or retrieval failed

**Notes:** Results are cached for 10 minutes. Respects `${PROXY}` environment variable.

### Network Interface Information

#### net::list_interfaces

List all active (non-virtual) network interfaces.

```bash
interfaces=$(net::list_interfaces)
echo "Available interfaces:"
echo "${interfaces}"
```

**Outputs:** List of interface names, one per line

**Returns:** `PASS` (0) on success, `FAIL` (1) if no interfaces found

**Notes:** Filters out virtual interfaces (lo, docker, virbr, bridge, utun, etc.)

#### net::get_interface_info

Display detailed information for a specific interface.

```bash
net::get_interface_info "en0"
# Example output:
# Interface: en0
# IP: 192.168.1.100
# MAC: aa:bb:cc:dd:ee:ff
# Method: DHCP
# Speed: 1000baseT
```

**Arguments:**
- `$1` - Interface name (e.g., "eth0", "en0")

**Returns:** `PASS` (0) if interface found, `FAIL` (1) otherwise

#### net::get_gateway

Get the system's default gateway IP.

```bash
gateway=$(net::get_gateway)
echo "Gateway: ${gateway}"
```

**Outputs:** Gateway IP address

**Returns:** `PASS` (0) on success, `FAIL` (1) if unable to determine

#### net::get_dns_servers

List configured DNS servers.

```bash
net::get_dns_servers
# Example output:
# 8.8.8.8
# 8.8.4.4
```

**Outputs:** DNS server IPs, one per line

**Returns:** `PASS` (0) on success, `FAIL` (1) if unable to determine

### Port Checking

#### net::check_port

Check if a TCP port is open on a host.

```bash
if net::check_port "example.com" 443; then
    echo "Port 443 is open"
fi
```

**Arguments:**
- `$1` - Host or IP address
- `$2` - Port number

**Returns:** `PASS` (0) if open, `FAIL` (1) if closed or unreachable

### DNS Resolution

#### net::resolve_target

Resolve a hostname to an IPv4 address.

```bash
ip=$(net::resolve_target "example.com")
echo "Resolved: ${ip}"

# Already an IP? Returns it unchanged
ip=$(net::resolve_target "8.8.8.8")
```

**Arguments:**
- `$1` - FQDN or IP address

**Outputs:** IPv4 address

**Returns:** `PASS` (0) on success, `FAIL` (1) if resolution failed

**Notes:** Uses dig, host, getent, or nslookup (in order of preference)

#### net::resolve_target_ipv6

Resolve a hostname to an IPv6 address.

```bash
ipv6=$(net::resolve_target_ipv6 "example.com")
echo "IPv6: ${ipv6}"
```

**Arguments:**
- `$1` - FQDN to resolve

**Outputs:** IPv6 address

**Returns:** `PASS` (0) on success, `FAIL` (1) if resolution failed

### DHCP/Static Detection

#### net::get_ip_method

Determine if an interface uses DHCP or static IP assignment.

```bash
method=$(net::get_ip_method "eth0")
echo "IP method: ${method}"
```

**Arguments:**
- `$1` - Interface name

**Outputs:** "DHCP", "Static", or "Unknown"

**Returns:** `PASS` (0) if method determined, `FAIL` (1) if unknown

**Notes:** Checks NetworkManager, systemd-networkd, /etc/network/interfaces (Linux), and networksetup (macOS)

### Network Repair

#### net::repair_connectivity

Attempt self-healing of network issues (cross-platform).

```bash
if net::repair_connectivity; then
    echo "Network repaired"
else
    echo "Manual intervention required"
fi
```

**Returns:** `PASS` (0) if connectivity restored, `FAIL` (1) otherwise

**Notes:** Attempts network restart and DNS cache flush using platform abstractions

### Diagnostics

#### net::full_diagnostic

Perform a complete diagnostic check on network connectivity.

```bash
if net::full_diagnostic; then
    echo "All network checks passed"
else
    echo "Some network checks failed"
fi
```

**Returns:** `PASS` (0) if all checks succeed, `FAIL` (1) otherwise

**Checks performed:**
- Online connectivity (to gateway or default target)
- Local IP retrieval
- External IP retrieval

#### net::self_test

Run self-test for util_net.sh functionality.

```bash
net::self_test
```

**Returns:** `PASS` (0) if all tests pass, `FAIL` (1) otherwise

## Examples

### Network Diagnostics

```bash
#!/usr/bin/env bash
source util.sh

echo "=== Network Diagnostics ==="

if net::is_online; then
    pass "Internet: Connected"
else
    fail "Internet: Disconnected"
fi

net::get_local_ips
echo "External IP: $(net::get_external_ip)"
echo "Gateway:     $(net::get_gateway)"
echo "DNS Servers:"
net::get_dns_servers
```

### Interface Information

```bash
#!/usr/bin/env bash
source util.sh

echo "=== Network Interfaces ==="
for iface in $(net::list_interfaces); do
    echo "---"
    net::get_interface_info "${iface}"
done
```

### Port Scanner

```bash
#!/usr/bin/env bash
source util.sh

host="$1"
for port in 22 80 443 8080; do
    if net::check_port "${host}" "${port}"; then
        pass "Port ${port}: OPEN"
    else
        echo "Port ${port}: closed"
    fi
done
```

### Full Diagnostic

```bash
#!/usr/bin/env bash
source util.sh

# Run complete network diagnostic
net::full_diagnostic
```

## Self-Test

```bash
source util.sh
net::self_test
```
