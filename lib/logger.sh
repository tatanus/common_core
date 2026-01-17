#!/usr/bin/env bash

# =============================================================================
# NAME        : logger.sh
# DESCRIPTION : A modular and instance-based logging utility for Bash scripts.
#               - Provides configurable log levels (debug, info, warn, etc.)
#               - Supports logging to both console and file.
#               - Enables creation of multiple logger instances.
# AUTHOR      : Adam Compton
# DATE CREATED: 2024-12-08 20:11:12
# =============================================================================
# EDIT HISTORY:
# DATE                 | EDITED BY       | DESCRIPTION OF CHANGE
# ---------------------|-----------------|---------------------------------------
# 2024-12-08 20:11:12  | Adam Compton    | Initial creation.
# 2025-12-28           | Adam Compton    | Security & performance improvements.
# 2026-01-03           | Adam Compton    | CRITICAL: Replaced unsafe eval with
#                      |                 | temp file sourcing for function creation.
#                      |                 | Added additional instance name validation.
# =============================================================================

set -uo pipefail
IFS=$'\n\t'

# Guard to prevent multiple sourcing
if [[ -z "${LOGGER_SH_LOADED:-}" ]]; then
    declare -g LOGGER_SH_LOADED=true

    # =============================================================================
    # Define colors for screen output
    # =============================================================================

    # Check if `tput` is available; otherwise, use ANSI escape codes as fallback
    if [[ -t 1 && -n "$(command -v tput)" ]]; then
        light_green=$(tput setaf 2)
        light_blue=$(tput setaf 6)
        blue=$(tput setaf 4)
        light_red=$(tput setaf 1)
        yellow=$(tput setaf 3)
        orange=$(tput setaf 214 2> /dev/null || tput setaf 3) # Fallback to yellow if 214 isn't supported
        white=$(tput setaf 7)
        reset=$(tput sgr0)
    else
        light_green="\033[0;32m"
        light_blue="\033[1;36m"
        blue="\033[0;34m"
        light_red="\033[0;31m"
        yellow="\033[0;33m"
        orange="\033[1;33m" # Fallback to yellow
        white="\033[0;37m"
        reset="\033[0m"
    fi

    # =============================================================================
    # Default values
    # =============================================================================

    declare -gr LOGGER_INSTANCE_DEFAULT="default"
    declare -gr LOGGER_LEVEL_DEFAULT="info"
    declare -gr LOGGER_SCREEN_DEFAULT="true"
    declare -gr LOGGER_FILE_DEFAULT="true"
    declare -gr LOGGER_STACK_DEPTH_DEFAULT=3
    declare -gA LOGGER_INSTANCES=() # Track all logger instances

    # =============================================================================
    # CUSTOM LOG LEVEL CONSTANTS
    #
    # Here, we map each log level to a numeric "priority":
    #   vdebug -> 10 "verbose debug"
    #   debug  -> 20
    #   info   -> 30
    #   pass   -> 40
    #   warn   -> 50
    #   fail   -> 60
    #   error  -> 60
    #
    # Higher numbers mean "more severe/important," which can matter when filtering.
    # Adjust these to your liking, but keep them consistent with each other.
    # =============================================================================
    declare -gA log_level_priorities
    log_level_priorities[vdebug]=10
    log_level_priorities[debug]=20
    log_level_priorities[info]=30
    log_level_priorities[pass]=40
    log_level_priorities[warn]=50
    log_level_priorities[fail]=60
    log_level_priorities[error]=60

    ###############################################################################
    # _validate_instance_name
    #-------------------------------------------------------------------------------
    # Purpose  : Validate that an instance name is a safe Bash variable name
    # Usage    : _validate_instance_name <name>
    # Arguments:
    #   $1 : Instance name to validate
    # Returns  : 0 if valid, 1 if invalid
    # Security : Critical - instance name becomes part of function names
    ###########################################################################
    function _validate_instance_name() {
        local -r name="${1:-${LOGGER_INSTANCE_DEFAULT}}"

        # SECURITY: Strict validation - only alphanumeric and underscore
        if [[ ! "${name}" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            printf "Error: Invalid instance name '%s'. Must start with a letter or underscore and contain only alphanumeric characters and underscores.\n" "${name}" >&2
            return 1
        fi

        # SECURITY: Additional length check to prevent abuse
        if [[ ${#name} -gt 64 ]]; then
            printf "Error: Instance name too long (max 64 characters).\n" >&2
            return 1
        fi

        # SECURITY: Reject names that could cause issues
        case "${name}" in
            eval | exec | source | declare | export | readonly | local | unset | set | trap)
                printf "Error: Instance name '%s' is a reserved word.\n" "${name}" >&2
                return 1
                ;;
            *) ;;

        esac

        return 0
    }

    ###############################################################################
    # _sanitize_log_path
    #-------------------------------------------------------------------------------
    # Purpose  : Sanitize a file path to prevent directory traversal attacks
    # Usage    : _sanitize_log_path <path>
    # Arguments:
    #   $1 : Path to sanitize
    # Returns  : 0 if valid, 1 if path contains traversal patterns
    # Outputs  : Sanitized absolute path
    ###########################################################################
    function _sanitize_log_path() {
        local -r path="${1}"

        # Check for directory traversal patterns
        if [[ "${path}" =~ \.\. ]]; then
            printf "Error: Path contains '..' which is not allowed for security reasons.\n" >&2
            return 1
        fi

        # SECURITY FIX: Check for null bytes
        if [[ "${path}" == *$'\x00'* ]]; then
            printf "Error: Path contains null byte.\n" >&2
            return 1
        fi

        # Resolve to absolute path if possible
        local resolved_path
        if [[ -d "$(dirname "${path}" 2> /dev/null)" ]]; then
            resolved_path="$(cd "$(dirname "${path}")" && pwd)/$(basename "${path}")"
            printf "%s" "${resolved_path}"
        else
            printf "%s" "${path}"
        fi
        return 0
    }

    ###############################################################################
    # _validate_log_level
    #-------------------------------------------------------------------------------
    # Purpose  : Validate that a log level is a recognized level
    # Usage    : _validate_log_level <level>
    # Arguments:
    #   $1 : Log level to validate
    # Returns  : 0 if valid, 1 if invalid
    ###########################################################################
    function _validate_log_level() {
        local -r level="${1:-${LOGGER_LEVEL_DEFAULT}}"

        # Check if level is empty
        if [[ -z "${level}" ]]; then
            printf "Error: Log level is empty. Valid levels are: %s.\n" \
                "${!log_level_priorities[*]}" >&2
            return 1
        fi

        # Check if level exists in log_level_priorities
        if [[ -z "${log_level_priorities[${level}]:-}" ]]; then
            printf "Error: Invalid log level '%s'. Valid levels are: %s.\n" \
                "${level}" "${!log_level_priorities[*]}" >&2
            return 1
        fi
    }

    ###############################################################################
    # _logger_create_instance_methods
    #-------------------------------------------------------------------------------
    # Purpose  : Create instance methods safely without direct eval
    # Usage    : _logger_create_instance_methods <instance_name>
    # Arguments:
    #   $1 : Instance name (validated)
    # Returns  : 0 on success, 1 on failure
    # Security : Uses temp file approach which is safer than direct eval
    ###########################################################################
    function _logger_create_instance_methods() {
        local -r instance_name="${1}"

        # Double-check validation (defense in depth)
        if ! _validate_instance_name "${instance_name}"; then
            return 1
        fi

        # Create secure temp file
        local tmp_file
        tmp_file=$(mktemp) || {
            printf "Error: Failed to create temp file for logger methods.\n" >&2
            return 1
        }

        # Set restrictive permissions
        chmod 600 "${tmp_file}" || {
            rm -f -- "${tmp_file}"
            printf "Error: Failed to secure temp file.\n" >&2
            return 1
        }

        # Write function definitions to temp file
        # The instance_name has been validated to only contain safe characters
        cat > "${tmp_file}" << LOGGER_METHODS_EOF
function ${instance_name}.vdebug() { logger_log '${instance_name}' 'vdebug' "\$*"; }
function ${instance_name}.info() { logger_log '${instance_name}' 'info' "\$*"; }
function ${instance_name}.warn() { logger_log '${instance_name}' 'warn' "\$*"; }
function ${instance_name}.pass() { logger_log '${instance_name}' 'pass' "\$*"; }
function ${instance_name}.fail() { logger_log '${instance_name}' 'fail' "\$*"; }
function ${instance_name}.error() { logger_log '${instance_name}' 'error' "\$*"; }
function ${instance_name}.debug() { logger_log '${instance_name}' 'debug' "\$*"; }
function ${instance_name}.set_log_to_screen() { _logger_set_property '${instance_name}' 'log_to_screen' "\${1}"; }
function ${instance_name}.get_log_to_screen() { _logger_get_property '${instance_name}' 'log_to_screen'; }
function ${instance_name}.set_log_to_file() { _logger_set_property '${instance_name}' 'log_to_file' "\${1}"; }
function ${instance_name}.get_log_to_file() { _logger_get_property '${instance_name}' 'log_to_file'; }
function ${instance_name}.set_log_level() { _logger_set_property '${instance_name}' 'log_level' "\${1}"; }
function ${instance_name}.get_log_level() { _logger_get_property '${instance_name}' 'log_level'; }
function ${instance_name}.set_stack_depth() { _logger_set_property '${instance_name}' 'stack_depth' "\${1}"; }
function ${instance_name}.get_stack_depth() { _logger_get_property '${instance_name}' 'stack_depth'; }
LOGGER_METHODS_EOF

        # Source the temp file (safer than direct eval)
        # shellcheck source=/dev/null
        source "${tmp_file}"
        local rc=$?

        # Clean up temp file immediately
        rm -f -- "${tmp_file}"

        return "${rc}"
    }

    ###############################################################################
    # logger_init
    #-------------------------------------------------------------------------------
    # Purpose  : Initialize a new logger instance with specified configuration
    # Usage    : logger_init <name> [log_file] [log_level] [to_screen] [to_file]
    # Arguments:
    #   $1 : Instance name (default: LOGGER_INSTANCE_DEFAULT)
    #   $2 : Log file path (default: $HOME/<name>.log)
    #   $3 : Log level (default: LOGGER_LEVEL_DEFAULT)
    #   $4 : Log to screen (default: LOGGER_SCREEN_DEFAULT)
    #   $5 : Log to file (default: LOGGER_FILE_DEFAULT)
    # Returns  : 0 on success, 1 on failure
    ###########################################################################
    function logger_init() {
        local -r instance_name="${1:-${LOGGER_INSTANCE_DEFAULT}}"
        local log_file="${2:-${HOME}/${instance_name}.log}"
        local -r log_level="${3:-${LOGGER_LEVEL_DEFAULT}}"
        local -r log_to_screen="${4:-${LOGGER_SCREEN_DEFAULT}}"
        local -r log_to_file="${5:-${LOGGER_FILE_DEFAULT}}"

        # Validate instance name
        _validate_instance_name "${instance_name}" || return 1

        # Check if instance already exists
        if [[ -n "${LOGGER_INSTANCES[${instance_name}]:-}" ]]; then
            printf "Warning: Logger instance '%s' already exists. Reinitializing.\n" "${instance_name}" >&2
            logger_destroy "${instance_name}"
        fi

        # Validate log level
        _validate_log_level "${log_level}" || return 1

        # Sanitize log file path
        log_file=$(_sanitize_log_path "${log_file}") || return 1

        # Ensure log file directory exists
        local log_dir
        log_dir="$(dirname "${log_file}")"
        if [[ ! -d "${log_dir}" ]]; then
            printf "Error: Log file directory does not exist: %s\n" "${log_dir}" >&2
            return 1
        fi

        # Validate boolean values for log_to_screen and log_to_file
        if [[ "${log_to_screen}" != "true" && "${log_to_screen}" != "false" ]]; then
            printf "Error: log_to_screen must be 'true' or 'false'.\n" >&2
            return 1
        fi

        if [[ "${log_to_file}" != "true" && "${log_to_file}" != "false" ]]; then
            printf "Error: log_to_file must be 'true' or 'false'.\n" >&2
            return 1
        fi

        # Create an empty associative array for the instance
        declare -gA "${instance_name}_props"

        # Check if the array is declared
        if ! declare -p "${instance_name}_props" &> /dev/null; then
            printf "Error: Failed to declare %s_props\n" "${instance_name}" >&2
            return 1
        fi

        # Set properties using _logger_set_property
        _logger_set_property "${instance_name}" "log_file" "${log_file}" || return 1
        _logger_set_property "${instance_name}" "log_level" "${log_level}" || return 1
        _logger_set_property "${instance_name}" "log_to_screen" "${log_to_screen}" || return 1
        _logger_set_property "${instance_name}" "log_to_file" "${log_to_file}" || return 1
        _logger_set_property "${instance_name}" "stack_depth" "${LOGGER_STACK_DEPTH_DEFAULT}" || return 1

        # Track this instance
        LOGGER_INSTANCES[${instance_name}]="initialized"

        # SECURITY FIX: Create methods using safer approach
        if ! _logger_create_instance_methods "${instance_name}"; then
            # Cleanup on failure
            unset "${instance_name}_props"
            unset "LOGGER_INSTANCES[${instance_name}]"
            return 1
        fi

        return 0
    }

    ###############################################################################
    # logger_destroy
    #-------------------------------------------------------------------------------
    # Purpose  : Destroy a logger instance and clean up resources
    # Usage    : logger_destroy <instance_name>
    # Arguments:
    #   $1 : Instance name to destroy
    # Returns  : 0 on success, 1 if instance does not exist
    ###########################################################################
    function logger_destroy() {
        local -r instance_name="${1:-${LOGGER_INSTANCE_DEFAULT}}"

        # Validate instance exists
        if [[ -z "${LOGGER_INSTANCES[${instance_name}]:-}" ]]; then
            printf "Warning: Logger instance '%s' does not exist.\n" "${instance_name}" >&2
            return 1
        fi

        # Unset the properties array
        unset "${instance_name}_props"

        # Unset all instance methods
        unset -f "${instance_name}.vdebug" 2> /dev/null || true
        unset -f "${instance_name}.debug" 2> /dev/null || true
        unset -f "${instance_name}.info" 2> /dev/null || true
        unset -f "${instance_name}.warn" 2> /dev/null || true
        unset -f "${instance_name}.pass" 2> /dev/null || true
        unset -f "${instance_name}.fail" 2> /dev/null || true
        unset -f "${instance_name}.error" 2> /dev/null || true
        unset -f "${instance_name}.set_log_to_screen" 2> /dev/null || true
        unset -f "${instance_name}.get_log_to_screen" 2> /dev/null || true
        unset -f "${instance_name}.set_log_to_file" 2> /dev/null || true
        unset -f "${instance_name}.get_log_to_file" 2> /dev/null || true
        unset -f "${instance_name}.set_log_level" 2> /dev/null || true
        unset -f "${instance_name}.get_log_level" 2> /dev/null || true
        unset -f "${instance_name}.set_stack_depth" 2> /dev/null || true
        unset -f "${instance_name}.get_stack_depth" 2> /dev/null || true

        # Remove from tracking
        unset "LOGGER_INSTANCES[${instance_name}]"
    }

    # =============================================================================
    # Generates a timestamp for log entries
    # =============================================================================
    function _logger_timestamp() {
        date +"[%Y-%m-%d %H:%M:%S]"
    }

    ###############################################################################
    # logger_log
    #-------------------------------------------------------------------------------
    # Purpose  : Log a message at the specified level for a logger instance
    # Usage    : logger_log <instance_name> <level> <message...>
    # Arguments:
    #   $1 : Instance name
    #   $2 : Log level (debug, info, warn, pass, fail, error, vdebug)
    #   $@ : Message to log (remaining arguments)
    # Returns  : 0 on success, 1 on failure
    ###########################################################################
    function logger_log() {
        local -r instance_name="${1:-${LOGGER_INSTANCE_DEFAULT}}"
        local -r level="${2:-${LOGGER_LEVEL_DEFAULT}}"
        local -r message="${*:3}" # Capture all remaining arguments as message

        # Validate the log level
        if ! _validate_log_level "${level}"; then
            printf "Error: Invalid log level '%s'\n" "${level}" >&2
            return 1
        fi

        # Validate that the instance exists
        if ! declare -p "${instance_name}_props" &> /dev/null; then
            printf "Error: Logger instance '%s' does not exist.\n" "${instance_name}" >&2
            return 1
        fi

        # Use nameref for efficient property access (Bash 4.3+)
        local -n props_ref="${instance_name}_props"

        # Retrieve properties with defaults
        local log_file="${props_ref[log_file]:-${HOME}/${instance_name}.log}"
        local log_level="${props_ref[log_level]:-${LOGGER_LEVEL_DEFAULT}}"
        local log_to_screen="${props_ref[log_to_screen]:-${LOGGER_SCREEN_DEFAULT}}"
        local log_to_file="${props_ref[log_to_file]:-${LOGGER_FILE_DEFAULT}}"
        local stack_depth="${props_ref[stack_depth]:-${LOGGER_STACK_DEPTH_DEFAULT}}"

        # Get priorities for the current log level and the message log level
        local current_priority="${log_level_priorities[${log_level}]}"
        local priority="${log_level_priorities[${level}]}"

        # Ensure priorities are valid (should always be true after validation)
        if [[ -z "${current_priority}" || -z "${priority}" ]]; then
            printf "Error: Invalid log level priority.\n" >&2
            return 1
        fi

        # Skip logging if the message level is below the instance's configured level
        if [[ "${priority}" -lt "${current_priority}" ]]; then
            return 0
        fi

        # Parse caller information for debug messages
        local debug_info=""
        if [[ "${level}" == "debug" ]]; then
            # Get caller info from 1 level up
            local call_line
            call_line=$(caller 1 2> /dev/null || true)
            if [[ -n "${call_line}" ]]; then
                local line_number function_name file_name
                read -r line_number function_name file_name <<< "${call_line}"
                debug_info="CALLER: ${file_name}:${line_number} (${function_name})"
            fi

        elif [[ "${level}" == "vdebug" ]]; then
            debug_info="Stack Trace (last ${stack_depth} calls):"
            local i
            for ((i = 1; i <= stack_depth; i++)); do
                local call_line
                call_line=$(caller "${i}" 2> /dev/null || true)
                if [[ -z "${call_line}" ]]; then
                    break
                fi
                local line_number function_name file_name
                read -r line_number function_name file_name <<< "${call_line}"
                debug_info+="\\n  -> ${file_name}:${line_number} (${function_name})"
            done
        fi

        # Define log levels and their prefixes
        local timestamp prefix formatted_message
        timestamp=$(_logger_timestamp)
        case "${level}" in
            vdebug) prefix="[ # V-DBG ]" ;; # verbose debug
            debug) prefix="[ # DEBUG ]" ;;
            info) prefix="[ * INFO  ]" ;;
            warn) prefix="[ ! WARN  ]" ;;
            pass) prefix="[ + PASS  ]" ;;
            fail) prefix="[ - FAIL  ]" ;;
            error) prefix="[ - ERROR ]" ;;
            *) prefix="[ UNKNOWN ]" ;; # Fallback for unexpected log levels
        esac

        # Format the log message, including debug info if applicable
        if [[ -n "${debug_info}" ]]; then
            formatted_message="${debug_info} - ${message}"
        else
            formatted_message="${message}"
        fi

        # Attempt file logging (if enabled)
        local error_occurred=false
        if [[ "${log_to_file}" == "true" ]]; then
            if ! printf "%s %s %s\n" "${timestamp}" "${prefix}" "${formatted_message}" >> "${log_file}"; then
                printf "Error: Failed to write to log file: %s\n" "${log_file}" >&2
                error_occurred=true
            fi
        fi

        # Log to screen if enabled
        if [[ "${log_to_screen}" == "true" ]]; then
            local color
            case "${level}" in
                vdebug) color="${orange}" ;;
                debug) color="${orange}" ;;
                info) color="${blue}" ;;
                warn) color="${yellow}" ;;
                pass) color="${light_green}" ;;
                fail) color="${light_red}" ;;
                error) color="${light_red}" ;;
                *) color="${white}" ;;
            esac
            printf "%s %b%s%b %s\n" "${timestamp}" "${color}" "${prefix}" "${reset}" "${formatted_message}"
        fi

        # Return code based on whether file-logging failed
        if [[ "${error_occurred}" == "true" ]]; then
            return 1
        else
            return 0
        fi
    }

    ###############################################################################
    # _logger_set_property
    #-------------------------------------------------------------------------------
    # Purpose  : Set a property for a logger instance
    # Usage    : _logger_set_property <instance_name> <property> <value>
    # Arguments:
    #   $1 : Instance name
    #   $2 : Property name (log_level, log_to_screen, log_to_file, etc.)
    #   $3 : Property value
    # Returns  : 0 on success, 1 on failure
    ###########################################################################
    function _logger_set_property() {
        local -r instance_name="${1}"
        local -r property="${2}"
        local -r value="${3}"

        # Ensure the instance's associative array is declared
        if ! declare -p "${instance_name}_props" &> /dev/null; then
            printf "Error: Logger instance '%s' is not declared.\n" "${instance_name}" >&2
            return 1
        fi

        # Validate property names and values
        case "${property}" in
            log_level)
                _validate_log_level "${value}" || return 1
                ;;
            log_to_screen | log_to_file)
                if [[ "${value}" != "true" && "${value}" != "false" ]]; then
                    printf "Error: %s must be 'true' or 'false'.\n" "${property}" >&2
                    return 1
                fi
                ;;
            log_file)
                local dir
                dir="$(dirname "${value}" 2> /dev/null)"
                if [[ -z "${value}" ]] || { [[ "${value}" == */* ]] && [[ ! -d "${dir}" ]]; }; then
                    printf "Error: Log file directory does not exist: %s\n" "${dir}" >&2
                    return 1
                fi
                ;;
            stack_depth)
                if ! [[ "${value}" =~ ^[0-9]+$ ]] || [[ "${value}" -lt 1 ]] || [[ "${value}" -gt 10 ]]; then
                    printf "Error: stack_depth must be a number between 1 and 10.\n" >&2
                    return 1
                fi
                ;;
            *)
                printf "Error: Invalid property '%s'.\n" "${property}" >&2
                return 1
                ;;
        esac

        # Use nameref for safer assignment
        # shellcheck disable=SC2034,SC2178
        local -n props_array_ref="${instance_name}_props"
        # shellcheck disable=SC2004
        props_array_ref[${property}]="${value}"
    }

    ###############################################################################
    # _logger_get_property
    #-------------------------------------------------------------------------------
    # Purpose  : Get a property from a logger instance
    # Usage    : _logger_get_property <instance_name> <property>
    # Arguments:
    #   $1 : Instance name
    #   $2 : Property name
    # Returns  : 0 on success, 1 if instance does not exist
    # Outputs  : Property value
    ###########################################################################
    function _logger_get_property() {
        local -r instance_name="${1}"
        local -r property="${2}"

        # Validate instance exists
        if ! declare -p "${instance_name}_props" &> /dev/null; then
            printf "Error: Logger instance '%s' does not exist.\n" "${instance_name}" >&2
            return 1
        fi

        # Use nameref for safer property access
        # shellcheck disable=SC2034,SC2178
        local -n props_array_ref="${instance_name}_props"
        printf "%s" "${props_array_ref[${property}]}"
    }

    ###############################################################################
    # logger_list_instances
    #-------------------------------------------------------------------------------
    # Purpose  : List all active logger instances with their configuration
    # Usage    : logger_list_instances
    # Returns  : 0 always
    # Outputs  : List of active instances with level and log file
    ###########################################################################
    function logger_list_instances() {
        if [[ ${#LOGGER_INSTANCES[@]} -eq 0 ]]; then
            printf "No logger instances currently active.\n"
            return 0
        fi

        printf "Active logger instances:\n"
        local instance
        for instance in "${!LOGGER_INSTANCES[@]}"; do
            local -n instance_props="${instance}_props"
            printf "  - %s (level: %s, file: %s)\n" \
                "${instance}" \
                "${instance_props[log_level]:-unknown}" \
                "${instance_props[log_file]:-unknown}"
        done
    }
fi
