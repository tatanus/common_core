#!/usr/bin/env bash
###############################################################################
# NAME         : logging_example.sh
# DESCRIPTION  : Demonstrates the logging functions in common_core
# AUTHOR       : Adam Compton
# DATE CREATED : 2024-12-15
###############################################################################

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
# Logging Level Examples
#===============================================================================

info "=== Logging Functions Demo ==="
info ""

# Standard logging levels
info "This is an INFO message - general information"
warn "This is a WARN message - something to be aware of"
error "This is an ERROR message - something went wrong"
debug "This is a DEBUG message - detailed debugging info"

info ""

# Success/failure indicators
pass "This is a PASS message - operation succeeded"
fail "This is a FAIL message - operation failed"

info ""
info "=== Using Logging in Scripts ==="

# Practical example: validating prerequisites
info "Checking prerequisites..."

###############################################################################
# check_prereq
#-------------------------------------------------------------------------------
# Purpose  : Check if a command exists in PATH
# Usage    : check_prereq <command>
# Arguments:
#   $1 : Command name to check
# Returns  : PASS if found, FAIL if missing
###############################################################################
function check_prereq() {
    local cmd="$1"
    if cmd::exists "${cmd}"; then
        pass "Found: ${cmd}"
        return "${PASS}"
    else
        fail "Missing: ${cmd}"
        return "${FAIL}"
    fi
}

check_prereq "bash"
check_prereq "git"
check_prereq "nonexistent_command_12345"

info ""
info "=== Return Code Constants ==="
info "PASS = ${PASS} (use for success)"
info "FAIL = ${FAIL} (use for failure)"

info ""
info "Logging example complete!"
