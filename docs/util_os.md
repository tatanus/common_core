# util_os.sh - Operating System Detection

Operating system detection and information utilities providing consistent access to OS details across Linux, macOS, and WSL.

## Overview

This module provides:
- OS type detection (Linux, macOS, WSL, Windows)
- Linux distribution identification
- Version and architecture information
- System resource information (CPU, memory, uptime)
- Root/privilege detection
- Shell detection

## Dependencies

- `util_platform.sh` (must be loaded before util_os.sh)

## Functions

### OS Detection

#### os::detect

Get the current operating system name.

```bash
os_name=$(os::detect)
echo "Running on: ${os_name}"
```

**Returns:** `PASS` (0) always

**Outputs:** One of: `linux`, `macos`, `wsl`, `windows`, `unknown`

#### os::is_linux

Check if running on Linux.

```bash
if os::is_linux; then
    apt-get update
fi
```

**Returns:** `PASS` (0) if Linux, `FAIL` (1) otherwise

**Notes:** Returns true for standard Linux, but false for WSL (use `os::is_wsl` for that)

#### os::is_macos

Check if running on macOS.

```bash
if os::is_macos; then
    brew update
fi
```

**Returns:** `PASS` (0) if macOS, `FAIL` (1) otherwise

#### os::is_wsl

Check if running in Windows Subsystem for Linux.

```bash
if os::is_wsl; then
    info "Running in WSL"
    # Can access Windows paths via /mnt/c/
fi
```

**Returns:** `PASS` (0) if WSL, `FAIL` (1) otherwise

**Notes:** Detects both WSL1 and WSL2 by checking `/proc/sys/kernel/osrelease` and `/proc/version`

#### os::is_root

Check if running as root user.

```bash
if os::is_root; then
    info "Running as root"
else
    error "This script requires root privileges"
    exit 1
fi
```

**Returns:** `PASS` (0) if root (EUID == 0), `FAIL` (1) otherwise

#### os::require_root

Require root privileges, exit if not root.

```bash
os::require_root "Installation requires root privileges"
# Script continues only if running as root
```

**Arguments:**
- `$1` - Optional custom error message (default: "This script must be run as root")

**Returns:** `PASS` (0) if root, `FAIL` (1) if not root (with error message to stderr)

### Architecture Detection

#### os::get_arch

Get the normalized system architecture.

```bash
arch=$(os::get_arch)
echo "Architecture: ${arch}"
```

**Returns:** `PASS` (0) always

**Outputs:** Normalized architecture string:
- `amd64` (from x86_64)
- `arm64` (from aarch64 or arm64)
- `386` (from i386, i486, i586, i686)
- `armhf` (from armv7l)
- `armv6` (from armv6l)
- `ppc64le`
- `s390x`
- `unsupported` (for unrecognized architectures)

#### os::is_arm

Check if system architecture is ARM-based.

```bash
if os::is_arm; then
    info "ARM architecture detected"
fi
```

**Returns:** `PASS` (0) if ARM (arm64, armhf, armv6, aarch64), `FAIL` (1) otherwise

#### os::is_x86

Check if system architecture is x86-based.

```bash
if os::is_x86; then
    info "x86 architecture detected"
fi
```

**Returns:** `PASS` (0) if x86 (amd64, 386, x86_64, i386-i686), `FAIL` (1) otherwise

### Distribution Information

#### os::get_distro

Get the Linux distribution name.

```bash
distro=$(os::get_distro)
echo "Distribution: ${distro}"
```

**Returns:** `PASS` (0) always

**Outputs:** Distribution name (e.g., `ubuntu`, `debian`, `fedora`, `centos`, `arch`, `rhel`, `unknown`)

**Notes:**
- Returns `macos` on macOS
- Uses `/etc/os-release`, `lsb_release`, or distribution-specific files for detection
- Returns `unknown` on unrecognized systems

### System Information

#### os::get_version

Get the OS version string.

```bash
version=$(os::get_version)
echo "OS Version: ${version}"
```

**Returns:** `PASS` (0) always

**Outputs:** Version string (e.g., `14.2` on macOS, `22.04` on Ubuntu) or `unknown`

**Notes:**
- On macOS: uses `sw_vers -productVersion`
- On Linux/WSL: uses `/etc/os-release` VERSION_ID or `lsb_release -sr`
- On Windows: parses output from `cmd.exe /c ver`

#### os::get_kernel_version

Get the kernel version string.

```bash
kernel=$(os::get_kernel_version)
echo "Kernel: ${kernel}"  # e.g., "5.15.0-91-generic"
```

**Returns:** `PASS` (0) always

**Outputs:** Kernel version string from `uname -r`, or `unknown`

#### os::get_hostname

Get the system hostname.

```bash
hostname=$(os::get_hostname)
echo "Hostname: ${hostname}"
```

**Returns:** `PASS` (0) always

**Outputs:** Hostname (uses `hostname` command, `/etc/hostname`, or `uname -n`)

#### os::get_shell

Get the current shell name.

```bash
shell=$(os::get_shell)
echo "Shell: ${shell}"  # e.g., "bash", "zsh"
```

**Returns:** `PASS` (0) always

**Outputs:** Shell name (e.g., `bash`, `zsh`) or `unknown`

**Notes:** Detects from `$SHELL` environment variable or `ps` command

#### os::str

Print a concise OS descriptor string.

```bash
os_info=$(os::str)
echo "System: ${os_info}"  # e.g., "macos 14.2 arm64"
```

**Returns:** `PASS` (0) always

**Outputs:** Combined string in format: `<OS> <Version> <Arch>`

### Resource Information

#### os::get_memory_total

Get total system memory in bytes.

```bash
memory=$(os::get_memory_total)
echo "Total Memory: ${memory} bytes"

# Convert to GB
memory_gb=$((memory / 1024 / 1024 / 1024))
echo "Total Memory: ${memory_gb} GB"
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error (outputs `0`)

**Outputs:** Memory in bytes

**Notes:**
- On macOS: uses `sysctl -n hw.memsize`
- On Linux: reads from `/proc/meminfo` and converts from KB to bytes

#### os::get_cpu_count

Get the number of CPU cores.

```bash
cpus=$(os::get_cpu_count)
echo "CPU Cores: ${cpus}"
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error (outputs `1` as fallback)

**Outputs:** Number of CPU cores

**Notes:**
- On macOS: uses `sysctl -n hw.ncpu`
- On Linux: counts processors in `/proc/cpuinfo` or uses `nproc`

#### os::get_uptime

Get system uptime in seconds.

```bash
uptime=$(os::get_uptime)
echo "Uptime: ${uptime} seconds"

# Convert to hours
hours=$((uptime / 3600))
echo "Uptime: ${hours} hours"
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error (outputs `0`)

**Outputs:** Uptime in seconds

**Notes:**
- On macOS: calculates from boot time via `sysctl -n kern.boottime`
- On Linux: reads from `/proc/uptime`

### Self-Test

#### os::self_test

Run self-test for util_os.sh functionality.

```bash
source util.sh
os::self_test
```

**Returns:** `PASS` (0) if all tests pass, `FAIL` (1) otherwise

**Tests:**
- OS detection (`os::detect`)
- Architecture detection (`os::get_arch`)
- Shell detection (`os::get_shell`)
- String representation (`os::str`)
- Distribution detection (`os::get_distro`)
- CPU count (`os::get_cpu_count`)

## Examples

### Cross-Platform Script

```bash
#!/usr/bin/env bash
source util.sh

# Detect and adapt
os=$(os::detect)

case "${os}" in
    linux)
        distro=$(os::get_distro)
        info "Running on Linux (${distro})"

        case "${distro}" in
            ubuntu|debian)
                package_manager="apt"
                ;;
            fedora|centos|rhel)
                package_manager="dnf"
                ;;
            arch)
                package_manager="pacman"
                ;;
        esac
        ;;
    macos)
        info "Running on macOS"
        package_manager="brew"
        ;;
    wsl)
        info "Running on WSL"
        package_manager="apt"
        ;;
    *)
        error "Unsupported OS: ${os}"
        exit 1
        ;;
esac
```

### System Requirements Check

```bash
#!/usr/bin/env bash
source util.sh

check_requirements() {
    local errors=0

    # Check architecture
    if os::is_arm; then
        info "ARM architecture detected"
    elif os::is_x86; then
        info "x86 architecture detected"
    else
        error "Unsupported architecture: $(os::get_arch)"
        ((errors++))
    fi

    # Check memory (require at least 2GB)
    local memory
    memory=$(os::get_memory_total)
    local min_memory=$((2 * 1024 * 1024 * 1024))  # 2GB in bytes
    if (( memory < min_memory )); then
        error "Insufficient memory: ${memory} bytes < ${min_memory} bytes"
        ((errors++))
    fi

    # Check CPU count
    local cpus
    cpus=$(os::get_cpu_count)
    if (( cpus < 2 )); then
        warn "Low CPU count: ${cpus} (recommended: 2+)"
    fi

    if (( errors > 0 )); then
        return "${FAIL}"
    fi

    pass "System requirements met"
    return "${PASS}"
}
```

### Root Check with Graceful Handling

```bash
#!/usr/bin/env bash
source util.sh

# Some operations require root
os::require_root "This installation requires root privileges"

# Now running as root
info "Running as root user"
```

### WSL-Specific Handling

```bash
#!/usr/bin/env bash
source util.sh

if os::is_wsl; then
    info "Detected WSL environment"

    # Access Windows files
    windows_home="/mnt/c/Users/${USER}"
    if [[ -d "${windows_home}" ]]; then
        info "Windows home: ${windows_home}"
    fi

    # Check WSL version
    if [[ -f /proc/version ]] && grep -qi "microsoft.*WSL2" /proc/version; then
        info "Running WSL2"
    else
        info "Running WSL1"
    fi
fi
```

### System Information Report

```bash
#!/usr/bin/env bash
source util.sh

system_report() {
    echo "=== System Information ==="
    echo "OS:           $(os::detect)"
    echo "Distro:       $(os::get_distro)"
    echo "Version:      $(os::get_version)"
    echo "Kernel:       $(os::get_kernel_version)"
    echo "Architecture: $(os::get_arch)"
    echo "Hostname:     $(os::get_hostname)"
    echo "Shell:        $(os::get_shell)"
    echo ""
    echo "=== Resources ==="
    echo "CPUs:         $(os::get_cpu_count)"
    echo "Memory:       $(($(os::get_memory_total) / 1024 / 1024)) MB"
    echo "Uptime:       $(($(os::get_uptime) / 3600)) hours"
    echo ""
    echo "=== Summary ==="
    echo "$(os::str)"
}

system_report
```

## Notes

- WSL detection checks for Microsoft-specific strings in `/proc/sys/kernel/osrelease` and `/proc/version`
- Distribution detection uses `/etc/os-release` on Linux (preferred), with fallbacks to `lsb_release` and distribution-specific files
- Memory values are returned in bytes (not kilobytes)
- Architecture is normalized to common identifiers (e.g., `x86_64` becomes `amd64`)
- Some functions may require elevated privileges for full information
- The module requires `util_platform.sh` to be loaded first
