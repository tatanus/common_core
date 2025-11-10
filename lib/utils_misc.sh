#!/usr/bin/env bash
set -uo pipefail

# =============================================================================
# NAME        : utils_misc.sh
# DESCRIPTION :
# AUTHOR      : Adam Compton
# DATE CREATED: 2024-12-08 20:11:12
# =============================================================================
# EDIT HISTORY:
# DATE                 | EDITED BY    | DESCRIPTION OF CHANGE
# ---------------------|--------------|----------------------------------------
# 2024-12-08 20:11:12  | Adam Compton | Initial creation.
# =============================================================================

# Guard to prevent multiple sourcing
if [[ -z "${UTILS_MISC_SH_LOADED:-}" ]]; then
    declare -g UTILS_MISC_SH_LOADED=true

    ###############################################################################
    # replace_in_file
    #==============================
    # Replace a value in a file with another value.
    #---------------------------------------------------------------------
    # Usage:
    # replace_in_file <file_path> <replacement_value> [search_value]
    #
    # Arguments:
    #   file_path       - Full path to the file (required).
    #   replacement     - Replacement value (required).
    #   search_value    - Value to search for (optional, defaults to "__REPLACE__").
    #
    # Return Values:
    #   0: Success
    #   1: Failure (e.g., missing arguments, file not found, or sed error)
    ###############################################################################
    function replace_in_file() {
        local file_path="$1"
        local replacement="$2"
        local search_value="${3:-__REPLACE__}"
        local delimiter="|"

        # Validate inputs
        if [[ -z "${file_path}" || -z "${replacement}" ]]; then
            fail "Error: Missing required arguments."
            fail "Usage: replace_in_file <file_path> <replacement_value> [search_value]"
            return "${FAIL}"
        fi

        if [[ ! -f "${file_path}" ]]; then
            fail "Error: File '${file_path}' does not exist."
            return "${FAIL}"
        fi

        # Escape special characters in replacement and search values
        local escaped_replacement
        local escaped_search_value
        escaped_replacement=$(printf '%s' "${replacement}" | sed -e 's/[\/&]/\\&/g')
        escaped_search_value=$(printf '%s' "${search_value}" | sed -e 's/[\/&]/\\&/g')

        # Check if the search value exists in the file
        if ! grep -q "${escaped_search_value}" "${file_path}"; then
            warn "Warning: Search value '${search_value}' not found in file '${file_path}'."
            return "${FAIL}"
        fi

        # Perform in-place replacement using sed
        if sed -i.bak "s${delimiter}${escaped_search_value}${delimiter}${escaped_replacement}${delimiter}g" "${file_path}"; then
            info "Replaced '${search_value}' with '${replacement}' in '${file_path}'."
            # Optionally remove backup file (comment out the following line if backup is desired)
            rm -f "${file_path}.bak"
        else
            fail "Error: Failed to modify the file '${file_path}'."
            return "${FAIL}"
        fi
    }

    # Function to show a spinning wheel and elapsed time
    # Usage:
    #   show_spinner "$!"
    #   or
    #   show_spinner "long running command"
    # Function to show a spinner for a command or a running process
    function show_spinner() {
        local delay=0.1
        local spin='|/-\\'
        local start_time
        start_time=$(date +%s)
        local pid
        local is_command=0

        # First arg is a PID if it's only digits and only one argument
        if [[ "$1" =~ ^[0-9]+$ ]] && [[ $# -eq 1 ]]; then
            pid="$1"
        else
            is_command=1
            # Execute command with all arguments
            "$@" > /dev/null 2>&1 &
            pid=$!
        fi

        printf "Processing... (0s) "
        i=0
        while kill -0 "${pid}" 2> /dev/null; do
            i=$(((i + 1) % 4))
            local current_time
            current_time=$(date +%s)
            local elapsed=$((current_time - start_time))
            printf "\rProcessing... %s (%s seconds) " "${spin:${i}:1}" "${elapsed}"
            sleep "${delay}"
        done

        if [[ ${is_command} -eq 1 ]]; then
            wait "${pid}"
        fi
        local exit_code=$?

        local total_time=$(($(date +%s) - start_time))
        if [[ ${exit_code} -eq 0 ]]; then
            printf "\rProcessing... Done! (Total time: %s seconds)\n" "${total_time}"
        else
            printf "\rProcessing... Failed! (Total time: %s seconds)\n" "${total_time}"
        fi

        return "${exit_code}"
    }

    # Check and set proxy if required
    # TODO NEEDS WORK
    function _check_proxy_needed() {
        local test_url="${1:-"http://google.com"}"  # Default test URL
        local timeout="${2:-5}"  # Timeout for connectivity tests

        info "Testing connectivity to ${test_url}..."

        # Test direct connectivity
        if curl -s --connect-timeout "${timeout}" "${test_url}" > /dev/null; then
            PROXY=""
            pass "Direct Internet access available. No proxy needed."
            return "${PASS}"
        fi

        # Test connectivity via proxychains4
        if command -v proxychains4 > /dev/null 2>&1; then
            if proxychains4 -q curl -s --connect-timeout "${timeout}" "${test_url}" > /dev/null; then
                PROXY="proxychains4 -q "
                pass "Proxy required. Using proxychains4."
                return "${PASS}"
            else
                fail "Proxychains4 is available but cannot connect to ${test_url}."
            fi
        else
            fail "Direct access failed and proxychains4 is not installed."
        fi

        PROXY=""
        fail "No Internet access available."
        return "${FAIL}"
    }

    # Function to check if a variable is in a list
    function _in_list() {
        local select="$1"
        shift
        local command_list=("$@")

        for item in "${command_list[@]}"; do
            if [[ "${select}" == "${item}" ]]; then
                return "${PASS}"  # Item found
            fi
        done

        return "${FAIL}"  # Item not found
    }
fi
