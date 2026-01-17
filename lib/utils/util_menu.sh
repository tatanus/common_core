#!/usr/bin/env bash
###############################################################################
# NAME         : util_menu.sh
# DESCRIPTION  : Dialog-backed menu utilities (primitives + hierarchical menus)
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-12-07
###############################################################################
# EDIT HISTORY:
# DATE        | EDITED BY      | DESCRIPTION
# ------------|----------------|-----------------------------------------------
# 2025-12-07  | Adam Compton   | Initial creation (primitive dialog wrappers)
# 2025-12-07  | Adam Compton   | Added timestamped menus, dynamic menus,
#                               and hierarchical tree menus.
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Library Guard
#===============================================================================
if [[ -n "${UTIL_MENU_SH_LOADED:-}" ]]; then
    if (return 0 2> /dev/null); then
        return 0
    fi
else
    UTIL_MENU_SH_LOADED=1
fi

#===============================================================================
# Module Dependencies
#===============================================================================
if [[ "${UTIL_CONFIG_SH_LOADED:-0}" -eq 0 ]]; then
    echo "ERROR: util_config.sh must be loaded before util_menu.sh" >&2
    return 1
fi

#===============================================================================
# Logging Fallbacks
#===============================================================================
if ! declare -F info > /dev/null 2>&1; then
    function info() { printf '[INFO ] %s\n' "${*}" >&2; }
fi
if ! declare -F warn > /dev/null 2>&1; then
    function warn() { printf '[WARN ] %s\n' "${*}" >&2; }
fi
if ! declare -F error > /dev/null 2>&1; then
    function error() { printf '[ERROR] %s\n' "${*}" >&2; }
fi
if ! declare -F debug > /dev/null 2>&1; then
    function debug() { printf '[DEBUG] %s\n' "${*}" >&2; }
fi
if ! declare -F pass > /dev/null 2>&1; then
    function pass() { printf '[PASS ] %s\n' "${*}" >&2; }
fi
if ! declare -F fail > /dev/null 2>&1; then
    function fail() { printf '[FAIL ] %s\n' "${*}" >&2; }
fi

#===============================================================================
# Globals and Configuration
#===============================================================================
# File used to store per-menu item timestamps
MENU_TIMESTAMP_FILE="${MENU_TIMESTAMP_FILE:-${XDG_STATE_HOME:-${HOME}/.local/state}/menu_timestamps}"

: "${PASS:=0}"
: "${FAIL:=1}"

# Ensure parent directory exists
if [[ ! -d "$(dirname "${MENU_TIMESTAMP_FILE}")" ]]; then
    mkdir -p "$(dirname "${MENU_TIMESTAMP_FILE}")" 2> /dev/null || true
fi

# Ensure the timestamp file exists (best effort)
if [[ ! -f "${MENU_TIMESTAMP_FILE}" ]]; then
    : > "${MENU_TIMESTAMP_FILE}" 2> /dev/null || true
fi

declare -a MENU_BREADCRUMB=()

#===============================================================================
# Internal Helpers (Not Intended for External Use)
#===============================================================================

###############################################################################
# menu::_push_breadcrumb
#------------------------------------------------------------------------------
# Purpose  : Add item to breadcrumb trail
# Usage    : menu::_push_breadcrumb "Main Menu"
# Returns  : PASS
###############################################################################
function menu::_push_breadcrumb() {
    local item="$1"
    MENU_BREADCRUMB+=("${item}")
    return "${PASS}"
}

###############################################################################
# menu::_pop_breadcrumb
#------------------------------------------------------------------------------
# Purpose  : Remove last item from breadcrumb trail
# Usage    : menu::_pop_breadcrumb
# Returns  : PASS
###############################################################################
function menu::_pop_breadcrumb() {
    if [[ ${#MENU_BREADCRUMB[@]} -gt 0 ]]; then
        unset 'MENU_BREADCRUMB[-1]'
    fi
    return "${PASS}"
}

###############################################################################
# menu::_get_breadcrumb
#------------------------------------------------------------------------------
# Purpose  : Get current breadcrumb trail as string
# Usage    : path=$(menu::_get_breadcrumb)
# Returns  : Prints breadcrumb path
###############################################################################
function menu::_get_breadcrumb() {
    if [[ ${#MENU_BREADCRUMB[@]} -eq 0 ]]; then
        printf "Home\n"
    else
        printf '%s\n' "${MENU_BREADCRUMB[*]}" | tr ' ' ' > '
    fi
}

###############################################################################
# menu::_dialog
#------------------------------------------------------------------------------
# Thin wrapper around dialog to enforce --clear and --stdout.
#--------------------
# Usage:
#   result=$(menu::_dialog --menu "Title" 15 60 5 ...)
#
# Return Values:
#   Exit code from dialog:
#     0   - OK/selection made
#     1   - Cancel
#     255 - ESC / error
#--------------------
# Requirements:
#   - dialog installed
###############################################################################
function menu::_dialog() {
    cmd::exists dialog || {
        fail "dialog is required for util_menu.sh"
        return "${FAIL}"
    }
    dialog --clear --stdout "$@"
}

###############################################################################
# menu::_timestamp_get
#------------------------------------------------------------------------------
# Retrieve last-seen timestamp for a menu item.
#--------------------
# Usage:
#   ts=$(menu::_timestamp_get "Menu Title" "Item Label")
#
# Return Values:
#   Prints timestamp string, or empty if none found.
#--------------------
# Requirements:
#   - MENU_TIMESTAMP_FILE readable
###############################################################################
function menu::_timestamp_get() {
    local menu="$1"
    local item="$2"
    grep "^${menu}::${item}:" "${MENU_TIMESTAMP_FILE}" 2> /dev/null |
        cut -d':' -f3-
}

###############################################################################
# menu::_timestamp_set
#------------------------------------------------------------------------------
# Set/update timestamp for a menu item to "now".
#--------------------
# Usage:
#   menu::_timestamp_set "Menu Title" "Item Label"
#
# Return Values:
#   0 on success (best-effort)
#   1 on I/O failure
#--------------------
# Requirements:
#   - MENU_TIMESTAMP_FILE writable (best-effort)
###############################################################################
function menu::_timestamp_set() {
    local menu="$1"
    local item="$2"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')

    # Portable sed -i handling
    if sed --version > /dev/null 2>&1; then
        # GNU sed (Linux)
        sed -i "/^${menu}::${item}:/d" "${MENU_TIMESTAMP_FILE}" 2> /dev/null || true
    else
        # BSD sed (macOS) - requires backup extension
        sed -i '' "/^${menu}::${item}:/d" "${MENU_TIMESTAMP_FILE}" 2> /dev/null || true
    fi

    printf '%s::%s:%s\n' "${menu}" "${item}" "${ts}" >> "${MENU_TIMESTAMP_FILE}"
}

#===============================================================================
# Primitive Menu Utilities
#===============================================================================

###############################################################################
# menu::select_single
#------------------------------------------------------------------------------
# Display a single-select menu using dialog.
#--------------------
# Usage:
#   choice=$(menu::select_single "Title" "Prompt" "opt1" "opt2" "opt3") || ...
#
# Arguments:
#   $1 - Menu title (string)
#   $2 - Prompt / message (string)
#   $3.. - Options (each a label string)
#
# Return Values:
#   0 (PASS) on success, prints selected option to stdout.
#   1 (FAIL) on error or if dialog is unavailable.
#
# Notes:
#   - Supports arrow keys, mouse, and ENTER / double-click (dialog-native).
###############################################################################
function menu::select_single() {
    local title="$1"
    local prompt="$2"
    shift 2
    local options=("$@")

    local nodes=()
    for opt in "${options[@]}"; do
        nodes+=("${opt}|return|${opt}")
    done

    local result
    result=$(menu::tree "${title}" "${prompt}" false "${nodes[@]}") || return "${FAIL}"

    [[ -z "${result}" ]] && return "${FAIL}"
    printf '%s\n' "${result}"
}

###############################################################################
# menu::select_multi
#------------------------------------------------------------------------------
# Display a multi-select checklist using dialog.
#--------------------
# Usage:
#   selections=$(menu::select_multi "Title" "Prompt" "opt1" "opt2" "opt3") || ...
#
# Arguments:
#   $1 - Menu title (string)
#   $2 - Prompt / message (string)
#   $3.. - Options (each a label string)
#
# Return Values:
#   0 (PASS) on success, prints space-separated selected options to stdout.
#   1 (FAIL) on error or cancel.
###############################################################################
function menu::select_multi() {
    local title="$1"
    local prompt="$2"
    shift 2

    menu::_dialog \
        --title "${title}" \
        --checklist "${prompt}" \
        18 75 12 \
        "$(printf '%s "" off ' "$@")"
}

###############################################################################
# menu::select_or_input
#------------------------------------------------------------------------------
# Display a single-select menu with an option for manual input.
#--------------------
# Usage:
#   value=$(menu::select_or_input "Title" "Prompt" "opt1" "opt2") || ...
#
# Behavior:
#   - If the user selects a listed option, that option is printed.
#   - If the user chooses "Manual entry", tui::prompt_input is used.
#
# Arguments:
#   $1 - Menu title (string)
#   $2 - Prompt / message (string)
#   $3.. - Options (each a label string)
#
# Return Values:
#   0 (PASS) on success, prints chosen or manually entered value to stdout.
#   1 (FAIL) on error or cancel.
###############################################################################
function menu::select_or_input() {
    local title="$1"
    local prompt="$2"
    shift 2

    local nodes=("Manual entry|func|tui::prompt_input")
    for opt in "$@"; do
        nodes+=("${opt}|return|${opt}")
    done

    local result
    result=$(menu::tree "${title}" "${prompt}" false "${nodes[@]}") || return "${FAIL}"
    printf '%s\n' "${result}"
}

###############################################################################
# menu::confirm_action
#------------------------------------------------------------------------------
# Confirm a risky or important action (yes/no).
#--------------------
# Usage:
#   menu::confirm_action "Delete all data?" && do_the_thing
#
# Arguments:
#   $1 - Confirmation prompt (string)
#
# Return Values:
#   0 (PASS) if user confirmed
#   1 (FAIL) if user declined or canceled
###############################################################################
function menu::confirm_action() {
    tui::prompt_yes_no "$1"
}

###############################################################################
# menu::pause
#------------------------------------------------------------------------------
# Pause execution until the user presses ENTER.
#--------------------
# Usage:
#   menu::pause
#
# Return Values:
#   Always 0 (PASS)
###############################################################################
function menu::pause() {
    tui::pause
}

#===============================================================================
# Dynamic Menus
#===============================================================================

###############################################################################
# menu::dynamic_from_file
#------------------------------------------------------------------------------
# Display a menu whose options are loaded dynamically from a file.
#--------------------
# Usage:
#   choice=$(menu::dynamic_from_file "Targets" "Choose a host:" "/path/to/targets.txt")
#
# Arguments:
#   $1 - Menu title (string)
#   $2 - Prompt / message (string)
#   $3 - Path to file containing options, one per line. Lines starting with
#        "#" or blank lines are ignored.
#
# Return Values:
#   0 (PASS) on success, prints selected option to stdout and updates timestamp.
#   1 (FAIL) if file missing, empty, or user cancels.
###############################################################################
function menu::dynamic_from_file() {
    local title="$1"
    local prompt="$2"
    local use_timestamps="${3:-false}"
    local file="$4"

    file::exists "${file}" || {
        fail "Menu file not found: ${file}"
        return "${FAIL}"
    }

    mapfile -t options < <(grep -Ev '^\s*(#|$)' "${file}")
    [[ ${#options[@]} -eq 0 ]] && {
        warn "No menu options found in ${file}"
        return "${FAIL}"
    }

    local nodes=()
    for opt in "${options[@]}"; do
        nodes+=("${opt}|return|${opt}")
    done

    menu::tree "${title}" "${prompt}" "${use_timestamps}" "${nodes[@]}"
}

#===============================================================================
# Hierarchical Menu Engine (DEFAULT)
#===============================================================================

###############################################################################
# menu::tree
#------------------------------------------------------------------------------
# Purpose  : Default menu renderer for all menus
# Usage    : menu::tree "Title" "Prompt" <timestamps:true|false> "${NODES[@]}"
# Arguments:
#   $1 : Menu title
#   $2 : Menu prompt text
#   $3 : Whether to show timestamps (true|false)
#   $@ : Node array in format "Label|TYPE|TARGET"
# Node Types:
#   menu   - TARGET is array variable name (submenu)
#   func   - TARGET is function name (menu:: or tui::)
#   cmd    - TARGET is shell command
#   return - TARGET is printed and returned
# Returns  : PASS (0) always
# Security : Uses eval for 'cmd' type nodes. This is acceptable because:
#            1. Menu nodes are defined in script source code, not user input
#            2. The menu structure is built by application developers
#            3. cmd type is used for pre-defined operations only
#            4. For user-provided commands, use 'func' type with validation
###############################################################################
function menu::tree() {
    local title="$1"
    local prompt="$2"
    local use_timestamps="${3:-false}"
    shift 3
    local nodes=("$@")

    # Use config for timestamps if not explicitly set
    if [[ -z "${use_timestamps}" ]]; then
        if config::get_bool "menu.timestamps"; then
            use_timestamps="true"
        else
            use_timestamps="false"
        fi
    fi

    # Use config for breadcrumbs
    local show_breadcrumbs
    if config::get_bool "menu.breadcrumbs"; then
        show_breadcrumbs=true
    else
        show_breadcrumbs=false
    fi

    if [[ "${show_breadcrumbs}" == "true" ]]; then
        menu::_push_breadcrumb "${title}"
    fi

    # Show breadcrumb in prompt if enabled
    local full_prompt
    if [[ "${show_breadcrumbs}" == "true" ]]; then
        full_prompt="$(menu::_get_breadcrumb)\n\n${prompt}"
    else
        full_prompt="${prompt}"
    fi

    while true; do
        local items=()

        for node in "${nodes[@]}"; do
            IFS='|' read -r label type target <<< "${node}"

            local desc="${type}"
            [[ "${use_timestamps}" == "true" ]] &&
                desc="$(menu::_timestamp_get "${title}" "${label}" || echo Never)"

            items+=("${label}" "${desc:-}")
        done

        items+=("Back" "Return to previous menu")

        local choice
        choice=$(menu::_dialog \
            --title "${title}" \
            --menu "${full_prompt}" \
            20 80 14 \
            "${items[@]}")

        if [[ $? -ne 0 || "${choice}" == "Back" ]]; then
            menu::_pop_breadcrumb
            return "${PASS}"
        fi

        for node in "${nodes[@]}"; do
            IFS='|' read -r label type target <<< "${node}"
            [[ "${label}" != "${choice}" ]] && continue

            [[ "${use_timestamps}" == "true" ]] &&
                menu::_timestamp_set "${title}" "${label}"

            case "${type}" in
                menu)
                    declare -n submenu="${target}"
                    menu::tree "${label}" "${prompt}" "${use_timestamps}" "${submenu[@]}"
                    ;;
                func)
                    if ! declare -F "${target}" > /dev/null; then
                        fail "Function not found: ${target}"
                        break
                    fi
                    "${target}" || warn "Function ${target} returned non-zero"
                    menu::pause
                    ;;
                cmd)
                    # SECURITY: TARGET originates from hardcoded menu definitions
                    # in source code, not from runtime user input. Applications
                    # must never construct menu nodes from untrusted input.
                    eval "${target}" || warn "Command failed: ${target}"
                    menu::pause
                    ;;
                return)
                    menu::_pop_breadcrumb
                    printf '%s\n' "${target}"
                    return "${PASS}"
                    ;;
                *)
                    warn "Unknown menu type: ${type}"
                    ;;
            esac
            break
        done
    done
}

###############################################################################
# menu::self_test
#------------------------------------------------------------------------------
# Purpose  : Self-test for util_menu.sh functionality
# Usage    : menu::self_test
# Returns  : PASS (0) if all tests pass, FAIL (1) otherwise
# Globals  : None
###############################################################################
function menu::self_test() {
    info "Running util_menu.sh self-test..."

    local status="${PASS}"

    # Test 1: Check critical functions exist
    if ! declare -F menu::select_single > /dev/null 2>&1; then
        fail "menu::select_single function not available"
        status="${FAIL}"
    fi

    if ! declare -F menu::select_multi > /dev/null 2>&1; then
        fail "menu::select_multi function not available"
        status="${FAIL}"
    fi

    if ! declare -F menu::confirm_action > /dev/null 2>&1; then
        fail "menu::confirm_action function not available"
        status="${FAIL}"
    fi

    # Test 2: Check helper functions
    if ! declare -F menu::_dialog > /dev/null 2>&1; then
        fail "menu::_dialog helper not available"
        status="${FAIL}"
    fi

    if [[ "${status}" -eq "${PASS}" ]]; then
        pass "util_menu.sh self-test passed"
    else
        fail "util_menu.sh self-test failed"
    fi

    return "${status}"
}
