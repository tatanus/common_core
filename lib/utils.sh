#!/usr/bin/env bash
###############################################################################
# NAME         : utils.sh
# DESCRIPTION  : Dynamically load all utility modules (util_*.sh) from ./utils.
# AUTHOR       : Adam Compton
# DATE CREATED : 2024-12-15
###############################################################################
# EDIT HISTORY:
# DATE        | EDITED BY      | DESCRIPTION
# ------------|----------------|-----------------------------------------------
# 2025-10-29  | Adam Compton   | Updated to load util_*.sh files from ./utils/
#                              | Added local log function fallbacks (no color).
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Library Guard
#===============================================================================
if [[ -n "${UTILS_SH_LOADED:-}" ]]; then
    if (return 0 2> /dev/null); then
        return 0
    else
        exit 0
    fi
else
    export UTILS_SH_LOADED=1
fi

#===============================================================================
# Environment Setup
#===============================================================================
export DEBIAN_FRONTEND=noninteractive

UTILS_PATH="$(realpath "${BASH_SOURCE[0]}")"
UTILS_DIR="$(dirname "${UTILS_PATH}")"
#UTILS_SUBDIR="${UTILS_DIR}/utils"

#===============================================================================
# Local Fallback Logging (No Colors)
#------------------------------------------------------------------------------
# These functions are defined only if not already provided by sourced modules.
###############################################################################
if ! declare -F info > /dev/null 2>&1; then
    function info()  { printf '[INFO ] %s\n' "${*}" >&2; }
fi

if ! declare -F warn > /dev/null 2>&1; then
    function warn()  { printf '[WARN ] %s\n' "${*}" >&2; }
fi

if ! declare -F error > /dev/null 2>&1; then
    function error() { printf '[ERROR] %s\n' "${*}" >&2; }
fi

if ! declare -F debug > /dev/null 2>&1; then
    function debug() { printf '[DEBUG] %s\n' "${*}" >&2; }
fi

if ! declare -F pass > /dev/null 2>&1; then
    function pass()  { printf '[PASS ] %s\n' "${*}" >&2; }
fi

if ! declare -F fail > /dev/null 2>&1; then
    function fail()  { printf '[FAIL ] %s\n' "${*}" >&2; }
fi

#===============================================================================
# Dynamic Utility Loader
#------------------------------------------------------------------------------
# Searches ./utils/ for all util_*.sh scripts and sources them sequentially.
# Fails fast if any source fails. Logs each action without color.
###############################################################################
info "Initializing utility loader in: ${UTILS_DIR}"

# if [[ ! -d "${UTILS_SUBDIR}" ]]; then
#     error "Missing ./utils directory. Expected at: ${UTILS_SUBDIR}"
#     exit 1
# fi

info "Scanning for util_*.sh files under ${UTILS_DIR}..."
UTILS_SOURCED=false

# shellcheck disable=SC2231
for util_file in "${UTILS_DIR}"/util_*.sh; do
    [[ -e "${util_file}" ]] || continue
    if [[ -f "${util_file}" ]]; then
        debug "Attempting to source: ${util_file}"
        # shellcheck disable=SC1090
        if source "${util_file}"; then
            pass "Successfully sourced: $(basename "${util_file}")"
            UTILS_SOURCED=true
        else
            fail "Failed to source: ${util_file}"
            exit 1
        fi
    fi
done

if [[ "${UTILS_SOURCED}" == false ]]; then
    warn "No util_*.sh scripts found in ${UTILS_DIR}"
else
    info "All utility modules loaded successfully."
fi

#===============================================================================
# Exported Variables
#===============================================================================
export UTILS_DIR UTILS_SUBDIR UTILS_SOURCED
debug "Utility framework initialization complete."
