#!/usr/bin/env bash
###############################################################################
# NAME         : util_tui.sh
# DESCRIPTION  : Terminal UI utilities backed by dialog with safe fallbacks.
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-10-27
###############################################################################
# EDIT HISTORY:
# DATE       | EDITED BY      | DESCRIPTION
# -----------|----------------|------------------------------------------------
# 2025-10-27 | Adam Compton   | Initial generation
# 2025-12-07 | Adam Compton   | Integrated dialog-backed TUI abstraction
# 2025-12-25 | Adam Compton   | Corrected: Removed PASS/FAIL defs, added
#            |                | logging fallbacks, standardized error messages
# 2025-12-27 | Adam Compton   | Refactored show_spinner, show_dots, show_timer
#            |                | to use arrays instead of eval/bash -c. Commands
#            |                | now run in current shell environment.
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Library Guard
#===============================================================================
if [[ -n "${UTIL_TUI_SH_LOADED:-}" ]]; then
    if (return 0 2> /dev/null); then
        return 0
    fi
else
    UTIL_TUI_SH_LOADED=1
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
# Global Constants (imported from util.sh)
#===============================================================================
: "${PASS:=0}"
: "${FAIL:=1}"

DIALOG_BIN="${DIALOG_BIN:-dialog}"

#===============================================================================
# Internal Helpers
#===============================================================================

###############################################################################
# tui::_has_dialog
#------------------------------------------------------------------------------
# Purpose  : Check if dialog command is available.
# Usage    : tui::_has_dialog
# Returns  : PASS (0) if available, FAIL (1) otherwise
# Requires:
#   Environment: DIALOG_BIN
###############################################################################
function tui::_has_dialog() {
    cmd::exists "${DIALOG_BIN}"
}

###############################################################################
# tui::_dialog
#------------------------------------------------------------------------------
# Purpose  : Wrapper around dialog with --clear and --stdout.
# Usage    : tui::_dialog --menu "Title" 15 60 5 ...
# Arguments:
#   $@ : Dialog arguments
# Returns  : Exit code from dialog
# Requires:
#   Functions: tui::_has_dialog
#   Commands: dialog
###############################################################################
function tui::_dialog() {
    "${DIALOG_BIN}" --clear --stdout "$@"
}

#===============================================================================
# Prompt Utilities (dialog-backed)
#===============================================================================

###############################################################################
# tui::prompt_yes_no
#------------------------------------------------------------------------------
# Purpose  : Display a yes/no prompt.
# Usage    : tui::prompt_yes_no "Proceed?"
# Arguments:
#   $1 : Prompt text (optional, default: "Continue?")
# Returns  : PASS (0) if yes, FAIL (1) if no
# Requires:
#   Functions: tui::_has_dialog, tui::_dialog
###############################################################################
function tui::prompt_yes_no() {
    local prompt="${1:-Continue?}"

    if tui::_has_dialog; then
        tui::_dialog --yesno "${prompt}" 8 60 && return "${PASS}" || return "${FAIL}"
    fi

    local response
    while true; do
        read -rp "${prompt} [y/n]: " response
        case "${response,,}" in
            y | yes) return "${PASS}" ;;
            n | no) return "${FAIL}" ;;
            *) ;; # Invalid input, continue loop
        esac
    done
}

###############################################################################
# tui::prompt_input
#------------------------------------------------------------------------------
# Purpose  : Prompt for text input with optional default.
# Usage    : val=$(tui::prompt_input "Enter value" "default")
# Arguments:
#   $1 : Prompt text (required)
#   $2 : Default value (optional)
# Returns  : PASS (0) on success, FAIL (1) on cancel
# Outputs  : User input or default
# Requires:
#   Functions: tui::_has_dialog, tui::_dialog
###############################################################################
function tui::prompt_input() {
    local prompt="$1"
    local default="${2:-}"
    local result

    if tui::_has_dialog; then
        result=$(tui::_dialog --inputbox "${prompt}" 8 60 "${default}") || return "${FAIL}"
        printf '%s\n' "${result}"
        return "${PASS}"
    fi

    read -rp "${prompt} [${default}]: " result
    printf '%s\n' "${result:-${default}}"
}

###############################################################################
# tui::prompt_select
#------------------------------------------------------------------------------
# Purpose  : Display a single-select menu.
# Usage    : choice=$(tui::prompt_select "Pick one" opt1 opt2 opt3)
# Arguments:
#   $1 : Prompt text (required)
#   $@ : Options (required)
# Returns  : PASS (0) on success, FAIL (1) on cancel
# Outputs  : Selected option
# Requires:
#   Functions: tui::_has_dialog, tui::_dialog, error
###############################################################################
function tui::prompt_select() {
    local prompt="$1"
    shift
    local options=("$@")

    if [[ ${#options[@]} -eq 0 ]]; then
        error "tui::prompt_select: no options provided"
        return "${FAIL}"
    fi

    if tui::_has_dialog; then
        local dialog_opts=()
        for opt in "${options[@]}"; do
            dialog_opts+=("${opt}" "")
        done
        tui::_dialog --menu "${prompt}" 15 60 8 "${dialog_opts[@]}"
        return $?
    fi

    select opt in "${options[@]}"; do
        [[ -n "${opt}" ]] && printf '%s\n' "${opt}" && return "${PASS}"
    done

    return "${FAIL}"
}

###############################################################################
# tui::prompt_multiselect
#------------------------------------------------------------------------------
# Purpose  : Display a multi-select checklist.
# Usage    : selections=$(tui::prompt_multiselect "Pick items" a b c)
# Arguments:
#   $1 : Prompt text (required)
#   $@ : Options (required)
# Returns  : PASS (0) on success, FAIL (1) on cancel
# Outputs  : Space-separated selected options
# Requires:
#   Functions: tui::_has_dialog, tui::_dialog, error
###############################################################################
function tui::prompt_multiselect() {
    local prompt="$1"
    shift
    local options=("$@")

    if [[ ${#options[@]} -eq 0 ]]; then
        error "tui::prompt_multiselect: no options provided"
        return "${FAIL}"
    fi

    if tui::_has_dialog; then
        local dialog_opts=()
        for opt in "${options[@]}"; do
            dialog_opts+=("${opt}" "" off)
        done
        tui::_dialog --checklist "${prompt}" 18 70 10 "${dialog_opts[@]}"
        return $?
    fi

    # Fallback: stdin multi-select (space-separated)
    printf "%s\n" "${prompt}"
    printf "Options: %s\n" "${options[*]}"
    read -rp "Enter selections (space-separated): " selections
    printf '%s\n' "${selections}"
}

###############################################################################
# tui::msg
#------------------------------------------------------------------------------
# Purpose  : Display a message box.
# Usage    : tui::msg "Message"
# Arguments:
#   $1 : Message text (required)
# Returns  : PASS (0) always
# Requires:
#   Functions: tui::_has_dialog, tui::_dialog
###############################################################################
function tui::msg() {
    local message="${1:-}"

    if [[ -z "${message}" ]]; then
        error "tui::msg: no message provided"
        return "${FAIL}"
    fi

    if tui::_has_dialog; then
        tui::_dialog --msgbox "${message}" 8 60
        return "${PASS}"
    fi

    printf "%s\n" "${message}"
}

#===============================================================================
# Spinner / Progress (stdout-based by design)
#===============================================================================

###############################################################################
# tui::show_spinner
#------------------------------------------------------------------------------
# Purpose  : Display spinner animation while a command or PID runs.
# Usage    : tui::show_spinner -- sleep 5
#            tui::show_spinner -- git clone "$repo" "$dest"
#            long_running_command & tui::show_spinner $!
# Arguments:
#   $1   : PID to monitor, OR "--" followed by command array
#   $@   : Command and arguments (when $1 is "--")
# Returns  : Exit code of monitored process or command
# Notes    : Command runs in current shell environment, inheriting all
#            variables and functions. Use "--" separator for commands.
###############################################################################
function tui::show_spinner() {
    if [[ $# -eq 0 ]]; then
        error "tui::show_spinner: requires PID or -- command..."
        return "${FAIL}"
    fi

    local delay=0.1
    local spin="|/-\\"
    local start_time
    start_time=$(date +%s)
    local pid
    local is_command=0

    if [[ "$1" == "--" ]]; then
        # Command mode: run command array in background
        shift
        if [[ $# -eq 0 ]]; then
            error "tui::show_spinner: no command provided after --"
            return "${FAIL}"
        fi
        is_command=1
        # Run in background subshell to get PID, but inherit current environment
        ("$@") &
        pid=$!
    elif [[ "$1" =~ ^[0-9]+$ ]]; then
        # PID mode: monitor existing process
        pid="$1"
    else
        error "tui::show_spinner: first arg must be PID or '--'"
        return "${FAIL}"
    fi

    printf "Processing... (0s) "
    local i=0
    while kill -0 "${pid}" 2> /dev/null; do
        i=$(((i + 1) % 4))
        local elapsed
        elapsed=$(($(date +%s) - start_time))
        printf "\rProcessing... %s (%ss) " "${spin:${i}:1}" "${elapsed}"
        sleep "${delay}"
    done

    if [[ ${is_command} -eq 1 ]]; then
        wait "${pid}"
    fi

    local exit_code=$?
    local total_time
    total_time=$(($(date +%s) - start_time))

    if [[ ${exit_code} -eq 0 ]]; then
        pass "Processing... Done! (${total_time}s)"
    else
        fail "Processing... Failed! (${total_time}s)"
    fi

    return "${exit_code}"
}

###############################################################################
# tui::show_dots
#------------------------------------------------------------------------------
# Purpose  : Display simple animated dots while command or PID runs.
# Usage    : tui::show_dots -- sleep 3
#            tui::show_dots -- curl -fsSL "$url"
#            long_running_command & tui::show_dots $!
# Arguments:
#   $1   : PID to monitor, OR "--" followed by command array
#   $@   : Command and arguments (when $1 is "--")
# Returns  : Exit code of monitored process
# Notes    : Command runs in current shell environment, inheriting all
#            variables and functions. Use "--" separator for commands.
###############################################################################
function tui::show_dots() {
    if [[ $# -eq 0 ]]; then
        error "tui::show_dots: requires PID or -- command..."
        return "${FAIL}"
    fi

    local delay=0.5
    local pid
    local is_command=0

    if [[ "$1" == "--" ]]; then
        # Command mode: run command array in background
        shift
        if [[ $# -eq 0 ]]; then
            error "tui::show_dots: no command provided after --"
            return "${FAIL}"
        fi
        is_command=1
        # Run in background subshell to get PID, but inherit current environment
        ("$@") &
        pid=$!
    elif [[ "$1" =~ ^[0-9]+$ ]]; then
        # PID mode: monitor existing process
        pid="$1"
    else
        error "tui::show_dots: first arg must be PID or '--'"
        return "${FAIL}"
    fi

    printf "Processing"
    while kill -0 "${pid}" 2> /dev/null; do
        printf "."
        sleep "${delay}"
    done

    if [[ ${is_command} -eq 1 ]]; then
        wait "${pid}"
    fi

    local exit_code=$?
    printf "\n"

    if [[ ${exit_code} -eq 0 ]]; then
        pass "Processing complete"
    else
        fail "Processing failed"
    fi

    return "${exit_code}"
}

###############################################################################
# tui::show_progress_bar
#------------------------------------------------------------------------------
# Purpose  : Display a progress bar for percentage completion.
# Usage    : tui::show_progress_bar 45
# Arguments:
#   $1 : Percentage (0-100, required)
# Returns  : PASS (0) on success, FAIL (1) on invalid input
# Requires:
#   Functions: error, pass
###############################################################################
function tui::show_progress_bar() {
    local percent="${1:-0}"
    local width=50

    if ! [[ "${percent}" =~ ^[0-9]+$ ]]; then
        error "tui::show_progress_bar: progress value must be numeric"
        return "${FAIL}"
    fi

    ((percent > 100)) && percent=100
    ((percent < 0)) && percent=0

    local filled=$((percent * width / 100))
    printf "\rProgress: [%-*s] %3d%%" \
        "${width}" "$(printf "%0.s#" $(seq 1 "${filled}"))" "${percent}"

    if [[ "${percent}" -eq 100 ]]; then
        printf "\n"
        pass "Completed."
    fi
    return "${PASS}"
}

###############################################################################
# tui::show_timer
#------------------------------------------------------------------------------
# Purpose  : Run a command and display elapsed time upon completion.
# Usage    : tui::show_timer sleep 3
#            tui::show_timer git clone "$repo" "$dest"
# Arguments:
#   $@ : Command and arguments to execute (required)
# Returns  : Exit code of the executed command
# Notes    : Command runs in current shell environment, inheriting all
#            variables and functions.
###############################################################################
function tui::show_timer() {
    if [[ $# -eq 0 ]]; then
        error "tui::show_timer: requires a command"
        return "${FAIL}"
    fi

    local start_time
    start_time=$(date +%s)
    info "Running: $*"

    # Execute command directly in current environment
    "$@"
    local exit_code=$?

    local elapsed
    elapsed=$(($(date +%s) - start_time))

    if [[ ${exit_code} -eq 0 ]]; then
        pass "Command finished in ${elapsed}s"
    else
        fail "Command failed in ${elapsed}s (exit ${exit_code})"
    fi

    return "${exit_code}"
}

#===============================================================================
# Terminal Utilities
#===============================================================================

###############################################################################
# tui::is_terminal
#------------------------------------------------------------------------------
# Purpose  : Check if running in an interactive terminal
# Usage    : tui::is_terminal && info "Interactive terminal detected"
# Returns  : PASS (0) if terminal, FAIL (1) otherwise
###############################################################################
function tui::is_terminal() {
    [[ -t 1 ]] && return "${PASS}" || return "${FAIL}"
}

###############################################################################
# tui::supports_color
#------------------------------------------------------------------------------
# Purpose  : Check if terminal supports color output
# Usage    : tui::supports_color && use_colors=true
# Returns  : PASS (0) if color supported, FAIL (1) otherwise
###############################################################################
function tui::supports_color() {
    if ! tui::is_terminal; then
        return "${FAIL}"
    fi

    # Check TERM variable
    case "${TERM:-}" in
        *-256color | xterm-color | xterm | screen | linux)
            return "${PASS}"
            ;;
        *) ;; # Unknown TERM, check tput below
    esac

    # Check tput if available
    if cmd::exists tput; then
        local colors
        colors=$(tput colors 2> /dev/null || echo 0)
        [[ "${colors}" -ge 8 ]] && return "${PASS}"
    fi

    return "${FAIL}"
}

###############################################################################
# tui::get_terminal_width
#------------------------------------------------------------------------------
# Purpose  : Return the width of the terminal in columns.
# Usage    : width=$(tui::get_terminal_width)
# Returns  : PASS (0) always
# Outputs  : Terminal width
# Requires:
#   Commands: tput
###############################################################################
function tui::get_terminal_width() {
    local width
    width=$(tput cols 2> /dev/null || echo 80)
    printf '%s\n' "${width}"
    return "${PASS}"
}

###############################################################################
# tui::clear_line
#------------------------------------------------------------------------------
# Purpose  : Clear the current terminal line.
# Usage    : tui::clear_line
# Returns  : PASS (0) always
###############################################################################
function tui::clear_line() {
    printf "\r\033[K"
    return "${PASS}"
}

###############################################################################
# tui::pause
#------------------------------------------------------------------------------
# Purpose  : Pause execution until user presses ENTER.
# Usage    : tui::pause "Press ENTER to continue"
# Arguments:
#   $1 : Prompt text (optional)
# Returns  : PASS (0) always
###############################################################################
function tui::pause() {
    local prompt="${1:-Press ENTER to continue...}"
    read -rp "${prompt}"
    return "${PASS}"
}

###############################################################################
# tui::strip_color
#------------------------------------------------------------------------------
# Purpose  : Remove ANSI color codes from input or file.
# Usage    : tui::strip_color "string"
#            tui::strip_color /path/to/file
# Arguments:
#   $1 : String or file path (required)
# Returns  : PASS (0) on success, FAIL (1) on error
# Outputs  : Cleaned text
# Requires:
#   Functions: error
#   Commands: sed, grep
###############################################################################
function tui::strip_color() {
    if [[ -z "${1:-}" ]]; then
        error "tui::strip_color: no input provided"
        return "${FAIL}"
    fi

    if file::exists "$1"; then
        # Process file
        sed -E \
            -e 's/\x1B\[[0-9;]*[mK]//g' \
            -e 's/\x1B\([AB]//g' \
            -e 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g' \
            "$1" | tr -d '\000-\011\013-\037\177-\377'
    else
        # Process string
        printf '%s\n' "$1" | sed -E \
            -e 's/\x1B\[[0-9;]*[mK]//g' \
            -e 's/\x1B\([AB]//g' \
            -e 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g' |
            tr -d '\000-\011\013-\037\177-\377'
    fi

    return "${PASS}"
}

###############################################################################
# tui::self_test
#------------------------------------------------------------------------------
# Purpose  : Self-test for util_tui.sh functionality
# Usage    : tui::self_test
# Returns  : PASS (0) if all tests pass, FAIL (1) otherwise
# Globals  : None
###############################################################################
function tui::self_test() {
    info "Running util_tui.sh self-test..."

    local status="${PASS}"

    # Test 1: Check critical functions exist
    if ! declare -F tui::is_terminal > /dev/null 2>&1; then
        fail "tui::is_terminal function not available"
        status="${FAIL}"
    fi

    if ! declare -F tui::get_terminal_width > /dev/null 2>&1; then
        fail "tui::get_terminal_width function not available"
        status="${FAIL}"
    fi

    # Test 2: Test terminal detection
    if tui::is_terminal; then
        debug "Running in terminal context"

        # Test width detection
        if ! tui::get_terminal_width > /dev/null 2>&1; then
            fail "tui::get_terminal_width failed"
            status="${FAIL}"
        fi
    else
        debug "Not running in terminal - skipping interactive tests"
    fi

    # Test 3: Check utility functions
    if ! declare -F tui::supports_color > /dev/null 2>&1; then
        fail "tui::supports_color function not available"
        status="${FAIL}"
    fi

    if ! declare -F tui::strip_color > /dev/null 2>&1; then
        fail "tui::strip_color function not available"
        status="${FAIL}"
    fi

    if [[ "${status}" -eq "${PASS}" ]]; then
        pass "util_tui.sh self-test passed"
    else
        fail "util_tui.sh self-test failed"
    fi

    return "${status}"
}
