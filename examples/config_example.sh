#!/usr/bin/env bash
###############################################################################
# NAME         : config_example.sh
# DESCRIPTION  : Demonstrates the configuration system in common_core
# AUTHOR       : Adam Compton
# DATE CREATED : 2024-12-15
###############################################################################

set -uo pipefail
IFS=$'\n\t'

# Source the common_core library
if [[ -f "${HOME}/.config/bash/lib/common_core/util.sh" ]]; then
    source "${HOME}/.config/bash/lib/common_core/util.sh"
elif [[ -f "$(dirname "${BASH_SOURCE[0]}")/../lib/util.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../lib/util.sh"
else
    echo "ERROR: common_core library not found" >&2
    exit 1
fi

#===============================================================================
# Configuration System Examples
#===============================================================================

info "=== Configuration System Demo ==="
info ""

# Create a temporary config file for this demo
CONFIG_FILE="/tmp/common_core_demo_$$.conf"

info "Creating demo config file: ${CONFIG_FILE}"
cat > "${CONFIG_FILE}" << 'EOF'
# Demo configuration file
APP_NAME=MyApplication
APP_VERSION=1.0.0
DEBUG_MODE=false
MAX_RETRIES=3
LOG_LEVEL=info
DATA_DIR=/var/lib/myapp
EOF

pass "Config file created"
info ""

# Load the configuration
info "Loading configuration..."
if config::load "${CONFIG_FILE}"; then
    pass "Configuration loaded successfully"
else
    fail "Failed to load configuration"
    exit 1
fi

info ""
info "=== Reading Configuration Values ==="

# Get configuration values with defaults
app_name="$(config::get "APP_NAME" "DefaultApp")"
app_version="$(config::get "APP_VERSION" "0.0.0")"
debug_mode="$(config::get "DEBUG_MODE" "false")"
max_retries="$(config::get "MAX_RETRIES" "5")"
missing_key="$(config::get "NONEXISTENT_KEY" "default_value")"

info "APP_NAME     = ${app_name}"
info "APP_VERSION  = ${app_version}"
info "DEBUG_MODE   = ${debug_mode}"
info "MAX_RETRIES  = ${max_retries}"
info "MISSING_KEY  = ${missing_key} (used default)"

info ""
info "=== Setting Configuration Values ==="

# Set new values
config::set "NEW_SETTING" "some_value"
config::set "DEBUG_MODE" "true"

new_setting="$(config::get "NEW_SETTING")"
debug_mode="$(config::get "DEBUG_MODE")"

info "NEW_SETTING  = ${new_setting}"
info "DEBUG_MODE   = ${debug_mode} (updated)"

info ""
info "=== Checking Configuration Keys ==="

if config::has "APP_NAME"; then
    pass "APP_NAME exists in config"
fi

if ! config::has "UNDEFINED_KEY"; then
    info "UNDEFINED_KEY does not exist (expected)"
fi

# Cleanup
info ""
info "Cleaning up demo config file..."
rm -f "${CONFIG_FILE}"
pass "Cleanup complete"

info ""
info "Configuration example complete!"
