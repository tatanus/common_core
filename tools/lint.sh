#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

###############################################################################
# NAME         : lint.sh
# DESCRIPTION  : Run ShellCheck on all bash scripts in the project
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-01-04
###############################################################################
# EDIT HISTORY:
# DATE       | EDITED BY      | DESCRIPTION
# -----------|----------------|----------------------------------------------
# 2025-01-04 | Adam Compton   | Initial creation
# 2025-01-04 | Adam COmpton   | Style compliance fixes - array usage, IFS
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PROJECT_ROOT
readonly PASS=0
readonly FAIL=1

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly NC='\033[0m'

#===============================================================================
# Logging Functions
#===============================================================================

###############################################################################
# info
#------------------------------------------------------------------------------
# Purpose  : Display informational message
# Usage    : info "message"
# Arguments: $* - Message to display
# Outputs  : Formatted message to stdout
###############################################################################
info() {
    printf '[INFO] %s\n' "$*"
}

###############################################################################
# pass_msg
#------------------------------------------------------------------------------
# Purpose  : Display success message with color
# Usage    : pass_msg "message"
# Arguments: $* - Message to display
# Outputs  : Colored success message to stdout
###############################################################################
pass_msg() {
    printf '%b✓%b %s\n' "${GREEN}" "${NC}" "$*"
}

###############################################################################
# error_msg
#------------------------------------------------------------------------------
# Purpose  : Display error message with color
# Usage    : error_msg "message"
# Arguments: $* - Message to display
# Outputs  : Colored error message to stderr
###############################################################################
error_msg() {
    printf '%b✗%b %s\n' "${RED}" "${NC}" "$*" >&2
}

#===============================================================================
# Main Functions
#===============================================================================

###############################################################################
# find_shell_scripts
#------------------------------------------------------------------------------
# Purpose  : Find all .sh files in the project
# Returns  : Array of script paths via stdout (one per line)
# Notes    : Excludes .git, common_core, and node_modules directories
###############################################################################
find_shell_scripts() {
    find "${PROJECT_ROOT}" -type f -name "*.sh" \
        ! -path "*/.git/*" \
        ! -path "*/lib/common_core/*" \
        ! -path "*/node_modules/*" \
        ! -name "._*" \
        -print
}

###############################################################################
# run_shellcheck
#------------------------------------------------------------------------------
# Purpose  : Run ShellCheck on all found scripts
# Returns  : PASS if all checks pass, FAIL otherwise
###############################################################################
run_shellcheck() {
    local -a files=()
    local file
    local exit_code=0

    info "Finding shell scripts..."

    # Build array of files using process substitution
    while IFS= read -r file; do
        files+=("${file}")
    done < <(find_shell_scripts)

    if [[ ${#files[@]} -eq 0 ]]; then
        info "No .sh files found to lint"
        return "${PASS}"
    fi

    info "Found ${#files[@]} script(s) to check"
    info "Running ShellCheck..."

    # Run shellcheck on all files at once
    if shellcheck -x "${files[@]}"; then
        exit_code="${PASS}"
    else
        exit_code="${FAIL}"
    fi

    return "${exit_code}"
}

###############################################################################
# main
#------------------------------------------------------------------------------
# Purpose  : Main entry point
# Returns  : PASS if all checks pass, FAIL otherwise
###############################################################################
main() {
    local exit_code

    if run_shellcheck; then
        exit_code="${PASS}"
        pass_msg "All files passed ShellCheck"
    else
        exit_code="${FAIL}"
        error_msg "ShellCheck found issues"
    fi

    return "${exit_code}"
}

#===============================================================================
# Script Entry Point
#===============================================================================

main "$@"
exit $?
