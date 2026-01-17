#!/usr/bin/env bash
###############################################################################
# NAME         : basic_usage.sh
# DESCRIPTION  : Demonstrates basic usage of the common_core library
# AUTHOR       : Adam Compton
# DATE CREATED : 2024-12-15
###############################################################################

set -uo pipefail
IFS=$'\n\t'

# Source the common_core library
# Option 1: If installed to default location
if [[ -f "${HOME}/.config/bash/lib/common_core/util.sh" ]]; then
    source "${HOME}/.config/bash/lib/common_core/util.sh"
# Option 2: If running from the repository
elif [[ -f "$(dirname "${BASH_SOURCE[0]}")/../lib/util.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../lib/util.sh"
else
    echo "ERROR: common_core library not found" >&2
    exit 1
fi

#===============================================================================
# Basic Examples
#===============================================================================

info "Welcome to common_core!"
info "This script demonstrates basic library usage."

# Platform detection
info "Detecting platform..."
if platform::is_macos; then
    pass "Running on macOS"
elif platform::is_linux; then
    pass "Running on Linux"
    if platform::is_wsl; then
        info "  (WSL environment detected)"
    fi
fi

# Architecture detection
arch="$(os::get_arch)"
info "System architecture: ${arch}"

# Command existence checking
info "Checking for common commands..."
for cmd in bash git curl wget python3; do
    if cmd::exists "${cmd}"; then
        pass "${cmd} is available"
    else
        warn "${cmd} is not installed"
    fi
done

# Root check
if os::is_root; then
    warn "Running as root user"
else
    info "Running as regular user (EUID: ${EUID})"
fi

# File operations
info "Demonstrating file utilities..."
test_file="/tmp/common_core_example_$$"
if file::write "${test_file}" "Hello from common_core!"; then
    pass "Created test file: ${test_file}"

    if file::exists "${test_file}"; then
        content="$(file::read "${test_file}")"
        info "File content: ${content}"
    fi

    file::delete "${test_file}"
    pass "Cleaned up test file"
fi

info "Basic usage example complete!"
