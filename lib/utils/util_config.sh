#!/usr/bin/env bash
###############################################################################
# NAME         : util_config.sh
# DESCRIPTION  : Centralized configuration management system with validation,
#                persistence, environment integration, and hierarchical settings.
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-12-25
###############################################################################
# EDIT HISTORY:
# DATE        | EDITED BY      | DESCRIPTION
# ------------|----------------|-----------------------------------------------
# 2025-12-25  | Adam Compton   | Initial creation - configuration system
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Library Guard
#===============================================================================
if [[ -n "${UTIL_CONFIG_SH_LOADED:-}" ]]; then
    if (return 0 2> /dev/null); then
        return 0
    fi
else
    UTIL_CONFIG_SH_LOADED=1
fi

#===============================================================================
# Logging Fallbacks (respect log level if _util_should_log is available)
#===============================================================================
if ! declare -F info > /dev/null 2>&1; then
    if declare -F _util_should_log > /dev/null 2>&1; then
        function info() { _util_should_log info && printf '[INFO ] %s\n' "${*}" >&2; }
    else
        function info() { printf '[INFO ] %s\n' "${*}" >&2; }
    fi
fi
if ! declare -F warn > /dev/null 2>&1; then
    if declare -F _util_should_log > /dev/null 2>&1; then
        function warn() { _util_should_log warn && printf '[WARN ] %s\n' "${*}" >&2; }
    else
        function warn() { printf '[WARN ] %s\n' "${*}" >&2; }
    fi
fi
if ! declare -F error > /dev/null 2>&1; then
    if declare -F _util_should_log > /dev/null 2>&1; then
        function error() { _util_should_log error && printf '[ERROR] %s\n' "${*}" >&2; }
    else
        function error() { printf '[ERROR] %s\n' "${*}" >&2; }
    fi
fi
if ! declare -F debug > /dev/null 2>&1; then
    if declare -F _util_should_log > /dev/null 2>&1; then
        function debug() { _util_should_log debug && printf '[DEBUG] %s\n' "${*}" >&2; }
    else
        function debug() { :; } # Silent by default if no log system
    fi
fi
if ! declare -F pass > /dev/null 2>&1; then
    if declare -F _util_should_log > /dev/null 2>&1; then
        function pass() { _util_should_log pass && printf '[PASS ] %s\n' "${*}" >&2; }
    else
        function pass() { :; } # Silent by default if no log system
    fi
fi
if ! declare -F fail > /dev/null 2>&1; then
    if declare -F _util_should_log > /dev/null 2>&1; then
        function fail() { _util_should_log fail && printf '[FAIL ] %s\n' "${*}" >&2; }
    else
        function fail() { printf '[FAIL ] %s\n' "${*}" >&2; }
    fi
fi

#===============================================================================
# Global Constants
#===============================================================================
: "${PASS:=0}"
: "${FAIL:=1}"

#===============================================================================
# Configuration Storage
#===============================================================================

# Main configuration store (associative array)
declare -gA UTIL_CONFIG=()

# Configuration metadata (type, validation, description)
declare -gA UTIL_CONFIG_META=()

# Configuration defaults
declare -gA UTIL_CONFIG_DEFAULTS=()

# Configuration sources (env, file, runtime, default)
declare -gA UTIL_CONFIG_SOURCE=()

# Lock status for immutable configs
declare -gA UTIL_CONFIG_LOCKED=()

# Configuration file paths (searched in order)
declare -ga UTIL_CONFIG_PATHS=(
    "${UTIL_CONFIG_FILE:-}"
    "${HOME}/.config/bash_util/config"
    "${HOME}/.bash_util.conf"
)

#===============================================================================
# Core Configuration Management
#===============================================================================

###############################################################################
# config::init
#------------------------------------------------------------------------------
# Purpose  : Initialize configuration system with defaults
# Usage    : config::init
# Returns  : PASS always
###############################################################################
function config::init() {
    if [[ -n "${UTIL_CONFIG[_initialized]:-}" ]]; then
        debug "Configuration already initialized"
        return "${PASS}"
    fi

    debug "Initializing configuration system..."

    # =========================================================================
    # LOGGING CONFIGURATION
    # =========================================================================
    config::register "log.level" "info" "string" \
        "Logging level: debug, info, warn, error, none" \
        "debug|info|warn|error|none"

    config::register "log.color" "auto" "bool" \
        "Enable colored output: true, false, auto" \
        "true|false|auto"

    config::register "log.timestamp" "false" "bool" \
        "Include timestamps in log output" \
        "true|false"

    config::register "log.file" "" "path" \
        "Log file path (empty = no file logging)"

    config::register "log.format" "text" "string" \
        "Log format: text, json" \
        "text|json"

    # =========================================================================
    # TEMPORARY FILE CONFIGURATION
    # =========================================================================
    config::register "tmp.dir" "${TMPDIR:-/tmp}" "path" \
        "Base directory for temporary files"

    config::register "tmp.mode" "0700" "string" \
        "Default permissions for temp files/dirs" \
        "^[0-7]{3,4}$"

    config::register "tmp.cleanup" "true" "bool" \
        "Auto-cleanup temporary files on exit" \
        "true|false"

    config::register "tmp.prefix" "util" "string" \
        "Prefix for temporary file/directory names"

    # =========================================================================
    # NETWORK CONFIGURATION
    # =========================================================================
    config::register "net.timeout" "30" "int" \
        "Network operation timeout (seconds)" \
        "^[0-9]+$"

    config::register "net.retries" "3" "int" \
        "Number of network retry attempts" \
        "^[0-9]+$"

    config::register "net.retry_delay" "2" "int" \
        "Delay between retries (seconds)" \
        "^[0-9]+$"

    config::register "net.user_agent" "util-bash/1.0" "string" \
        "User agent string for HTTP requests"

    config::register "net.proxy" "" "string" \
        "HTTP/HTTPS proxy URL"

    config::register "net.cache_ttl" "600" "int" \
        "Network cache TTL (seconds)" \
        "^[0-9]+$"

    # =========================================================================
    # CURL CONFIGURATION
    # =========================================================================
    config::register "curl.timeout" "30" "int" \
        "Curl timeout (seconds)" \
        "^[0-9]+$"

    config::register "curl.max_redirects" "10" "int" \
        "Maximum HTTP redirects" \
        "^[0-9]+$"

    config::register "curl.max_retries" "3" "int" \
        "Maximum retry attempts" \
        "^[0-9]+$"

    config::register "curl.retry_delay" "2" "int" \
        "Delay between retries (seconds)" \
        "^[0-9]+$"

    # =========================================================================
    # FILE OPERATIONS CONFIGURATION
    # =========================================================================
    config::register "file.backup_suffix" ".bak" "string" \
        "Suffix for backup files"

    config::register "file.safe_mode" "true" "bool" \
        "Enable safety checks for destructive operations" \
        "true|false"

    config::register "file.checksum_algo" "sha256" "string" \
        "Default checksum algorithm" \
        "md5|sha1|sha256|sha512"

    # =========================================================================
    # DIRECTORY OPERATIONS CONFIGURATION
    # =========================================================================
    config::register "dir.safe_mode" "true" "bool" \
        "Enable safety checks for directory operations" \
        "true|false"

    config::register "dir.max_depth" "100" "int" \
        "Maximum directory traversal depth" \
        "^[0-9]+$"

    # =========================================================================
    # PACKAGE MANAGER CONFIGURATION
    # =========================================================================
    config::register "apt.auto_update" "false" "bool" \
        "Auto-update package lists before install" \
        "true|false"

    config::register "apt.auto_repair" "true" "bool" \
        "Auto-repair broken dependencies" \
        "true|false"

    config::register "brew.auto_update" "false" "bool" \
        "Auto-update Homebrew before install" \
        "true|false"

    # =========================================================================
    # GIT CONFIGURATION
    # =========================================================================
    config::register "git.default_branch" "main" "string" \
        "Default branch name for new repos"

    config::register "git.auto_fetch" "false" "bool" \
        "Auto-fetch before git operations" \
        "true|false"

    # =========================================================================
    # PLATFORM CONFIGURATION
    # =========================================================================
    config::register "platform.prefer_gnu" "true" "bool" \
        "Prefer GNU tools on BSD/macOS" \
        "true|false"

    config::register "platform.detect_cache" "true" "bool" \
        "Cache platform detection results" \
        "true|false"

    # =========================================================================
    # MENU/TUI CONFIGURATION
    # =========================================================================
    config::register "menu.timestamps" "false" "bool" \
        "Show timestamps in menu items" \
        "true|false"

    config::register "menu.breadcrumbs" "true" "bool" \
        "Show breadcrumb navigation" \
        "true|false"

    config::register "tui.dialog_backend" "dialog" "string" \
        "TUI backend: dialog, whiptail" \
        "dialog|whiptail"

    # =========================================================================
    # SECURITY CONFIGURATION
    # =========================================================================
    config::register "security.strict_mode" "true" "bool" \
        "Enable strict security checks" \
        "true|false"

    config::register "security.allow_elevated" "true" "bool" \
        "Allow automatic privilege escalation" \
        "true|false"

    # Mark as initialized
    UTIL_CONFIG[_initialized]="true"
    UTIL_CONFIG_LOCKED[_initialized]="true"

    # Load from environment and files
    config::load_from_env
    config::load_from_files

    debug "Configuration system initialized with $(config::count) settings"
    return "${PASS}"
}

###############################################################################
# config::register
#------------------------------------------------------------------------------
# Purpose  : Register a configuration key with metadata
# Usage    : config::register <key> <default> <type> <description> [validation]
# Arguments:
#   $1 : Configuration key (dot-notation: category.setting)
#   $2 : Default value
#   $3 : Type (string, int, bool, path, list)
#   $4 : Description
#   $5 : Validation pattern (regex) (optional)
# Returns  : PASS if registered, FAIL if invalid
###############################################################################
function config::register() {
    local key="${1:-}"
    local default="${2:-}"
    local type="${3:-string}"
    local description="${4:-}"
    local validation="${5:-}"

    if [[ -z "${key}" ]]; then
        error "config::register: key required"
        return "${FAIL}"
    fi

    # Validate type
    case "${type}" in
        string | int | bool | path | list) ;;
        *)
            error "config::register: invalid type '${type}' for key '${key}'"
            return "${FAIL}"
            ;;
    esac

    # Store default
    UTIL_CONFIG_DEFAULTS[${key}]="${default}"

    # Store metadata
    UTIL_CONFIG_META[${key}]="${type}|${description}|${validation}"

    # Set initial value to default if not already set
    if [[ -z "${UTIL_CONFIG[${key}]:-}" ]]; then
        UTIL_CONFIG[${key}]="${default}"
        UTIL_CONFIG_SOURCE[${key}]="default"
    fi

    debug "Registered config: ${key} = ${default} (${type})"
    return "${PASS}"
}

###############################################################################
# config::set
#------------------------------------------------------------------------------
# Purpose  : Set a configuration value with validation
# Usage    : config::set <key> <value>
# Arguments:
#   $1 : Configuration key
#   $2 : New value
# Returns  : PASS if set, FAIL if validation fails or key locked
###############################################################################
function config::set() {
    local key="${1:-}"
    local value="${2:-}"

    if [[ -z "${key}" ]]; then
        error "config::set: key required"
        return "${FAIL}"
    fi

    # Check if locked
    if [[ "${UTIL_CONFIG_LOCKED[${key}]:-false}" == "true" ]]; then
        error "config::set: key '${key}' is locked and cannot be modified"
        return "${FAIL}"
    fi

    # Check if registered
    if [[ -z "${UTIL_CONFIG_META[${key}]:-}" ]]; then
        warn "config::set: setting unregistered key '${key}'"
    fi

    # Validate if registered
    if ! config::validate "${key}" "${value}"; then
        error "config::set: validation failed for '${key}' = '${value}'"
        return "${FAIL}"
    fi

    # Store old value for comparison
    local old_value="${UTIL_CONFIG[${key}]:-}"

    # Set new value
    UTIL_CONFIG[${key}]="${value}"
    UTIL_CONFIG_SOURCE[${key}]="runtime"

    if [[ "${old_value}" != "${value}" ]]; then
        debug "Config changed: ${key} = '${value}' (was: '${old_value}')"
    fi

    return "${PASS}"
}

###############################################################################
# config::get
#------------------------------------------------------------------------------
# Purpose  : Get a configuration value
# Usage    : value=$(config::get <key> [default])
# Arguments:
#   $1 : Configuration key
#   $2 : Default value if key not found (optional)
# Returns  : PASS always
# Outputs  : Configuration value or default
###############################################################################
function config::get() {
    local key="${1:-}"
    local default="${2:-}"

    if [[ -z "${key}" ]]; then
        printf '%s\n' "${default}"
        return "${PASS}"
    fi

    local value="${UTIL_CONFIG[${key}]:-${default}}"
    printf '%s\n' "${value}"
    return "${PASS}"
}

###############################################################################
# config::get_bool
#------------------------------------------------------------------------------
# Purpose  : Get a boolean configuration value (returns 0/1)
# Usage    : config::get_bool <key> && do_something
# Arguments:
#   $1 : Configuration key
# Returns  : PASS (0) if true, FAIL (1) if false
###############################################################################
function config::get_bool() {
    local key="${1:-}"
    local value

    value=$(config::get "${key}" "false")

    case "${value,,}" in
        true | yes | 1 | on)
            return "${PASS}"
            ;;
        *)
            return "${FAIL}"
            ;;
    esac
}

###############################################################################
# config::get_int
#------------------------------------------------------------------------------
# Purpose  : Get an integer configuration value
# Usage    : timeout=$(config::get_int <key> [default])
# Arguments:
#   $1 : Configuration key
#   $2 : Default value (optional)
# Returns  : PASS always
# Outputs  : Integer value or default
###############################################################################
function config::get_int() {
    local key="${1:-}"
    local default="${2:-0}"
    local value

    value=$(config::get "${key}" "${default}")

    # Ensure it's an integer
    if [[ "${value}" =~ ^[0-9]+$ ]]; then
        printf '%s\n' "${value}"
    else
        printf '%s\n' "${default}"
    fi

    return "${PASS}"
}

###############################################################################
# config::validate
#------------------------------------------------------------------------------
# Purpose  : Validate a configuration value against its metadata
# Usage    : config::validate <key> <value>
# Arguments:
#   $1 : Configuration key
#   $2 : Value to validate
# Returns  : PASS if valid, FAIL otherwise
###############################################################################
function config::validate() {
    local key="${1:-}"
    local value="${2:-}"

    # If not registered, allow anything
    if [[ -z "${UTIL_CONFIG_META[${key}]:-}" ]]; then
        return "${PASS}"
    fi

    # Parse metadata
    local meta="${UTIL_CONFIG_META[${key}]}"
    local type validation
    IFS='|' read -r type _ validation <<< "${meta}"

    # Type-specific validation
    case "${type}" in
        int)
            if ! [[ "${value}" =~ ^-?[0-9]+$ ]]; then
                debug "Validation failed: '${value}' is not an integer"
                return "${FAIL}"
            fi
            ;;
        bool)
            case "${value,,}" in
                true | false | yes | no | 1 | 0 | on | off) ;;
                *)
                    debug "Validation failed: '${value}' is not a boolean"
                    return "${FAIL}"
                    ;;
            esac
            ;;
        path)
            # Path validation is lenient (doesn't require existence)
            if [[ -z "${value}" ]]; then
                return "${PASS}"
            fi
            ;;
        *) ;; # Unknown type, continue to custom validation
    esac

    # Custom validation pattern
    if [[ -n "${validation}" ]]; then
        if ! [[ "${value}" =~ ${validation} ]]; then
            debug "Validation failed: '${value}' does not match pattern '${validation}'"
            return "${FAIL}"
        fi
    fi

    return "${PASS}"
}

###############################################################################
# config::lock
#------------------------------------------------------------------------------
# Purpose  : Lock a configuration key (make immutable)
# Usage    : config::lock <key>
# Arguments:
#   $1 : Configuration key
# Returns  : PASS always
###############################################################################
function config::lock() {
    local key="${1:-}"

    if [[ -z "${key}" ]]; then
        error "config::lock: key required"
        return "${FAIL}"
    fi

    UTIL_CONFIG_LOCKED[${key}]="true"
    debug "Locked config key: ${key}"
    return "${PASS}"
}

###############################################################################
# config::unlock
#------------------------------------------------------------------------------
# Purpose  : Unlock a configuration key
# Usage    : config::unlock <key>
# Arguments:
#   $1 : Configuration key
# Returns  : PASS always
###############################################################################
function config::unlock() {
    local key="${1:-}"

    if [[ -z "${key}" ]]; then
        error "config::unlock: key required"
        return "${FAIL}"
    fi

    UTIL_CONFIG_LOCKED[${key}]="false"
    debug "Unlocked config key: ${key}"
    return "${PASS}"
}

###############################################################################
# config::reset
#------------------------------------------------------------------------------
# Purpose  : Reset a configuration key to default value
# Usage    : config::reset <key>
# Arguments:
#   $1 : Configuration key
# Returns  : PASS if reset, FAIL if locked or not registered
###############################################################################
function config::reset() {
    local key="${1:-}"

    if [[ -z "${key}" ]]; then
        error "config::reset: key required"
        return "${FAIL}"
    fi

    if [[ "${UTIL_CONFIG_LOCKED[${key}]:-false}" == "true" ]]; then
        error "config::reset: key '${key}' is locked"
        return "${FAIL}"
    fi

    if [[ -z "${UTIL_CONFIG_DEFAULTS[${key}]:-}" ]]; then
        error "config::reset: key '${key}' not registered"
        return "${FAIL}"
    fi

    UTIL_CONFIG[${key}]="${UTIL_CONFIG_DEFAULTS[${key}]}"
    UTIL_CONFIG_SOURCE[${key}]="default"

    info "Reset config: ${key} = ${UTIL_CONFIG[${key}]}"
    return "${PASS}"
}

#===============================================================================
# Configuration Loading/Saving
#===============================================================================

###############################################################################
# config::load_from_env
#------------------------------------------------------------------------------
# Purpose  : Load configuration from environment variables
# Usage    : config::load_from_env
# Returns  : PASS always
# Notes    : Looks for UTIL_CONFIG_<KEY> variables (e.g., UTIL_CONFIG_LOG_LEVEL)
###############################################################################
function config::load_from_env() {
    local count=0
    local key value env_var

    for key in "${!UTIL_CONFIG_DEFAULTS[@]}"; do
        # Convert key to environment variable name
        # log.level -> UTIL_CONFIG_LOG_LEVEL
        env_var="UTIL_CONFIG_$(echo "${key}" | tr '[:lower:].' '[:upper:]_')"

        if [[ -n "${!env_var:-}" ]]; then
            value="${!env_var}"
            if config::set "${key}" "${value}"; then
                UTIL_CONFIG_SOURCE[${key}]="env"
                debug "Loaded from env: ${key} = ${value}"
                ((count++))
            fi
        fi
    done

    if [[ ${count} -gt 0 ]]; then
        info "Loaded ${count} settings from environment"
    fi

    return "${PASS}"
}

###############################################################################
# config::load_from_file
#------------------------------------------------------------------------------
# Purpose  : Load configuration from a file
# Usage    : config::load_from_file <path>
# Arguments:
#   $1 : Configuration file path
# Returns  : PASS if loaded, FAIL if file not found or invalid
###############################################################################
function config::load_from_file() {
    local file="${1:-}"

    if [[ -z "${file}" ]]; then
        error "config::load_from_file: file path required"
        return "${FAIL}"
    fi

    if [[ ! -f "${file}" ]]; then
        debug "Config file not found: ${file}"
        return "${FAIL}"
    fi

    if [[ ! -r "${file}" ]]; then
        error "Config file not readable: ${file}"
        return "${FAIL}"
    fi

    info "Loading configuration from: ${file}"

    local line_num=0 count=0 key value
    while IFS= read -r line; do
        ((line_num++))

        # Skip empty lines and comments
        [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]] && continue

        # Parse key=value
        if [[ "${line}" =~ ^[[:space:]]*([a-z0-9_.]+)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"

            # Remove quotes if present
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"

            if config::set "${key}" "${value}"; then
                UTIL_CONFIG_SOURCE[${key}]="file:${file}"
                ((count++))
            else
                warn "Line ${line_num}: Failed to set '${key}' = '${value}'"
            fi
        else
            warn "Line ${line_num}: Invalid format: ${line}"
        fi
    done < "${file}"

    pass "Loaded ${count} settings from ${file}"
    return "${PASS}"
}

###############################################################################
# config::load_from_files
#------------------------------------------------------------------------------
# Purpose  : Load configuration from standard locations
# Usage    : config::load_from_files
# Returns  : PASS always
###############################################################################
function config::load_from_files() {
    local file

    for file in "${UTIL_CONFIG_PATHS[@]}"; do
        [[ -z "${file}" ]] && continue
        config::load_from_file "${file}" || continue
        # Stop after first successful load
        break
    done

    return "${PASS}"
}

###############################################################################
# config::save_to_file
#------------------------------------------------------------------------------
# Purpose  : Save current configuration to a file
# Usage    : config::save_to_file <path>
# Arguments:
#   $1 : Configuration file path
# Returns  : PASS if saved, FAIL otherwise
###############################################################################
function config::save_to_file() {
    local file="${1:-}"

    if [[ -z "${file}" ]]; then
        error "config::save_to_file: file path required"
        return "${FAIL}"
    fi

    info "Saving configuration to: ${file}"

    # Create directory if needed
    local dir
    dir=$(dirname "${file}")
    if [[ ! -d "${dir}" ]]; then
        mkdir -p "${dir}" || {
            error "Failed to create directory: ${dir}"
            return "${FAIL}"
        }
    fi

    {
        printf "# Utility Library Configuration\n"
        printf "# Generated: %s\n\n" "$(date)"

        local key value source
        for key in $(printf '%s\n' "${!UTIL_CONFIG[@]}" | sort); do
            # Skip internal keys
            [[ "${key}" == _* ]] && continue

            value="${UTIL_CONFIG[${key}]}"
            source="${UTIL_CONFIG_SOURCE[${key}]:-unknown}"

            # Get description from metadata
            local meta="${UTIL_CONFIG_META[${key}]:-}"
            if [[ -n "${meta}" ]]; then
                local description
                IFS='|' read -r _ description _ <<< "${meta}"
                printf "# %s\n" "${description}"
                printf "# Source: %s\n" "${source}"
            fi

            printf "%s=%s\n\n" "${key}" "${value}"
        done
    } > "${file}"

    pass "Saved configuration to ${file}"
    return "${PASS}"
}

#===============================================================================
# Configuration Inspection
#===============================================================================

###############################################################################
# config::list
#------------------------------------------------------------------------------
# Purpose  : List all configuration keys and values
# Usage    : config::list [pattern]
# Arguments:
#   $1 : Optional grep pattern to filter keys
# Returns  : PASS always
###############################################################################
function config::list() {
    local pattern="${1:-}"
    local key value source locked

    printf "%-30s %-20s %-15s %s\n" "KEY" "VALUE" "SOURCE" "LOCKED"
    printf "%s\n" "$(printf '=%.0s' {1..80})"

    for key in $(printf '%s\n' "${!UTIL_CONFIG[@]}" | sort); do
        # Skip internal keys
        [[ "${key}" == _* ]] && continue

        # Apply pattern filter
        if [[ -n "${pattern}" ]] && ! [[ "${key}" =~ ${pattern} ]]; then
            continue
        fi

        value="${UTIL_CONFIG[${key}]}"
        source="${UTIL_CONFIG_SOURCE[${key}]:-unknown}"
        locked="${UTIL_CONFIG_LOCKED[${key}]:-false}"

        # Truncate long values
        if [[ ${#value} -gt 20 ]]; then
            value="${value:0:17}..."
        fi

        printf "%-30s %-20s %-15s %s\n" "${key}" "${value}" "${source}" "${locked}"
    done

    return "${PASS}"
}

###############################################################################
# config::show
#------------------------------------------------------------------------------
# Purpose  : Show detailed information about a configuration key
# Usage    : config::show <key>
# Arguments:
#   $1 : Configuration key
# Returns  : PASS if key exists, FAIL otherwise
###############################################################################
function config::show() {
    local key="${1:-}"

    if [[ -z "${key}" ]]; then
        error "config::show: key required"
        return "${FAIL}"
    fi

    if [[ -z "${UTIL_CONFIG[${key}]:-}" ]]; then
        error "config::show: key not found: ${key}"
        return "${FAIL}"
    fi

    local meta="${UTIL_CONFIG_META[${key}]:-}"
    local type description validation

    if [[ -n "${meta}" ]]; then
        IFS='|' read -r type description validation <<< "${meta}"
    fi

    printf "Configuration: %s\n" "${key}"
    printf "  Value:       %s\n" "${UTIL_CONFIG[${key}]}"
    printf "  Default:     %s\n" "${UTIL_CONFIG_DEFAULTS[${key}]:-N/A}"
    printf "  Type:        %s\n" "${type:-unknown}"
    printf "  Source:      %s\n" "${UTIL_CONFIG_SOURCE[${key}]:-unknown}"
    printf "  Locked:      %s\n" "${UTIL_CONFIG_LOCKED[${key}]:-false}"
    [[ -n "${description}" ]] && printf "  Description: %s\n" "${description}"
    [[ -n "${validation}" ]] && printf "  Validation:  %s\n" "${validation}"

    return "${PASS}"
}

###############################################################################
# config::count
#------------------------------------------------------------------------------
# Purpose  : Count number of registered configuration keys
# Usage    : count=$(config::count)
# Returns  : PASS always
# Outputs  : Number of keys
###############################################################################
function config::count() {
    local count=0
    local key

    for key in "${!UTIL_CONFIG[@]}"; do
        [[ "${key}" != _* ]] && ((count++))
    done

    printf '%s\n' "${count}"
    return "${PASS}"
}

#===============================================================================
# Configuration Export
#===============================================================================

###############################################################################
# config::export_env
#------------------------------------------------------------------------------
# Purpose  : Export configuration as environment variables
# Usage    : eval "$(config::export_env)"
# Returns  : PASS always
# Outputs  : Export statements
###############################################################################
function config::export_env() {
    local key value env_var

    for key in "${!UTIL_CONFIG[@]}"; do
        [[ "${key}" == _* ]] && continue

        value="${UTIL_CONFIG[${key}]}"
        env_var="UTIL_CONFIG_$(echo "${key}" | tr '[:lower:].' '[:upper:]_')"

        printf "export %s=%q\n" "${env_var}" "${value}"
    done

    return "${PASS}"
}

###############################################################################
# config::export_json
#------------------------------------------------------------------------------
# Purpose  : Export configuration as JSON
# Usage    : config::export_json > config.json
# Returns  : PASS always
# Outputs  : JSON object
###############################################################################
function config::export_json() {
    local key value first=true

    printf "{\n"

    for key in $(printf '%s\n' "${!UTIL_CONFIG[@]}" | sort); do
        [[ "${key}" == _* ]] && continue

        value="${UTIL_CONFIG[${key}]}"

        [[ "${first}" == "false" ]] && printf ",\n"
        printf "  \"%s\": \"%s\"" "${key}" "${value}"
        first=false
    done

    printf "\n}\n"
    return "${PASS}"
}

#===============================================================================
# Self-Test
#===============================================================================

###############################################################################
# config::self_test
#------------------------------------------------------------------------------
# Purpose  : Test configuration system
# Usage    : config::self_test
# Returns  : PASS if all tests pass, FAIL otherwise
###############################################################################
function config::self_test() {
    info "Running config::self_test..."

    local status="${PASS}"

    # Test 1: Initialization
    if ! config::init; then
        fail "Initialization failed"
        return "${FAIL}"
    fi
    pass "Initialization successful"

    # Test 2: Get/Set
    config::set "test.key" "test_value"
    local value
    value=$(config::get "test.key")
    if [[ "${value}" != "test_value" ]]; then
        fail "Get/Set failed: expected 'test_value', got '${value}'"
        status="${FAIL}"
    else
        pass "Get/Set works"
    fi

    # Test 3: Validation
    config::register "test.int" "42" "int" "Test integer" "^[0-9]+$"
    if config::set "test.int" "invalid"; then
        fail "Validation should have failed for non-integer"
        status="${FAIL}"
    else
        pass "Validation works"
    fi

    # Test 4: Lock/Unlock
    config::lock "test.key"
    if config::set "test.key" "new_value"; then
        fail "Should not be able to set locked key"
        status="${FAIL}"
    else
        pass "Lock works"
    fi

    config::unlock "test.key"
    if ! config::set "test.key" "new_value"; then
        fail "Should be able to set unlocked key"
        status="${FAIL}"
    else
        pass "Unlock works"
    fi

    # Test 5: Boolean getter
    config::register "test.bool" "true" "bool" "Test boolean"
    if ! config::get_bool "test.bool"; then
        fail "Boolean getter failed"
        status="${FAIL}"
    else
        pass "Boolean getter works"
    fi

    if [[ ${status} -eq "${PASS}" ]]; then
        pass "config::self_test completed successfully"
    else
        fail "config::self_test encountered failures"
    fi

    return "${status}"
}

# Auto-initialize on load
config::init
