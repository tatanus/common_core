#!/usr/bin/env bash
###############################################################################
# NAME         : util_curl.sh
# DESCRIPTION  : HTTP/HTTPS operations and file transfers using curl.
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-10-27
###############################################################################
# EDIT HISTORY:
# DATE       | EDITED BY       | DESCRIPTION
# -----------|-----------------|-----------------------------------------------
# 2025-10-27 | Adam Compton    | Initial generation (style-guide compliant)
# 2025-10-29 | Adam Compton    | Added PROXY + tui::show_spinner integration
# 2025-11-20 | Adam Compton    | Updated to return response bodies by default,
#            |                 | added temp-file exec helper and self-test
# 2025-12-27 | Adam Compton    | Refactored to use array-based tui::show_spinner
# 2026-01-03 | Adam Compton    | CRITICAL: Fixed PROXY word-splitting vuln,
#            |                 | added URL protocol validation, proxy format
#            |                 | validation. Added -- separators.
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Library Guard
#===============================================================================
if [[ -n "${UTIL_CURL_SH_LOADED:-}" ]]; then
    if (return 0 2> /dev/null); then
        return 0
    fi
else
    UTIL_CURL_SH_LOADED=1
fi

#===============================================================================
# Module Dependencies
#===============================================================================
if [[ "${UTIL_PLATFORM_SH_LOADED:-0}" -eq 0 ]]; then
    echo "ERROR: util_platform.sh must be loaded before util_curl.sh" >&2
    return 1
fi

if [[ "${UTIL_CONFIG_SH_LOADED:-0}" -eq 0 ]]; then
    echo "ERROR: util_config.sh must be loaded before util_curl.sh" >&2
    return 1
fi

if [[ "${UTIL_TRAP_SH_LOADED:-0}" -eq 0 ]]; then
    echo "ERROR: util_trap.sh must be loaded before util_curl.sh" >&2
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
# Global Constants
#===============================================================================
: "${PASS:=0}"
: "${FAIL:=1}"

###############################################################################
# _curl_get_config
#------------------------------------------------------------------------------
# Purpose  : Load and cache curl configuration values from config system
# Usage    : _curl_get_config (called automatically on module load)
# Returns  : PASS (0) always
# Globals  : Sets CURL_TIMEOUT, CURL_MAX_REDIRECTS, CURL_USER_AGENT,
#            CURL_MAX_RETRIES, CURL_RETRY_DELAY as readonly
###############################################################################
function _curl_get_config() {
    # Cache config values for performance
    if [[ -z "${_CURL_CONFIG_LOADED:-}" ]]; then
        CURL_TIMEOUT=$(config::get_int "curl.timeout" 30)
        CURL_MAX_REDIRECTS=$(config::get_int "curl.max_redirects" 10)
        CURL_USER_AGENT=$(config::get "curl.user_agent" "util-bash/1.0")
        CURL_MAX_RETRIES=$(config::get_int "curl.max_retries" 3)
        CURL_RETRY_DELAY=$(config::get_int "curl.retry_delay" 2)

        readonly CURL_TIMEOUT CURL_MAX_REDIRECTS CURL_USER_AGENT \
            CURL_MAX_RETRIES CURL_RETRY_DELAY
        _CURL_CONFIG_LOADED=1
    fi
}

_curl_get_config

#===============================================================================
# Security Validation Functions (SECURITY FIX 2026-01-03)
#===============================================================================

###############################################################################
# _curl_validate_proxy
#------------------------------------------------------------------------------
# Purpose  : Validate PROXY environment variable format
# Usage    : _curl_validate_proxy
# Returns  : PASS if valid or empty, FAIL if invalid format
# Security : Prevents command injection via malformed PROXY values
###############################################################################
function _curl_validate_proxy() {
    local proxy="${PROXY:-}"

    # Empty proxy is valid (no proxy)
    if [[ -z "${proxy}" ]]; then
        return "${PASS}"
    fi

    # Validate proxy format: protocol://host[:port] or user:pass@host[:port]
    # Allowed protocols: http, https, socks4, socks5, socks4a, socks5h
    local proxy_regex='^(https?|socks[45][ah]?)://[a-zA-Z0-9.:@_-]+(:[0-9]{1,5})?(/)?$'

    if ! [[ "${proxy}" =~ ${proxy_regex} ]]; then
        error "_curl_validate_proxy: Invalid PROXY format: ${proxy}"
        error "Expected: protocol://host[:port] (e.g., http://proxy.example.com:8080)"
        return "${FAIL}"
    fi

    # Validate port range if present
    if [[ "${proxy}" =~ :([0-9]+)/?$ ]]; then
        local port="${BASH_REMATCH[1]}"
        if [[ ${port} -lt 1 || ${port} -gt 65535 ]]; then
            error "_curl_validate_proxy: Invalid port number: ${port}"
            return "${FAIL}"
        fi
    fi

    debug "_curl_validate_proxy: Valid proxy: ${proxy}"
    return "${PASS}"
}

###############################################################################
# _curl_validate_url
#------------------------------------------------------------------------------
# Purpose  : Validate URL format and protocol safety
# Usage    : _curl_validate_url "https://example.com/path"
# Arguments:
#   $1 : URL to validate
# Returns  : PASS if valid and safe, FAIL otherwise
# Security : Rejects dangerous protocols (file://, dict://, gopher://, etc.)
###############################################################################
function _curl_validate_url() {
    local url="${1:-}"

    if [[ -z "${url}" ]]; then
        error "_curl_validate_url: URL required"
        return "${FAIL}"
    fi

    # SECURITY: Only allow http and https protocols
    if ! [[ "${url}" =~ ^https?:// ]]; then
        error "_curl_validate_url: Only http:// and https:// URLs allowed"
        error "Rejected URL: ${url}"
        return "${FAIL}"
    fi

    # SECURITY: Check for embedded credentials abuse or unusual patterns
    # Block URLs with null bytes or control characters
    if [[ "${url}" =~ [[:cntrl:]] ]]; then
        error "_curl_validate_url: URL contains control characters"
        return "${FAIL}"
    fi

    debug "_curl_validate_url: Valid URL: ${url}"
    return "${PASS}"
}

###############################################################################
# _curl_build_proxy_args
#------------------------------------------------------------------------------
# Purpose  : Safely build proxy arguments for curl command array
# Usage    : _curl_build_proxy_args cmd_array_name
# Arguments:
#   $1 : Name of array variable to append to
# Returns  : PASS always (adds --proxy arg if PROXY is valid)
# Security : Validates PROXY before use, adds as single --proxy argument
###############################################################################
function _curl_build_proxy_args() {
    local -n _cmd_ref="${1}"

    if [[ -n "${PROXY:-}" ]]; then
        if _curl_validate_proxy; then
            # SECURITY FIX: Use --proxy with validated PROXY as single argument
            # This prevents word-splitting attacks
            _cmd_ref+=(--proxy "${PROXY}")
        else
            warn "_curl_build_proxy_args: Invalid PROXY format ignored"
        fi
    fi

    return "${PASS}"
}

###############################################################################
# _curl_exec_body
#------------------------------------------------------------------------------
# Purpose  : Execute curl command and return response body to stdout
# Usage    : _curl_exec_body "description" [curl_args...]
# Arguments:
#   $1 : Description for logging
#   $@ : Additional curl arguments
# Returns  : PASS (0) with body on stdout, FAIL (1) on error
# Requires:
#   Functions: tui::show_spinner, trap::with_cleanup, platform::mktemp
#   Globals: PROXY, CURL_TIMEOUT, CURL_MAX_REDIRECTS, CURL_USER_AGENT
###############################################################################
function _curl_exec_body() {
    local description="${1:-curl operation}"
    shift

    # Use trap utility - automatically registers for cleanup
    local tmp
    if ! tmp=$(trap::with_cleanup platform::mktemp "/tmp/curl_body.XXXXXX"); then
        fail "_curl_exec_body: Failed to create temporary file for curl output."
        return "${FAIL}"
    fi

    info "${description}..."

    # SECURITY FIX: Build command array safely - no word splitting on PROXY
    local -a cmd=(curl)
    _curl_build_proxy_args cmd
    cmd+=(--max-time "${CURL_TIMEOUT}" --max-redirs "${CURL_MAX_REDIRECTS}" -A "${CURL_USER_AGENT}" "$@" -o "${tmp}")

    # Run with spinner
    if tui::show_spinner -- "${cmd[@]}" 2> /dev/null; then
        debug "curl command succeeded: ${cmd[*]}"
        cat -- "${tmp}"
        return "${PASS}"
    fi

    debug "curl command failed: ${cmd[*]}"
    return "${FAIL}"
}

###############################################################################
# _curl_exec_file
#------------------------------------------------------------------------------
# Purpose  : Execute a curl operation that writes directly to a file via -o.
# Usage    : _curl_exec_file "Downloading file" "/tmp/file" -fsSL "https://example.com"
# Arguments:
#   $1 : Description for logging (required)
#   $2 : Destination file path (required)
#   $@ : Additional curl arguments
# Returns  : PASS (0) on success, FAIL (1) on failure
# Requires:
#   Functions: tui::show_spinner, info, debug
#   Globals: PROXY
###############################################################################
function _curl_exec_file() {
    local description="${1:-curl file operation}"
    local dest="${2:-}"
    shift 2

    if [[ -z "${dest}" ]]; then
        fail "_curl_exec_file requires a destination file path"
        return "${FAIL}"
    fi

    info "${description}..."

    # SECURITY FIX: Build command array safely - no word splitting on PROXY
    local -a cmd=(curl)
    _curl_build_proxy_args cmd
    cmd+=(-o "${dest}" "$@")

    # Run with spinner
    if tui::show_spinner -- "${cmd[@]}" > /dev/null 2>&1; then
        debug "curl file command succeeded: ${cmd[*]}"
        return "${PASS}"
    fi

    debug "curl file command failed: ${cmd[*]}"
    return "${FAIL}"
}

#===============================================================================
# Availability
#===============================================================================

###############################################################################
# curl::is_available
#------------------------------------------------------------------------------
# Check if curl is available on the system.
#--------------------
# Usage:
#   if curl::is_available; then ...
#
# Return Values:
#   PASS (0) if curl is available
#   FAIL (1) otherwise
#--------------------
# Requirements:
#   Functions:
#     - cmd::exists
#     - debug
###############################################################################
function curl::is_available() {
    if cmd::exists curl; then
        debug "curl available at $(command -v curl)"
        return "${PASS}"
    fi

    debug "curl not available"
    return "${FAIL}"
}

#===============================================================================
# Basic HTTP Methods (return response body)
#===============================================================================

###############################################################################
# curl::get
#------------------------------------------------------------------------------
# Perform an HTTP GET request and return the response body.
#--------------------
# Usage:
#   body=$(curl::get "https://example.com")
#
# Return Values:
#   PASS (0) on success (body printed to stdout)
#   FAIL (1) on failure
#--------------------
# Requirements:
#   Functions:
#     - curl::is_available
#     - _curl_exec_body
#     - info, pass, fail, error
#
#   Environment:
#     - PROXY
###############################################################################
function curl::get() {
    local url="${1:-}"

    if [[ -z "${url}" ]]; then
        error "curl::get requires a URL"
        return "${FAIL}"
    fi

    # SECURITY FIX: Validate URL protocol
    if ! _curl_validate_url "${url}"; then
        return "${FAIL}"
    fi

    if ! curl::is_available; then
        error "curl not installed"
        return "${FAIL}"
    fi

    info "GET ${url}"
    if _curl_exec_body "GET ${url}" -fsSL "${url}"; then
        pass "GET successful: ${url}"
        return "${PASS}"
    fi

    fail "GET failed: ${url}"
    return "${FAIL}"
}

###############################################################################
# curl::post
#------------------------------------------------------------------------------
# Perform an HTTP POST request and return the response body.
#--------------------
# Usage:
#   body=$(curl::post "https://example.com/api" "data=value")
#
# Return Values:
#   PASS (0) on success (body printed to stdout)
#   FAIL (1) on failure
#--------------------
# Requirements:
#   Functions:
#     - curl::is_available
#     - _curl_exec_body
#     - info, pass, fail, error
###############################################################################
function curl::post() {
    local url="${1:-}"
    local data="${2:-}"

    if [[ -z "${url}" ]]; then
        error "curl::post requires a URL"
        return "${FAIL}"
    fi

    # SECURITY FIX: Validate URL protocol
    if ! _curl_validate_url "${url}"; then
        return "${FAIL}"
    fi

    if ! curl::is_available; then
        error "curl not installed"
        return "${FAIL}"
    fi

    info "POST ${url}"
    if _curl_exec_body "POST ${url}" -fsSL -X POST -d "${data}" "${url}"; then
        pass "POST successful: ${url}"
        return "${PASS}"
    fi

    fail "POST failed: ${url}"
    return "${FAIL}"
}

###############################################################################
# curl::put
#------------------------------------------------------------------------------
# Perform an HTTP PUT request and return the response body.
#--------------------
# Usage:
#   body=$(curl::put "https://example.com/api/resource" "data=value")
#
# Return Values:
#   PASS (0) on success (body printed to stdout)
#   FAIL (1) on failure
#--------------------
# Requirements:
#   Functions:
#     - curl::is_available
#     - _curl_exec_body
#     - info, pass, fail, error
###############################################################################
function curl::put() {
    local url="${1:-}"
    local data="${2:-}"

    if [[ -z "${url}" ]]; then
        error "curl::put requires a URL"
        return "${FAIL}"
    fi

    # SECURITY FIX: Validate URL protocol
    if ! _curl_validate_url "${url}"; then
        return "${FAIL}"
    fi

    if ! curl::is_available; then
        error "curl not installed"
        return "${FAIL}"
    fi

    info "PUT ${url}"
    if _curl_exec_body "PUT ${url}" -fsSL -X PUT -d "${data}" "${url}"; then
        pass "PUT successful: ${url}"
        return "${PASS}"
    fi

    fail "PUT failed: ${url}"
    return "${FAIL}"
}

###############################################################################
# curl::delete
#------------------------------------------------------------------------------
# Perform an HTTP DELETE request and return the response body.
#--------------------
# Usage:
#   body=$(curl::delete "https://example.com/api/resource")
#
# Return Values:
#   PASS (0) on success (body printed to stdout)
#   FAIL (1) on failure
#--------------------
# Requirements:
#   Functions:
#     - curl::is_available
#     - _curl_exec_body
#     - info, pass, fail, error
###############################################################################
function curl::delete() {
    local url="${1:-}"

    if [[ -z "${url}" ]]; then
        error "curl::delete requires a URL"
        return "${FAIL}"
    fi

    # SECURITY FIX: Validate URL protocol
    if ! _curl_validate_url "${url}"; then
        return "${FAIL}"
    fi

    if ! curl::is_available; then
        error "curl not installed"
        return "${FAIL}"
    fi

    info "DELETE ${url}"
    if _curl_exec_body "DELETE ${url}" -fsSL -X DELETE "${url}"; then
        pass "DELETE successful: ${url}"
        return "${PASS}"
    fi

    fail "DELETE failed: ${url}"
    return "${FAIL}"
}

#===============================================================================
# File Transfers
#===============================================================================

###############################################################################
# curl::download
#------------------------------------------------------------------------------
# Download a file from a URL to a destination path. Does not print body.
#--------------------
# Usage:
#   curl::download "https://example.com/file" "/tmp/file"
#
# Return Values:
#   PASS (0) if download succeeds
#   FAIL (1) on failure
#--------------------
# Requirements:
#   Functions:
#     - curl::is_available
#     - _curl_exec_file
#     - info, pass, fail, error
###############################################################################
function curl::download() {
    local url="${1:-}"
    local dest="${2:-}"

    if [[ -z "${url}" || -z "${dest}" ]]; then
        error "Usage: curl::download <url> <dest>"
        return "${FAIL}"
    fi

    # SECURITY FIX: Validate URL protocol
    if ! _curl_validate_url "${url}"; then
        return "${FAIL}"
    fi

    if ! curl::is_available; then
        error "curl not installed"
        return "${FAIL}"
    fi

    info "Downloading ${url} -> ${dest}"
    if _curl_exec_file "Downloading file" "${dest}" -fsSL "${url}"; then
        pass "Downloaded: ${dest}"
        return "${PASS}"
    fi

    fail "Download failed: ${url}"
    return "${FAIL}"
}

###############################################################################
# curl::upload
#------------------------------------------------------------------------------
# Upload a file via multipart/form-data POST. Returns server response body.
#--------------------
# Usage:
#   body=$(curl::upload "https://example.com/upload" "/path/to/file")
#
# Return Values:
#   PASS (0) if upload succeeds (body printed to stdout)
#   FAIL (1) on failure
#--------------------
# Requirements:
#   Functions:
#     - curl::is_available
#     - file::exists
#     - _curl_exec_body
#     - info, pass, fail, error
###############################################################################
function curl::upload() {
    local url="${1:-}"
    local file="${2:-}"

    if [[ -z "${url}" || -z "${file}" ]]; then
        error "Usage: curl::upload <url> <file>"
        return "${FAIL}"
    fi

    # SECURITY FIX: Validate URL protocol
    if ! _curl_validate_url "${url}"; then
        return "${FAIL}"
    fi

    if ! curl::is_available; then
        error "curl not installed"
        return "${FAIL}"
    fi
    if ! file::exists "${file}"; then
        error "File not found: ${file}"
        return "${FAIL}"
    fi

    info "Uploading ${file} -> ${url}"
    if _curl_exec_body "Uploading file" -fsSL -X POST -F "file=@${file}" "${url}"; then
        pass "Upload successful: ${file}"
        return "${PASS}"
    fi

    fail "Upload failed: ${file}"
    return "${FAIL}"
}

#===============================================================================
# Network Validation and Metadata
#===============================================================================

###############################################################################
# curl::check_url
#------------------------------------------------------------------------------
# Check whether a URL is reachable using a HEAD request.
#--------------------
# Usage:
#   if curl::check_url "https://example.com"; then ...
#
# Return Values:
#   PASS (0) if reachable (2xx/3xx)
#   FAIL (1) otherwise
#--------------------
# Requirements:
#   Functions:
#     - curl::is_available
#     - debug, error
#
#   Environment:
#     - PROXY
###############################################################################
function curl::check_url() {
    local url="${1:-}"

    if [[ -z "${url}" ]]; then
        error "curl::check_url requires a URL"
        return "${FAIL}"
    fi

    # SECURITY FIX: Validate URL protocol
    if ! _curl_validate_url "${url}"; then
        return "${FAIL}"
    fi

    if ! curl::is_available; then
        error "curl not installed"
        return "${FAIL}"
    fi

    # SECURITY FIX: Build proxy args safely
    local -a cmd=(curl -fsI)
    _curl_build_proxy_args cmd
    cmd+=("${url}")

    if "${cmd[@]}" > /dev/null 2>&1; then
        debug "URL reachable: ${url}"
        return "${PASS}"
    fi

    debug "URL unreachable: ${url}"
    return "${FAIL}"
}

###############################################################################
# curl::get_status_code
#------------------------------------------------------------------------------
# Retrieve the HTTP status code for a URL.
#--------------------
# Usage:
#   code=$(curl::get_status_code "https://example.com")
#
# Return Values:
#   PASS (0) if curl invocation succeeds (code printed)
#   FAIL (1) if curl fails
#--------------------
# Requirements:
#   Functions:
#     - curl::is_available
#     - error
#
#   Environment:
#     - PROXY
###############################################################################
function curl::get_status_code() {
    local url="${1:-}"

    if [[ -z "${url}" ]]; then
        error "curl::get_status_code requires a URL"
        return "${FAIL}"
    fi

    # SECURITY FIX: Validate URL protocol
    if ! _curl_validate_url "${url}"; then
        printf '%s\n' "000"
        return "${FAIL}"
    fi

    if ! curl::is_available; then
        error "curl not installed"
        return "${FAIL}"
    fi

    # SECURITY FIX: Build proxy args safely
    local -a cmd=(curl -s -o /dev/null -w "%{http_code}")
    _curl_build_proxy_args cmd
    cmd+=("${url}")

    local code
    code=$("${cmd[@]}" || true)
    printf '%s\n' "${code:-000}"

    # Treat 2xx as success
    [[ "${code}" =~ ^2 ]] && return "${PASS}" || return "${FAIL}"
}

###############################################################################
# curl::follow_redirects
#------------------------------------------------------------------------------
# Follow HTTP redirects and print the final resolved URL.
#--------------------
# Usage:
#   final=$(curl::follow_redirects "http://example.com")
#
# Return Values:
#   PASS (0) if final URL is non-empty
#   FAIL (1) otherwise
#--------------------
# Requirements:
#   Functions:
#     - curl::is_available
#     - error
#
#   Environment:
#     - PROXY
###############################################################################
function curl::follow_redirects() {
    local url="${1:-}"

    if [[ -z "${url}" ]]; then
        error "curl::follow_redirects requires a URL"
        return "${FAIL}"
    fi

    # SECURITY FIX: Validate URL protocol
    if ! _curl_validate_url "${url}"; then
        return "${FAIL}"
    fi

    if ! curl::is_available; then
        error "curl not installed"
        return "${FAIL}"
    fi

    # SECURITY FIX: Build proxy args safely
    local -a cmd=(curl -Ls -o /dev/null -w "%{url_effective}")
    _curl_build_proxy_args cmd
    cmd+=("${url}")

    local final
    final=$("${cmd[@]}" || true)
    printf '%s\n' "${final}"

    [[ -n "${final}" ]] && return "${PASS}" || return "${FAIL}"
}

###############################################################################
# curl::with_auth
#------------------------------------------------------------------------------
# Perform an HTTP GET request with basic authentication and return the body.
#--------------------
# Usage:
#   body=$(curl::with_auth "https://api.example.com" "user" "pass")
#
# Return Values:
#   PASS (0) on success (body printed to stdout)
#   FAIL (1) on failure
#--------------------
# Requirements:
#   Functions:
#     - curl::is_available
#     - _curl_exec_body
#     - info, pass, fail, error
###############################################################################
function curl::with_auth() {
    local url="${1:-}"
    local user="${2:-}"
    local pass="${3:-}"

    if [[ -z "${url}" || -z "${user}" || -z "${pass}" ]]; then
        error "Usage: curl::with_auth <url> <user> <pass>"
        return "${FAIL}"
    fi

    # SECURITY FIX: Validate URL protocol
    if ! _curl_validate_url "${url}"; then
        return "${FAIL}"
    fi

    if ! curl::is_available; then
        error "curl not installed"
        return "${FAIL}"
    fi

    info "Requesting ${url} with basic authentication"
    if _curl_exec_body "Authenticated request ${url}" -fsSL -u "${user}:${pass}" "${url}"; then
        pass "Authenticated request successful: ${url}"
        return "${PASS}"
    fi

    fail "Authenticated request failed: ${url}"
    return "${FAIL}"
}

###############################################################################
# curl::with_headers
#------------------------------------------------------------------------------
# Perform an HTTP GET request with custom headers and return the body.
#--------------------
# Usage:
#   body=$(curl::with_headers "https://example.com" "Header1: value1" "Header2: v2")
#
# Return Values:
#   PASS (0) on success (body printed to stdout)
#   FAIL (1) on failure
#--------------------
# Requirements:
#   Functions:
#     - curl::is_available
#     - _curl_exec_body
#     - info, pass, fail, error
###############################################################################
function curl::with_headers() {
    local url="${1:-}"
    shift || true

    if [[ -z "${url}" ]]; then
        error "curl::with_headers requires a URL"
        return "${FAIL}"
    fi

    # SECURITY FIX: Validate URL protocol
    if ! _curl_validate_url "${url}"; then
        return "${FAIL}"
    fi

    if ! curl::is_available; then
        error "curl not installed"
        return "${FAIL}"
    fi

    local -a headers=()
    local h
    for h in "$@"; do
        headers+=(-H "${h}")
    done

    info "Requesting ${url} with custom headers"
    if _curl_exec_body "Request with headers ${url}" -fsSL "${headers[@]}" "${url}"; then
        pass "Request with headers succeeded: ${url}"
        return "${PASS}"
    fi

    fail "Request with headers failed: ${url}"
    return "${FAIL}"
}

###############################################################################
# curl::get_response_time
#------------------------------------------------------------------------------
# Measure total response time for a URL in seconds.
#--------------------
# Usage:
#   t=$(curl::get_response_time "https://example.com")
#
# Return Values:
#   PASS (0) always; prints time (e.g. 0.123) to stdout
#--------------------
# Requirements:
#   Functions:
#     - curl::is_available
#     - error
#
#   Environment:
#     - PROXY
###############################################################################
function curl::get_response_time() {
    local url="${1:-}"

    if [[ -z "${url}" ]]; then
        error "curl::get_response_time requires a URL"
        return "${FAIL}"
    fi

    # SECURITY FIX: Validate URL protocol
    if ! _curl_validate_url "${url}"; then
        printf '%s\n' "0.000"
        return "${FAIL}"
    fi

    if ! curl::is_available; then
        error "curl not installed"
        return "${FAIL}"
    fi

    # SECURITY FIX: Build proxy args safely
    local -a cmd=(curl -o /dev/null -s -w "%{time_total}")
    _curl_build_proxy_args cmd
    cmd+=("${url}")

    local time
    time=$("${cmd[@]}" || echo "0.000")
    printf '%s\n' "${time}"
    return "${PASS}"
}

###############################################################################
# curl::get_with_retry
#------------------------------------------------------------------------------
# Purpose  : Perform HTTP GET with automatic retry on failure
# Usage    : body=$(curl::get_with_retry "https://example.com" [attempts] [delay])
# Arguments:
#   $1 : URL (required)
#   $2 : Number of retry attempts (optional, default: 3)
#   $3 : Delay between retries in seconds (optional, default: 2)
# Returns  : PASS (0) on success (body printed to stdout), FAIL (1) on failure
###############################################################################
function curl::get_with_retry() {
    local url="${1:-}"
    local attempts="${2:-$(config::get_int "curl.max_retries" 3)}"
    local delay="${3:-$(config::get_int "curl.retry_delay" 2)}"

    if [[ -z "${url}" ]]; then
        error "curl::get_with_retry requires a URL"
        return "${FAIL}"
    fi

    # SECURITY FIX: Validate URL protocol (early validation before retries)
    if ! _curl_validate_url "${url}"; then
        return "${FAIL}"
    fi

    local attempt=1
    while [[ ${attempt} -le ${attempts} ]]; do
        if curl::get "${url}"; then
            return "${PASS}"
        fi

        if [[ ${attempt} -lt ${attempts} ]]; then
            warn "Attempt ${attempt}/${attempts} failed, retrying in ${delay}s..."
            sleep "${delay}"
        fi

        ((attempt++))
    done

    fail "Failed after ${attempts} attempts: ${url}"
    return "${FAIL}"
}

###############################################################################
# curl::get_headers
#------------------------------------------------------------------------------
# Purpose  : Retrieve HTTP response headers only
# Usage    : headers=$(curl::get_headers "https://example.com")
# Returns  : PASS (0) on success (headers printed), FAIL (1) otherwise
###############################################################################
function curl::get_headers() {
    local url="${1:-}"

    if [[ -z "${url}" ]]; then
        error "curl::get_headers requires a URL"
        return "${FAIL}"
    fi

    # SECURITY FIX: Validate URL protocol
    if ! _curl_validate_url "${url}"; then
        return "${FAIL}"
    fi

    if ! curl::is_available; then
        error "curl not installed"
        return "${FAIL}"
    fi

    # SECURITY FIX: Build proxy args safely
    local -a cmd=(curl -sI --max-time "${CURL_TIMEOUT}" -A "${CURL_USER_AGENT}")
    _curl_build_proxy_args cmd
    cmd+=("${url}")

    if "${cmd[@]}"; then
        return "${PASS}"
    fi

    return "${FAIL}"
}

#===============================================================================
# Self-Test
#===============================================================================

###############################################################################
# curl::self_test
#------------------------------------------------------------------------------
# Run basic self-tests for util_curl.sh.
#--------------------
# Usage:
#   curl::self_test
#
# Return Values:
#   PASS (0) if basic checks pass
#   FAIL (1) if curl is missing
#--------------------
# Requirements:
#   Functions:
#     - curl::is_available
#     - curl::get_status_code
#     - info, warn, pass, fail
###############################################################################
function curl::self_test() {
    info "Running util_curl.sh self-test..."

    local status="${PASS}"

    if ! curl::is_available; then
        fail "curl not available on this system"
        return "${FAIL}"
    fi
    pass "curl is available"

    # Test: URL validation rejects dangerous protocols
    if _curl_validate_url "file:///etc/passwd" 2> /dev/null; then
        fail "SECURITY: URL validation accepted file:// protocol"
        status="${FAIL}"
    else
        pass "SECURITY: URL validation rejects file:// protocol"
    fi

    if _curl_validate_url "gopher://example.com" 2> /dev/null; then
        fail "SECURITY: URL validation accepted gopher:// protocol"
        status="${FAIL}"
    else
        pass "SECURITY: URL validation rejects gopher:// protocol"
    fi

    # Test: PROXY validation
    if PROXY="invalid proxy format" _curl_validate_proxy 2> /dev/null; then
        fail "SECURITY: Proxy validation accepted invalid format"
        status="${FAIL}"
    else
        pass "SECURITY: Proxy validation rejects invalid format"
    fi

    # Best-effort external check; do not hard-fail on network issues.
    local code
    code=$(curl::get_status_code "https://example.com" || echo "000")
    if [[ "${code}" == "000" ]]; then
        warn "Network or DNS may be unavailable; status check returned 000"
    else
        pass "Network check returned status: ${code}"
    fi

    if [[ "${status}" -eq "${PASS}" ]]; then
        pass "util_curl.sh self-test completed."
    else
        fail "util_curl.sh self-test completed with failures."
    fi

    return "${status}"
}
