#!/usr/bin/env bash
set -uo pipefail

# =============================================================================
# NAME        : menu.sh
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
if [[ -z "${MENU_SH_LOADED:-}" ]]; then
    declare -g MENU_SH_LOADED=true

    # Ensure the timestamp file exists
    if [[ ! -f "${MENU_TIMESTAMP_FILE}" ]]; then
        touch "${MENU_TIMESTAMP_FILE}" || {
            fail "Failed to create file: ${MENU_TIMESTAMP_FILE}"
            exit 1
        }
        info "Created file: ${MENU_TIMESTAMP_FILE}"
    fi

    # Append timestamps to each option
    # $1: Menu title
    # Remaining arguments: List of options
    function _append_timestamps_to_options() {
        local title="$1"
        shift
        local options=("$@")
        local updated_options=()

        for option in "${options[@]}"; do
            if [[ -n "${option}" ]]; then
                local timestamp
                # Check if the entry exists in the timestamp file
                timestamp=$(grep "^${title}::${option}:" "${MENU_TIMESTAMP_FILE}" | cut -d':' -f4-)
                if [[ -n "${timestamp}" ]]; then
                    # Append the option and timestamp into two columns
                    updated_options+=("$(printf '%-30s %s' "${option}" "(Last: ${timestamp})")")
                else
                    # Append only the option if no timestamp exists
                    updated_options+=("$(printf '%-30s %s' "${option}" "")")
                fi
            fi
        done

        # Print each option on a new line
        printf "%s\n" "${updated_options[@]}"
    }

    # Update the timestamp of a selected menu item
    # $1: Menu title
    # $2: Selected item
    function _update_menu_timestamp() {
        local menu_title="$1"
        local selected_item="$2"
        local timestamp
        timestamp=$(date +"%Y-%m-%d %H:%M:%S")

        # Check if the file exists, create it if it doesn't
        if [[ ! -f "${MENU_TIMESTAMP_FILE}" ]]; then
            touch "${MENU_TIMESTAMP_FILE}"
        fi

        # Check for macOS or Ubuntu
        if sed --version > /dev/null 2>&1; then
            # GNU sed (Ubuntu)
            if grep -q "^${menu_title}::${selected_item}:" "${MENU_TIMESTAMP_FILE}"; then
                # If the entry exists, replace it
                sed -i "/^${menu_title}::${selected_item}:/d" "${MENU_TIMESTAMP_FILE}"
            fi
        else
            # BSD sed (macOS)
            if grep -q "^${menu_title}::${selected_item}:" "${MENU_TIMESTAMP_FILE}"; then
                # If the entry exists, replace it
                sed -i '' "/^${menu_title}::${selected_item}:/d" "${MENU_TIMESTAMP_FILE}"
            fi
        fi

        # Add the new entry (append or replace)
        echo "${menu_title}::${selected_item}:${timestamp}" >> "${MENU_TIMESTAMP_FILE}"
    }

    # Display menu from a provided list
    # $1: Menu title (unique identifier for the menu)
    # $2: Function to execute on selection
    # $3: "true" or "false" flag to indicate whether to call _Pause
    # $4..: List of options (array or file path)
    function _display_menu() {
        local title="$1"
        shift
        local action_function="${1:-"_perform_menu_action"}"
        shift
        local pause_flag="${1:-false}"
        shift
        local options=("$@")

        while true; do
            # Append timestamps to each option
            local updated_options=()
            while IFS= read -r line; do
                updated_options+=("${line}")
            done < <(_append_timestamps_to_options "${title}" "${options[@]}")

            local menu_items=()
            menu_items+=("0) Back/Exit")
            for ((i = 0; i < ${#updated_options[@]}; i++)); do
                # Number each option correctly
                menu_items+=("$((i + 1))) ${updated_options[i]}")
            done

            local choice
            choice=$(printf "%s\n" "${menu_items[@]}" | fzf --prompt "${title} > ")

            # This command processes the user's menu choice and extracts the meaningful part:
            # 1. Removes leading numbers and parentheses (e.g., "2) " becomes "").
            # 2. Strips out any trailing "(Last: ...)" text.
            # 3. Removes any extra leading or trailing whitespace.
            # The result is stored in the variable `actual_choice`.
            choice=$(echo "${choice}" | sed 's/^[[:space:]]*[0-9]*)[[:space:]]*//' | sed 's/[[:space:]]*(Last:.*)//' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

            # Handle choice
            if [[ -z "${choice}" ]]; then
                return "${_PASS}"
            elif [[ "${choice}" == "Back/Exit" ]]; then
                return "${_PASS}"
            else
                # Update menu item timestamp persistently
                _update_menu_timestamp "${title}" "${choice}"

                # Move to the next line
                echo

                # Perform the action associated with the choice
                "${action_function}" "${choice}"

                if [[ "${pause_flag}" == "true" ]]; then
                    _Pause
                fi
            fi
        done
    }

    # Perform an action based on menu selection
    # $1: Selected menu item
    function _perform_menu_action() {
        local choice="$1"

        # Example: Placeholder for specific actions
        info "Action performed for: ${choice}"
        log_command "Executed action for menu item: ${choice}"
    }

    # Function to execute a Bash command or a script
    function _execute_and_wait() {
        local input="$1"

        if [[ -z "${input}" ]]; then
            warn "Usage: execute_command_or_script '<command or script>'"
            return "${_FAIL}"
        fi

        # Check if the input is a script
        # validate script exists and is executable
        if [[ -x "${input}" ]]; then
            info "Executing script: ${input}"
            "${input}"
        else
            # Assume it's a command and try to execute it
            info "Executing command: ${input}"
            eval "${input}"
        fi

        # Capture the exit status
        local exit_status=$?

        if [[ ${exit_status} -eq 0 ]]; then
            pass "Execution completed successfully."
        else
            fail "Execution failed with exit status ${exit_status}."
        fi

        return "${exit_status}"
    }

    # Function to wait for a given process to end
    function _wait_pid() {
        # Capture the process ID of the most recently executed background command
        process_id=$!

        # Check if the process ID is valid (non-empty and numeric)
        if [[ -z "${process_id}" || ! "${process_id}" =~ ^[0-9]+$ ]]; then
            #fail "Invalid process ID."
            return "${_FAIL}"  # Return an error code
        fi

        # Wait for the process with the captured PID to complete
        wait "${process_id}"
        wait_status=$?  # Capture the exit status of the wait command

        # Check if the wait command was successful
        if [[ ${wait_status} -ne 0 ]]; then
            fail "Process with PID ${process_id} did not complete successfully."
            return "${_FAIL}"  # Return an error code
        fi

        # Get the sleep duration from the argument, default to 0.5 second if not provided
        sleep_duration="${1:-0.5}"

        # Introduce the specified delay after the process completes
        sleep "${sleep_duration}"

        return "${_PASS}"  # Return success
    }

    function _exec_function() {
        local function_name="$1"  # The name of the function to execute
        shift                     # Remove the function name from the arguments
        local args=("$@")         # Collect any remaining arguments into an array

        # Check if a function name was provided
        if [[ -z "${function_name}" ]]; then
            warn "Usage: _Exec_Function '<function_name>' [arguments...]"
            return "${_FAIL}"
        fi

        # Check if the function is defined
        if declare -f "${function_name}" > /dev/null; then
            if [[ ${#args[@]} -eq 0 ]]; then
                info "Calling function: ${function_name} with no arguments"
                "${function_name}" || {
                    fail "Execution of function ${function_name} failed."
                    return "${_FAIL}"
                }
            else
                info "Calling function: ${function_name} with arguments: ${args[*]}"
                "${function_name}" "${args[@]}" || {
                    fail "Execution of function ${function_name} failed with arguments: ${args[*]}."
                    return "${_FAIL}"
                }
            fi
        else
            fail "Function ${function_name} not found."
            return "${_FAIL}"
        fi
    }
fi
