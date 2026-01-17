#!/usr/bin/env bash
set -uo pipefail
IFS=$'\n\t'

###############################################################################
# NAME         : format.sh
# DESCRIPTION  : Format bash scripts with shfmt
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-01-04
###############################################################################
# EDIT HISTORY:
# DATE       | EDITED BY      | DESCRIPTION
# -----------|----------------|----------------------------------------------
# 2025-01-04 | Adam Compton   | Initial creation
# 2025-01-04 | Adam Compton   | Style compliance fixes - array usage, IFS
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

# Options
CHECK_ONLY=false

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
# parse_arguments
#------------------------------------------------------------------------------
# Purpose  : Parse command line arguments
# Arguments: $@ - Command line arguments
# Returns  : PASS on success
###############################################################################
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            --check | -c)
                CHECK_ONLY=true
                shift
                ;;
            *)
                error_msg "Unknown option: ${1}"
                printf 'Usage: %s [--check|-c]\n' "${0##*/}"
                return "${FAIL}"
                ;;
        esac
    done

    return "${PASS}"
}

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
# run_shfmt
#------------------------------------------------------------------------------
# Purpose  : Run shfmt on all found scripts
# Returns  : PASS if all checks pass, FAIL otherwise
###############################################################################
run_shfmt() {
    local -a files=()
    local file
    local exit_code=0
    local -a shfmt_args=(-i 4 -ci -sr)

    info "Finding shell scripts..."

    # Build array of files using process substitution
    while IFS= read -r file; do
        files+=("${file}")
    done < <(find_shell_scripts)

    if [[ ${#files[@]} -eq 0 ]]; then
        info "No .sh files found to format"
        return "${PASS}"
    fi

    info "Found ${#files[@]} script(s) to format"

    if [[ "${CHECK_ONLY}" == "true" ]]; then
        info "Running shfmt in check mode..."
        # Check mode - show diff without modifying
        if shfmt "${shfmt_args[@]}" -d "${files[@]}"; then
            exit_code="${PASS}"
        else
            exit_code="${FAIL}"
        fi
    else
        info "Running shfmt in write mode..."
        # Write mode - modify files in place
        if shfmt "${shfmt_args[@]}" -w "${files[@]}"; then
            exit_code="${PASS}"
        else
            exit_code="${FAIL}"
        fi
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

    # Parse arguments
    if ! parse_arguments "$@"; then
        return "${FAIL}"
    fi

    if run_shfmt; then
        if [[ "${CHECK_ONLY}" == "true" ]]; then
            pass_msg "All files are properly formatted"
        else
            pass_msg "Files formatted successfully"
        fi
        exit_code="${PASS}"
    else
        if [[ "${CHECK_ONLY}" == "true" ]]; then
            error_msg "Some files need formatting"
            info "Run './tools/format.sh' (without --check) to fix"
        else
            error_msg "shfmt encountered errors"
        fi
        exit_code="${FAIL}"
    fi

    return "${exit_code}"
}

#===============================================================================
# Script Entry Point
#===============================================================================

main "$@"
exit $?
