# util_os.sh - Operating System Detection

Operating system detection and information utilities providing consistent access to OS details across Linux, macOS, and WSL.

## Overview

This module provides:
- OS type detection (Linux, macOS, WSL, BSD)
- Linux distribution identification
- Version and architecture information
- System resource information
- Root/privilege detection

## Dependencies

- `util_platform.sh`

## Functions

### OS Detection

#### os::detect

Get the current operating system name.

```bash
os_name=$(os::detect)
echo "Running on: ${os_name}"
```

**Returns:** `PASS` (0) always

**Outputs:** One of: `linux`, `macos`, `wsl`, `freebsd`, `openbsd`, `netbsd`, `windows`, `unknown`

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

**Notes:** Detects both WSL1 and WSL2

#### os::is_freebsd

Check if running on FreeBSD.

```bash
if os::is_freebsd; then
    pkg update
fi
```

**Returns:** `PASS` (0) if FreeBSD, `FAIL` (1) otherwise

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

**Returns:** `PASS` (0) if root, `FAIL` (1) otherwise

### Distribution Information

#### os::get_distro

Get the Linux distribution name.

```bash
distro=$(os::get_distro)
echo "Distribution: ${distro}"
```

**Returns:** `PASS` (0) always

**Outputs:** Distribution name (e.g., `ubuntu`, `debian`, `fedora`, `centos`, `arch`, `alpine`, `unknown`)

**Notes:** Returns `macos` on macOS, `unknown` on unrecognized systems

#### os::get_distro_version

Get the distribution version.

```bash
version=$(os::get_distro_version)
echo "Version: ${version}"
```

**Returns:** `PASS` (0) always

**Outputs:** Version string (e.g., `22.04`, `14.2`, `39`)

#### os::get_distro_codename

Get the distribution codename (if available).

```bash
codename=$(os::get_distro_codename)
echo "Codename: ${codename}"  # e.g., "jammy", "bookworm"
```

**Returns:** `PASS` (0) always

**Outputs:** Codename or empty string

### System Information

#### os::get_version

Get the full OS version string.

```bash
version=$(os::get_version)
echo "OS Version: ${version}"
```

**Returns:** `PASS` (0) always

**Outputs:** Full version string

#### os::get_kernel

Get the kernel version.

```bash
kernel=$(os::get_kernel)
echo "Kernel: ${kernel}"  # e.g., "5.15.0-91-generic"
```

**Returns:** `PASS` (0) always

**Outputs:** Kernel version string

#### os::get_arch

Get the system architecture.

```bash
arch=$(os::get_arch)
echo "Architecture: ${arch}"
```

**Returns:** `PASS` (0) always

**Outputs:** Architecture (e.g., `x86_64`, `aarch64`, `arm64`, `i686`, `armv7l`)

#### os::get_hostname

Get the system hostname.

```bash
hostname=$(os::get_hostname)
echo "Hostname: ${hostname}"
```

**Returns:** `PASS` (0) always

**Outputs:** Hostname

### Resource Information

#### os::get_memory

Get total system memory in KB.

```bash
memory=$(os::get_memory)
echo "Total Memory: ${memory} KB"

# Convert to GB
memory_gb=$((memory / 1024 / 1024))
echo "Total Memory: ${memory_gb} GB"
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Memory in kilobytes

#### os::get_memory_free

Get available/free system memory in KB.

```bash
free=$(os::get_memory_free)
echo "Free Memory: ${free} KB"
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Available memory in kilobytes

#### os::get_cpu_count

Get the number of CPU cores.

```bash
cpus=$(os::get_cpu_count)
echo "CPU Cores: ${cpus}"
```

**Returns:** `PASS` (0) always

**Outputs:** Number of CPU cores

#### os::get_disk_usage

Get disk usage for a path.

```bash
usage=$(os::get_disk_usage "/")
echo "Root disk usage: ${usage}%"
```

**Arguments:**
- `$1` - Path to check (default: /)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Usage percentage (0-100)

#### os::get_disk_free

Get free disk space in KB.

```bash
free=$(os::get_disk_free "/home")
echo "Free space: ${free} KB"
```

**Arguments:**
- `$1` - Path to check (default: /)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Free space in kilobytes

### Utility Functions

#### os::get_uptime

Get system uptime in seconds.

```bash
uptime=$(os::get_uptime)
echo "Uptime: ${uptime} seconds"

# Convert to hours
hours=$((uptime / 3600))
echo "Uptime: ${hours} hours"
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Uptime in seconds

#### os::get_load_average

Get system load average.

```bash
load=$(os::get_load_average)
echo "Load average: ${load}"
```

**Returns:** `PASS` (0) always

**Outputs:** Load average (1-minute)

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
    local arch
    arch=$(os::get_arch)
    if [[ "${arch}" != "x86_64" && "${arch}" != "aarch64" ]]; then
        error "Unsupported architecture: ${arch}"
        ((errors++))
    fi
    
    # Check memory (require at least 2GB)
    local memory
    memory=$(os::get_memory)
    local min_memory=$((2 * 1024 * 1024))  # 2GB in KB
    if (( memory < min_memory )); then
        error "Insufficient memory: ${memory}KB < ${min_memory}KB"
        ((errors++))
    fi
    
    # Check disk space (require at least 10GB)
    local disk_free
    disk_free=$(os::get_disk_free "/")
    local min_disk=$((10 * 1024 * 1024))  # 10GB in KB
    if (( disk_free < min_disk )); then
        error "Insufficient disk space: ${disk_free}KB < ${min_disk}KB"
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
if ! os::is_root; then
    if cmd::sudo_available; then
        info "Elevating privileges..."
        exec sudo "$0" "$@"
    else
        error "This script requires root privileges"
        error "Please run with sudo or as root"
        exit 1
    fi
fi

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
    echo "Distro:       $(os::get_distro) $(os::get_distro_version)"
    echo "Kernel:       $(os::get_kernel)"
    echo "Architecture: $(os::get_arch)"
    echo "Hostname:     $(os::get_hostname)"
    echo ""
    echo "=== Resources ==="
    echo "CPUs:         $(os::get_cpu_count)"
    echo "Memory:       $(($(os::get_memory) / 1024)) MB"
    echo "Memory Free:  $(($(os::get_memory_free) / 1024)) MB"
    echo "Disk Usage:   $(os::get_disk_usage /)%"
    echo "Uptime:       $(($(os::get_uptime) / 3600)) hours"
    echo "Load:         $(os::get_load_average)"
}

system_report
```

## Self-Test

```bash
source util.sh
os::self_test
```

Tests:
- OS detection functions
- Distribution detection
- Architecture detection
- Root check

## Notes

- WSL detection checks for Microsoft-specific strings in `/proc/version`
- Distribution detection uses `/etc/os-release` on Linux
- Memory values are in kilobytes for precision
- Architecture normalizes common variants (e.g., `arm64` → `aarch64`)
- Some functions may require elevated privileges for full information
