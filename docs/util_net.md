# util_net.sh - Network Utilities

Cross-platform network management, diagnostics, and inspection utilities for Linux, macOS, and WSL.

## Overview

This module provides:
- Connectivity checking
- IP address discovery (local and external)
- Port checking
- DNS resolution
- Network interface information
- DHCP/Static detection
- Network repair utilities

## Dependencies

- `util_cmd.sh`
- `util_platform.sh`
- `util_tui.sh`

## Functions

### Connectivity

#### net::is_online

Check if internet connectivity is available.

```bash
if net::is_online; then
    echo "Internet connected"
else
    echo "Offline"
fi
```

**Returns:** `PASS` (0) if online, `FAIL` (1) if offline

### IP Addresses

#### net::get_local_ip

Get the local/private IP address.

```bash
ip=$(net::get_local_ip)
echo "Local IP: ${ip}"
```

**Outputs:** Local IP address (e.g., 192.168.1.100)

#### net::get_external_ip

Get the external/public IP address.

```bash
ip=$(net::get_external_ip)
echo "External IP: ${ip}"
```

**Outputs:** External IP address

### Network Interface Information

#### net::get_default_interface

Get the default network interface.

```bash
iface=$(net::get_default_interface)
echo "Default interface: ${iface}"
```

**Outputs:** Interface name (e.g., "eth0", "en0")

#### net::get_gateway

Get the default gateway IP.

```bash
gateway=$(net::get_gateway)
echo "Gateway: ${gateway}"
```

**Outputs:** Gateway IP address

#### net::get_dns_servers

Get configured DNS servers.

```bash
dns=$(net::get_dns_servers)
echo "DNS: ${dns}"
```

**Outputs:** Space-separated list of DNS servers

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

**Returns:** `PASS` (0) if open, `FAIL` (1) if closed

### DNS Resolution

#### net::resolve_target

Resolve a hostname to an IP address.

```bash
ip=$(net::resolve_target "example.com")
echo "Resolved: ${ip}"
```

**Outputs:** IP address

#### net::ping

Ping a host.

```bash
if net::ping "example.com"; then
    echo "Host is reachable"
fi
```

**Returns:** `PASS` (0) if reachable, `FAIL` (1) otherwise

### DHCP/Static Detection

#### net::get_ip_method

Determine if an interface uses DHCP or static IP.

```bash
method=$(net::get_ip_method "eth0")
echo "IP method: ${method}"
```

**Outputs:** "DHCP", "Static", or "Unknown"

### Network Repair

#### net::repair_connectivity

Attempt to repair network connectivity issues.

```bash
if net::repair_connectivity; then
    echo "Network repaired"
fi
```

**Returns:** `PASS` (0) if connectivity restored, `FAIL` (1) otherwise

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

echo "Local IP:    $(net::get_local_ip)"
echo "External IP: $(net::get_external_ip)"
echo "Gateway:     $(net::get_gateway)"
echo "DNS:         $(net::get_dns_servers)"
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

## Self-Test

```bash
source util.sh
net::self_test
```
