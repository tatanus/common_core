#!/usr/bin/env bash
###############################################################################
# NAME         : util_ruby.sh
# DESCRIPTION  : Ruby environment, gem, and bundler management utilities.
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-10-27
###############################################################################
# EDIT HISTORY:
# DATE       | EDITED BY      | DESCRIPTION
# -----------|----------------|------------------------------------------------
# 2025-10-27 | Adam Compton   | Initial generation (style-guide compliant)
# 2025-12-27 | Adam Compton   | Refactored to use array-based tui::show_spinner
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Library Guard
#===============================================================================
if [[ -n "${UTIL_RUBY_SH_LOADED:-}" ]]; then
    if (return 0 2> /dev/null); then
        return 0
    fi
else
    UTIL_RUBY_SH_LOADED=1
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
# Globals
#===============================================================================
: "${PASS:=0}"
: "${FAIL:=1}"
# none

#===============================================================================
# Ruby Detection and Environment
#===============================================================================

###############################################################################
# ruby::is_available
#------------------------------------------------------------------------------
# Purpose  : Check if Ruby is installed.
# Usage    : ruby::is_available && info "Ruby detected"
# Returns  : PASS if installed, FAIL otherwise.
###############################################################################
function ruby::is_available() {
    if cmd::exists ruby; then
        debug "Ruby found at $(command -v ruby)"
        return "${PASS}"
    fi
    debug "Ruby not found"
    return "${FAIL}"
}

###############################################################################
# ruby::get_version
#------------------------------------------------------------------------------
# Purpose  : Get the current Ruby version.
# Usage    : ver=$(ruby::get_version)
# Returns  : Prints Ruby version string.
###############################################################################
function ruby::get_version() {
    if ! ruby::is_available; then
        error "Ruby not installed"
        return "${FAIL}"
    fi
    local version
    version=$(ruby -v 2> /dev/null | awk '{print $2}')
    printf '%s\n' "${version:-unknown}"
    return "${PASS}"
}

###############################################################################
# ruby::get_path
#------------------------------------------------------------------------------
# Purpose  : Get the path to the Ruby executable.
# Usage    : ruby::get_path
# Returns  : Prints Ruby path.
###############################################################################
function ruby::get_path() {
    local path
    path="$(command -v ruby 2> /dev/null || echo "/usr/bin/ruby")"
    printf '%s\n' "${path}"
    return "${PASS}"
}

###############################################################################
# ruby::rbenv_available
#------------------------------------------------------------------------------
# Purpose  : Check if rbenv is installed.
# Usage    : ruby::rbenv_available
# Returns  : PASS if installed, FAIL otherwise.
###############################################################################
function ruby::rbenv_available() {
    if cmd::exists rbenv; then
        debug "rbenv detected"
        return "${PASS}"
    fi
    debug "rbenv not found"
    return "${FAIL}"
}

###############################################################################
# ruby::rvm_available
#------------------------------------------------------------------------------
# Purpose  : Check if RVM is installed.
# Usage    : ruby::rvm_available
# Returns  : PASS if installed, FAIL otherwise.
###############################################################################
function ruby::rvm_available() {
    if cmd::exists rvm; then
        debug "RVM detected"
        return "${PASS}"
    fi
    debug "RVM not found"
    return "${FAIL}"
}

#===============================================================================
# Gem Management
#===============================================================================

###############################################################################
# ruby::gem_install
#------------------------------------------------------------------------------
# Purpose  : Install one or more gems globally.
# Usage    : ruby::gem_install "bundler" "rake"
# Returns  : PASS if successful, FAIL otherwise.
###############################################################################
function ruby::gem_install() {
    local gems=("$@")

    if [[ ${#gems[@]} -eq 0 ]]; then
        error "ruby::gem_install requires one or more gem names."
        return "${FAIL}"
    fi

    local gem overall_status="${PASS}"

    for gem in "${gems[@]}"; do
        info "Installing gem: ${gem}"

        # Use spinner with command array
        if tui::show_spinner -- gem install "${gem}" --no-document > /dev/null 2>&1; then
            pass "Successfully installed ${gem}."
        else
            fail "Failed to install ${gem}."
            overall_status="${FAIL}"
            continue
        fi

        # Verify installation
        if gem list -i "${gem}" > /dev/null 2>&1; then
            debug "Verified gem installation: ${gem}"
        else
            fail "Verification failed: ${gem} not detected after install."
            overall_status="${FAIL}"
        fi
    done

    return "${overall_status}"
}

###############################################################################
# ruby::gem_update
#------------------------------------------------------------------------------
# Purpose  : Update all installed gems.
# Usage    : ruby::gem_update
# Returns  : PASS if successful, FAIL otherwise.
###############################################################################
function ruby::gem_update() {
    info "Updating installed gems..."
    if cmd::run gem update; then
        pass "All gems updated successfully"
        return "${PASS}"
    fi
    fail "Gem update failed"
    return "${FAIL}"
}

###############################################################################
# ruby::install_rbenv
#------------------------------------------------------------------------------
# Purpose  : Install rbenv for Ruby version management
# Usage    : ruby::install_rbenv
# Returns  : PASS if successful, FAIL otherwise
###############################################################################
function ruby::install_rbenv() {
    if ruby::rbenv_available; then
        info "rbenv already installed"
        return "${PASS}"
    fi

    local rbenv_root="${HOME}/.rbenv"

    info "Installing rbenv..."
    if git::clone "https://github.com/rbenv/rbenv.git" "${rbenv_root}"; then
        # Install ruby-build plugin
        local plugin_dir="${rbenv_root}/plugins/ruby-build"
        if git::clone "https://github.com/rbenv/ruby-build.git" "${plugin_dir}"; then
            pass "rbenv installed successfully"
            info "Add to shell: export PATH=\"${rbenv_root}/bin:\$PATH\" && eval \"\$(rbenv init -)\""
            return "${PASS}"
        fi
    fi

    fail "rbenv installation failed"
    return "${FAIL}"
}

###############################################################################
# ruby::get_bundler_version
#------------------------------------------------------------------------------
# Purpose  : Get Bundler major version (1 or 2)
# Usage    : ver=$(ruby::get_bundler_version)
# Returns  : Prints major version
###############################################################################
function ruby::get_bundler_version() {
    if ! ruby::is_gem_installed "bundler"; then
        error "Bundler not installed"
        return "${FAIL}"
    fi

    local version
    version=$(bundle --version 2> /dev/null | awk '{print $3}' | cut -d. -f1)
    printf '%s\n' "${version:-unknown}"
    return "${PASS}"
}

###############################################################################
# ruby::gem_cleanup
#------------------------------------------------------------------------------
# Purpose  : Remove old gem versions
# Usage    : ruby::gem_cleanup
# Returns  : PASS if successful, FAIL otherwise
###############################################################################
function ruby::gem_cleanup() {
    info "Cleaning up old gem versions..."
    if cmd::run gem cleanup; then
        pass "Gem cleanup complete"
        return "${PASS}"
    fi

    fail "Gem cleanup failed"
    return "${FAIL}"
}

###############################################################################
# ruby::is_gem_installed
#------------------------------------------------------------------------------
# Purpose  : Check if a specific gem is installed.
# Usage    : ruby::is_gem_installed "bundler"
# Returns  : PASS if installed, FAIL otherwise.
###############################################################################
function ruby::is_gem_installed() {
    local gem_name="${1:-}"
    if [[ -z "${gem_name}" ]]; then
        error "ruby::is_gem_installed requires a gem name"
        return "${FAIL}"
    fi
    if gem list -i "${gem_name}" > /dev/null 2>&1; then
        debug "Gem installed: ${gem_name}"
        return "${PASS}"
    fi
    debug "Gem not installed: ${gem_name}"
    return "${FAIL}"
}

###############################################################################
# ruby::get_gem_version
#------------------------------------------------------------------------------
# Purpose  : Get the version of a specific installed gem.
# Usage    : ruby::get_gem_version "bundler"
# Returns  : Prints version or FAIL.
###############################################################################
function ruby::get_gem_version() {
    local gem_name="${1:-}"
    if [[ -z "${gem_name}" ]]; then
        error "ruby::get_gem_version requires a gem name"
        return "${FAIL}"
    fi
    local version
    version=$(gem list "${gem_name}" --no-versions | grep "${gem_name}" | awk '{print $2}' | tr -d '()')
    printf '%s\n' "${version:-unknown}"
    [[ -n "${version}" ]] && return "${PASS}" || return "${FAIL}"
}

#===============================================================================
# Bundler and Project Tools
#===============================================================================

###############################################################################
# ruby::bundler_install
#------------------------------------------------------------------------------
# Purpose  : Install Bundler if not already installed.
# Usage    : ruby::bundler_install
# Returns  : PASS if installed, FAIL otherwise.
###############################################################################
function ruby::bundler_install() {
    if ruby::is_gem_installed "bundler"; then
        debug "Bundler already installed"
        return "${PASS}"
    fi
    info "Installing Bundler..."
    if ruby::gem_install "bundler"; then
        pass "Bundler installed successfully"
        return "${PASS}"
    fi
    fail "Bundler installation failed"
    return "${FAIL}"
}

###############################################################################
# ruby::bundle_install
#------------------------------------------------------------------------------
# Purpose  : Install project dependencies via Bundler.
# Usage    : ruby::bundle_install
# Returns  : PASS if successful, FAIL otherwise.
###############################################################################
function ruby::bundle_install() {
    if ! cmd::exists bundle; then
        ruby::bundler_install || return "${FAIL}"
    fi
    info "Installing bundle dependencies..."
    if cmd::run bundle install; then
        pass "Dependencies installed via Bundler"
        return "${PASS}"
    fi
    fail "Bundle installation failed"
    return "${FAIL}"
}

###############################################################################
# ruby::run_script
#------------------------------------------------------------------------------
# Purpose  : Execute a Ruby script.
# Usage    : ruby::run_script "./script.rb"
# Returns  : PASS if successful, FAIL otherwise.
###############################################################################
function ruby::run_script() {
    local script="${1:-}"
    if [[ -z "${script}" ]]; then
        error "ruby::run_script requires a script path"
        return "${FAIL}"
    fi
    if ! file::exists "${script}"; then
        error "Ruby script not found: ${script}"
        return "${FAIL}"
    fi
    info "Running Ruby script: ${script}"
    if cmd::run ruby "${script}"; then
        pass "Ruby script executed successfully"
        return "${PASS}"
    fi
    fail "Ruby script execution failed"
    return "${FAIL}"
}

###############################################################################
# ruby::self_test
#------------------------------------------------------------------------------
# Purpose  : Self-test for util_ruby.sh functionality
# Usage    : ruby::self_test
# Returns  : PASS (0) if all tests pass, FAIL (1) otherwise
# Globals  : None
###############################################################################
function ruby::self_test() {
    info "Running util_ruby.sh self-test..."

    local status="${PASS}"

    # Test 1: Check if Ruby detection works
    if ! declare -F ruby::is_available > /dev/null 2>&1; then
        fail "ruby::is_available function not available"
        status="${FAIL}"
    fi

    # Test 2: If Ruby is available, test version retrieval
    if ruby::is_available; then
        if ! ruby::get_version > /dev/null 2>&1; then
            fail "ruby::get_version failed"
            status="${FAIL}"
        fi

        if ! ruby::get_path > /dev/null 2>&1; then
            fail "ruby::get_path failed"
            status="${FAIL}"
        fi
    else
        info "Ruby not available - skipping version tests"
    fi

    if [[ "${status}" -eq "${PASS}" ]]; then
        pass "util_ruby.sh self-test passed"
    else
        fail "util_ruby.sh self-test failed"
    fi

    return "${status}"
}
#!/usr/bin/env bash
###############################################################################
# NAME         : util_ruby.sh
# DESCRIPTION  : Ruby environment, gem, and bundler management utilities.
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-10-27
###############################################################################
# EDIT HISTORY:
# DATE        | EDITED BY      | DESCRIPTION
# ------------|----------------|-----------------------------------------------
# 2025-10-27  | Adam Compton   | Initial generation (style-guide compliant)
# 2025-12-26  | Adam Compton   | Added version-specific gem installation,
#             |                | batch installation from array, proxy support,
#             |                | and merged features from utils_ruby.sh
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Library Guard
#===============================================================================
if [[ -n "${UTIL_RUBY_SH_LOADED:-}" ]]; then
    if (return 0 2> /dev/null); then
        return 0
    fi
else
    UTIL_RUBY_SH_LOADED=1
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
# Globals
#===============================================================================
: "${PASS:=0}"
: "${FAIL:=1}"

# Default gem array for batch operations (can be overridden)
declare -ga RUBY_GEMS=()

#===============================================================================
# Internal Helpers
#===============================================================================

###############################################################################
# ruby::_build_proxy_env
#------------------------------------------------------------------------------
# Purpose  : Build proxy environment array for gem commands
# Usage    : local -a proxy_env=($(ruby::_build_proxy_env))
# Returns  : Prints proxy env wrapper arguments
# Notes    : Supports PROXY as "VAR=value" or as URL format
###############################################################################
function ruby::_build_proxy_env() {
    local -a proxy_env=()

    if [[ -n "${PROXY:-}" ]]; then
        if [[ "${PROXY}" == *"="* ]]; then
            # PROXY is in VAR=value format (e.g., "http_proxy=http://...")
            proxy_env=("env" "${PROXY}")
        else
            # PROXY is a URL, set both http_proxy and https_proxy
            proxy_env=("env" "http_proxy=${PROXY}" "https_proxy=${PROXY}")
        fi
    fi

    if [[ ${#proxy_env[@]} -gt 0 ]]; then
        printf '%s\n' "${proxy_env[*]}"
    fi
    return "${PASS}"
}

###############################################################################
# ruby::_parse_version_from_spec
#------------------------------------------------------------------------------
# Purpose  : Parse version number from a gem spec string
# Usage    : ver=$(ruby::_parse_version_from_spec "nori -v 2.6.0")
# Arguments:
#   $1 : Gem spec string
# Returns  : Prints version if found, empty otherwise
###############################################################################
function ruby::_parse_version_from_spec() {
    local spec="${1:-}"
    local -a parts
    local ver_value=""
    local i a

    # Split spec into parts
    IFS=' ' read -r -a parts <<< "${spec}"

    # Search for version flags in multiple forms:
    # -v 2.6.0, -v2.6.0, --version 2.6.0, --version=2.6.0
    for ((i = 0; i < ${#parts[@]}; i++)); do
        a="${parts[i]}"

        if [[ "${a}" == "-v" || "${a}" == "--version" ]]; then
            # Next element is the version
            if ((i + 1 < ${#parts[@]})); then
                ver_value="${parts[i + 1]}"
            fi
            break
        elif [[ "${a}" == -v* && "${a}" != "-v" ]]; then
            # -v2.6.0 format
            ver_value="${a:2}"
            break
        elif [[ "${a}" == --version=* ]]; then
            # --version=2.6.0 format
            ver_value="${a#*=}"
            break
        fi
    done

    printf '%s\n' "${ver_value}"
    return "${PASS}"
}

###############################################################################
# ruby::_parse_name_from_spec
#------------------------------------------------------------------------------
# Purpose  : Parse gem name from a gem spec string
# Usage    : name=$(ruby::_parse_name_from_spec "nori -v 2.6.0")
# Arguments:
#   $1 : Gem spec string
# Returns  : Prints gem name (first word)
###############################################################################
function ruby::_parse_name_from_spec() {
    local spec="${1:-}"
    local -a parts

    IFS=' ' read -r -a parts <<< "${spec}"
    printf '%s\n' "${parts[0]:-}"
    return "${PASS}"
}

###############################################################################
# ruby::_parse_args_from_spec
#------------------------------------------------------------------------------
# Purpose  : Parse gem install arguments from a gem spec string
# Usage    : args=$(ruby::_parse_args_from_spec "nori -v 2.6.0")
# Arguments:
#   $1 : Gem spec string
# Returns  : Prints arguments (everything after gem name)
###############################################################################
function ruby::_parse_args_from_spec() {
    local spec="${1:-}"
    local -a parts

    IFS=' ' read -r -a parts <<< "${spec}"

    # Return everything except the first element (gem name)
    if [[ ${#parts[@]} -gt 1 ]]; then
        printf '%s\n' "${parts[*]:1}"
    fi
    return "${PASS}"
}

#===============================================================================
# Ruby Detection and Environment
#===============================================================================

###############################################################################
# ruby::is_available
#------------------------------------------------------------------------------
# Purpose  : Check if Ruby is installed.
# Usage    : ruby::is_available && info "Ruby detected"
# Returns  : PASS if installed, FAIL otherwise.
###############################################################################
function ruby::is_available() {
    if cmd::exists ruby; then
        debug "Ruby found at $(command -v ruby)"
        return "${PASS}"
    fi
    debug "Ruby not found"
    return "${FAIL}"
}

###############################################################################
# ruby::gem_available
#------------------------------------------------------------------------------
# Purpose  : Check if gem command is available.
# Usage    : ruby::gem_available && info "gem detected"
# Returns  : PASS if available, FAIL otherwise.
###############################################################################
function ruby::gem_available() {
    if cmd::exists gem; then
        debug "gem found at $(command -v gem)"
        return "${PASS}"
    fi
    debug "gem not found"
    return "${FAIL}"
}

###############################################################################
# ruby::get_version
#------------------------------------------------------------------------------
# Purpose  : Get the current Ruby version.
# Usage    : ver=$(ruby::get_version)
# Returns  : Prints Ruby version string.
###############################################################################
function ruby::get_version() {
    if ! ruby::is_available; then
        error "Ruby not installed"
        return "${FAIL}"
    fi
    local version
    version=$(ruby -v 2> /dev/null | awk '{print $2}')
    printf '%s\n' "${version:-unknown}"
    return "${PASS}"
}

###############################################################################
# ruby::get_path
#------------------------------------------------------------------------------
# Purpose  : Get the path to the Ruby executable.
# Usage    : ruby::get_path
# Returns  : Prints Ruby path.
###############################################################################
function ruby::get_path() {
    local path
    path="$(command -v ruby 2> /dev/null || echo "/usr/bin/ruby")"
    printf '%s\n' "${path}"
    return "${PASS}"
}

###############################################################################
# ruby::rbenv_available
#------------------------------------------------------------------------------
# Purpose  : Check if rbenv is installed.
# Usage    : ruby::rbenv_available
# Returns  : PASS if installed, FAIL otherwise.
###############################################################################
function ruby::rbenv_available() {
    if cmd::exists rbenv; then
        debug "rbenv detected"
        return "${PASS}"
    fi
    debug "rbenv not found"
    return "${FAIL}"
}

###############################################################################
# ruby::rvm_available
#------------------------------------------------------------------------------
# Purpose  : Check if RVM is installed.
# Usage    : ruby::rvm_available
# Returns  : PASS if installed, FAIL otherwise.
###############################################################################
function ruby::rvm_available() {
    if cmd::exists rvm; then
        debug "RVM detected"
        return "${PASS}"
    fi
    debug "RVM not found"
    return "${FAIL}"
}

#===============================================================================
# Gem Management - Core Functions
#===============================================================================

###############################################################################
# ruby::gem_install
#------------------------------------------------------------------------------
# Purpose  : Install one or more gems globally (simple names only).
# Usage    : ruby::gem_install "bundler" "rake"
# Arguments:
#   $@ : Gem names to install
# Returns  : PASS if all successful, FAIL if any failed.
# Notes    : For version-specific installs, use ruby::gem_install_spec
###############################################################################
function ruby::gem_install() {
    local -a gems=("$@")

    if [[ ${#gems[@]} -eq 0 ]]; then
        error "ruby::gem_install requires one or more gem names"
        return "${FAIL}"
    fi

    if ! ruby::gem_available; then
        fail "gem binary not found in PATH"
        return "${FAIL}"
    fi

    local gem overall_status="${PASS}"
    local proxy_env_str
    local -a proxy_env=()

    # Build proxy environment
    proxy_env_str=$(ruby::_build_proxy_env)
    if [[ -n "${proxy_env_str}" ]]; then
        IFS=' ' read -r -a proxy_env <<< "${proxy_env_str}"
    fi

    for gem in "${gems[@]}"; do
        info "Installing gem: ${gem}"

        local install_ok=0

        # Run gem install with optional proxy
        if [[ ${#proxy_env[@]} -gt 0 ]]; then
            if "${proxy_env[@]}" gem install --no-document "${gem}" > /dev/null 2>&1; then
                install_ok=1
            fi
        else
            if gem install --no-document "${gem}" > /dev/null 2>&1; then
                install_ok=1
            fi
        fi

        if [[ ${install_ok} -eq 1 ]]; then
            pass "Successfully installed ${gem}"
        else
            fail "Failed to install ${gem}"
            overall_status="${FAIL}"
            continue
        fi

        # Verify installation
        if gem list -i "${gem}" > /dev/null 2>&1; then
            debug "Verified gem installation: ${gem}"
        else
            fail "Verification failed: ${gem} not detected after install"
            overall_status="${FAIL}"
        fi
    done

    return "${overall_status}"
}

###############################################################################
# ruby::gem_install_spec
#------------------------------------------------------------------------------
# Purpose  : Install a gem with version specification.
# Usage    : ruby::gem_install_spec "nori -v 2.6.0"
#            ruby::gem_install_spec "evil-winrm"
# Arguments:
#   $1 : Gem specification string (name + optional version flags)
# Returns  : PASS if successful, FAIL otherwise.
# Notes    : Supports -v, --version, -vX.X.X, --version=X.X.X formats
###############################################################################
function ruby::gem_install_spec() {
    local spec="${1:-}"

    if [[ -z "${spec}" ]]; then
        error "ruby::gem_install_spec requires a gem specification"
        return "${FAIL}"
    fi

    if ! ruby::gem_available; then
        fail "gem binary not found in PATH"
        return "${FAIL}"
    fi

    # Parse the spec
    local name args_str ver_value
    local -a args=()

    name=$(ruby::_parse_name_from_spec "${spec}")
    args_str=$(ruby::_parse_args_from_spec "${spec}")
    ver_value=$(ruby::_parse_version_from_spec "${spec}")

    if [[ -z "${name}" ]]; then
        error "Could not parse gem name from spec: ${spec}"
        return "${FAIL}"
    fi

    # Convert args string to array
    if [[ -n "${args_str}" ]]; then
        IFS=' ' read -r -a args <<< "${args_str}"
    fi

    # Build proxy environment
    local proxy_env_str
    local -a proxy_env=()
    proxy_env_str=$(ruby::_build_proxy_env)
    if [[ -n "${proxy_env_str}" ]]; then
        IFS=' ' read -r -a proxy_env <<< "${proxy_env_str}"
    fi

    if [[ ${#args[@]} -gt 0 ]]; then
        info "Installing ${name} ${args[*]}..."
    else
        info "Installing ${name}..."
    fi

    local install_ok=0

    # Run gem install with optional proxy and args
    if [[ ${#proxy_env[@]} -gt 0 ]]; then
        if [[ ${#args[@]} -gt 0 ]]; then
            if "${proxy_env[@]}" gem install --no-document "${name}" "${args[@]}" > /dev/null 2>&1; then
                install_ok=1
            fi
        else
            if "${proxy_env[@]}" gem install --no-document "${name}" > /dev/null 2>&1; then
                install_ok=1
            fi
        fi
    else
        if [[ ${#args[@]} -gt 0 ]]; then
            if gem install --no-document "${name}" "${args[@]}" > /dev/null 2>&1; then
                install_ok=1
            fi
        else
            if gem install --no-document "${name}" > /dev/null 2>&1; then
                install_ok=1
            fi
        fi
    fi

    if [[ ${install_ok} -eq 0 ]]; then
        fail "Failed to install ${name}"
        return "${FAIL}"
    fi

    pass "Installed ${name}"

    # Verification with version check if specified
    if [[ -n "${ver_value}" ]]; then
        if gem list -i --version "${ver_value}" "${name}" > /dev/null 2>&1; then
            pass "Verification OK: ${name} (${ver_value})"
            return "${PASS}"
        else
            fail "Verification failed: ${name} (${ver_value}) not found"
            return "${FAIL}"
        fi
    else
        if gem list -i "${name}" > /dev/null 2>&1; then
            pass "Verification OK: ${name}"
            return "${PASS}"
        else
            fail "Verification failed: ${name} not found"
            return "${FAIL}"
        fi
    fi
}

###############################################################################
# ruby::gem_install_batch
#------------------------------------------------------------------------------
# Purpose  : Install gems from an array of specifications.
# Usage    : ruby::gem_install_batch "RUBY_GEMS"
#            ruby::gem_install_batch  # Uses default RUBY_GEMS array
# Arguments:
#   $1 : Array name containing gem specs (optional, defaults to RUBY_GEMS)
# Returns  : PASS if all successful, FAIL if any failed
# Exit codes:
#   0 : All gems installed successfully
#   1 : One or more install/verify failures
#   2 : gem binary not found
#   3 : Gem array not defined or empty
# Notes    : Array entries can be "gem_name" or "gem_name -v X.X.X"
###############################################################################
function ruby::gem_install_batch() {
    local array_name="${1:-RUBY_GEMS}"
    local -a gems=()
    local rc=0

    # Use nameref for array access
    if [[ "${array_name}" == "RUBY_GEMS" ]]; then
        if [[ -z "${RUBY_GEMS+x}" || ${#RUBY_GEMS[@]} -eq 0 ]]; then
            fail "RUBY_GEMS array is not defined or empty"
            return 3
        fi
        gems=("${RUBY_GEMS[@]}")
    else
        # Try to access named array
        declare -n gems_ref="${array_name}" 2> /dev/null || {
            fail "Array not defined: ${array_name}"
            return 3
        }
        if [[ ${#gems_ref[@]} -eq 0 ]]; then
            fail "Array ${array_name} is empty"
            return 3
        fi
        gems=("${gems_ref[@]}")
    fi

    if ! ruby::gem_available; then
        fail "gem binary not found in PATH"
        return 2
    fi

    info "Installing ${#gems[@]} gem(s)..."

    local gem_spec
    for gem_spec in "${gems[@]}"; do
        if ! ruby::gem_install_spec "${gem_spec}"; then
            ((rc++))
        fi
    done

    if ((rc > 0)); then
        fail "One or more Ruby gems failed to install or verify (${rc} failures)"
        return 1
    fi

    pass "All Ruby gems installed and verified successfully"
    return "${PASS}"
}

###############################################################################
# ruby::gem_install_with_version
#------------------------------------------------------------------------------
# Purpose  : Install a specific version of a gem.
# Usage    : ruby::gem_install_with_version "rails" "7.0.0"
# Arguments:
#   $1 : Gem name (required)
#   $2 : Version (required)
# Returns  : PASS if successful, FAIL otherwise.
###############################################################################
function ruby::gem_install_with_version() {
    local name="${1:-}"
    local version="${2:-}"

    if [[ -z "${name}" || -z "${version}" ]]; then
        error "Usage: ruby::gem_install_with_version <gem_name> <version>"
        return "${FAIL}"
    fi

    ruby::gem_install_spec "${name} -v ${version}"
    return $?
}

###############################################################################
# ruby::gem_update
#------------------------------------------------------------------------------
# Purpose  : Update all installed gems.
# Usage    : ruby::gem_update
# Returns  : PASS if successful, FAIL otherwise.
###############################################################################
function ruby::gem_update() {
    info "Updating installed gems..."

    local proxy_env_str
    local -a proxy_env=()
    proxy_env_str=$(ruby::_build_proxy_env)
    if [[ -n "${proxy_env_str}" ]]; then
        IFS=' ' read -r -a proxy_env <<< "${proxy_env_str}"
    fi

    local update_ok=0
    if [[ ${#proxy_env[@]} -gt 0 ]]; then
        if "${proxy_env[@]}" gem update > /dev/null 2>&1; then
            update_ok=1
        fi
    else
        if gem update > /dev/null 2>&1; then
            update_ok=1
        fi
    fi

    if [[ ${update_ok} -eq 1 ]]; then
        pass "All gems updated successfully"
        return "${PASS}"
    fi

    fail "Gem update failed"
    return "${FAIL}"
}

###############################################################################
# ruby::install_rbenv
#------------------------------------------------------------------------------
# Purpose  : Install rbenv for Ruby version management
# Usage    : ruby::install_rbenv
# Returns  : PASS if successful, FAIL otherwise
###############################################################################
function ruby::install_rbenv() {
    if ruby::rbenv_available; then
        info "rbenv already installed"
        return "${PASS}"
    fi

    local rbenv_root="${HOME}/.rbenv"

    info "Installing rbenv..."

    # Check if git::clone is available, fall back to direct git
    if declare -F git::clone > /dev/null 2>&1; then
        if git::clone "https://github.com/rbenv/rbenv.git" "${rbenv_root}"; then
            local plugin_dir="${rbenv_root}/plugins/ruby-build"
            if git::clone "https://github.com/rbenv/ruby-build.git" "${plugin_dir}"; then
                pass "rbenv installed successfully"
                info "Add to shell: export PATH=\"${rbenv_root}/bin:\$PATH\" && eval \"\$(rbenv init -)\""
                return "${PASS}"
            fi
        fi
    else
        if git clone "https://github.com/rbenv/rbenv.git" "${rbenv_root}" 2> /dev/null; then
            local plugin_dir="${rbenv_root}/plugins/ruby-build"
            if git clone "https://github.com/rbenv/ruby-build.git" "${plugin_dir}" 2> /dev/null; then
                pass "rbenv installed successfully"
                info "Add to shell: export PATH=\"${rbenv_root}/bin:\$PATH\" && eval \"\$(rbenv init -)\""
                return "${PASS}"
            fi
        fi
    fi

    fail "rbenv installation failed"
    return "${FAIL}"
}

###############################################################################
# ruby::rbenv_install_version
#------------------------------------------------------------------------------
# Purpose  : Install a specific Ruby version via rbenv
# Usage    : ruby::rbenv_install_version "3.2.0"
# Arguments:
#   $1 : Ruby version to install
# Returns  : PASS if successful, FAIL otherwise
###############################################################################
function ruby::rbenv_install_version() {
    local version="${1:-}"

    if [[ -z "${version}" ]]; then
        error "ruby::rbenv_install_version requires a version"
        return "${FAIL}"
    fi

    if ! ruby::rbenv_available; then
        error "rbenv not installed"
        return "${FAIL}"
    fi

    # Check if already installed
    if rbenv versions --bare 2> /dev/null | grep -qx "${version}"; then
        info "Ruby ${version} already installed via rbenv"
        return "${PASS}"
    fi

    info "Installing Ruby ${version} via rbenv..."
    if rbenv install "${version}"; then
        pass "Ruby ${version} installed via rbenv"
        return "${PASS}"
    fi

    fail "Failed to install Ruby ${version}"
    return "${FAIL}"
}

###############################################################################
# ruby::get_bundler_version
#------------------------------------------------------------------------------
# Purpose  : Get Bundler major version (1 or 2)
# Usage    : ver=$(ruby::get_bundler_version)
# Returns  : Prints major version
###############################################################################
function ruby::get_bundler_version() {
    if ! ruby::is_gem_installed "bundler"; then
        error "Bundler not installed"
        return "${FAIL}"
    fi

    local version
    version=$(bundle --version 2> /dev/null | awk '{print $3}' | cut -d. -f1)
    printf '%s\n' "${version:-unknown}"
    return "${PASS}"
}

###############################################################################
# ruby::gem_cleanup
#------------------------------------------------------------------------------
# Purpose  : Remove old gem versions
# Usage    : ruby::gem_cleanup
# Returns  : PASS if successful, FAIL otherwise
###############################################################################
function ruby::gem_cleanup() {
    info "Cleaning up old gem versions..."
    if gem cleanup > /dev/null 2>&1; then
        pass "Gem cleanup complete"
        return "${PASS}"
    fi

    fail "Gem cleanup failed"
    return "${FAIL}"
}

###############################################################################
# ruby::is_gem_installed
#------------------------------------------------------------------------------
# Purpose  : Check if a specific gem is installed.
# Usage    : ruby::is_gem_installed "bundler"
#            ruby::is_gem_installed "nori" "2.6.0"
# Arguments:
#   $1 : Gem name (required)
#   $2 : Version (optional)
# Returns  : PASS if installed, FAIL otherwise.
###############################################################################
function ruby::is_gem_installed() {
    local gem_name="${1:-}"
    local version="${2:-}"

    if [[ -z "${gem_name}" ]]; then
        error "ruby::is_gem_installed requires a gem name"
        return "${FAIL}"
    fi

    if [[ -n "${version}" ]]; then
        if gem list -i --version "${version}" "${gem_name}" > /dev/null 2>&1; then
            debug "Gem installed: ${gem_name} (${version})"
            return "${PASS}"
        fi
    else
        if gem list -i "${gem_name}" > /dev/null 2>&1; then
            debug "Gem installed: ${gem_name}"
            return "${PASS}"
        fi
    fi

    debug "Gem not installed: ${gem_name}"
    return "${FAIL}"
}

###############################################################################
# ruby::get_gem_version
#------------------------------------------------------------------------------
# Purpose  : Get the version of a specific installed gem.
# Usage    : ruby::get_gem_version "bundler"
# Returns  : Prints version or FAIL.
###############################################################################
function ruby::get_gem_version() {
    local gem_name="${1:-}"
    if [[ -z "${gem_name}" ]]; then
        error "ruby::get_gem_version requires a gem name"
        return "${FAIL}"
    fi

    local version
    # Use gem list with exact match to get version
    version=$(gem list "^${gem_name}$" 2> /dev/null | grep -E "^${gem_name} " | sed -E 's/.*\(([^,)]+).*/\1/')

    if [[ -n "${version}" ]]; then
        printf '%s\n' "${version}"
        return "${PASS}"
    fi

    printf '%s\n' "unknown"
    return "${FAIL}"
}

###############################################################################
# ruby::gem_uninstall
#------------------------------------------------------------------------------
# Purpose  : Uninstall a gem.
# Usage    : ruby::gem_uninstall "gem_name" ["version"]
# Arguments:
#   $1 : Gem name (required)
#   $2 : Version (optional, uninstalls all versions if omitted)
# Returns  : PASS if successful, FAIL otherwise.
###############################################################################
function ruby::gem_uninstall() {
    local gem_name="${1:-}"
    local version="${2:-}"

    if [[ -z "${gem_name}" ]]; then
        error "ruby::gem_uninstall requires a gem name"
        return "${FAIL}"
    fi

    local -a args=(uninstall "${gem_name}" --executables)

    if [[ -n "${version}" ]]; then
        args+=(--version "${version}")
    else
        args+=(--all)
    fi

    info "Uninstalling ${gem_name}${version:+ (${version})}..."

    if gem "${args[@]}" > /dev/null 2>&1; then
        pass "Uninstalled ${gem_name}"
        return "${PASS}"
    fi

    fail "Failed to uninstall ${gem_name}"
    return "${FAIL}"
}

#===============================================================================
# Bundler and Project Tools
#===============================================================================

###############################################################################
# ruby::bundler_install
#------------------------------------------------------------------------------
# Purpose  : Install Bundler if not already installed.
# Usage    : ruby::bundler_install
# Returns  : PASS if installed, FAIL otherwise.
###############################################################################
function ruby::bundler_install() {
    if ruby::is_gem_installed "bundler"; then
        debug "Bundler already installed"
        return "${PASS}"
    fi
    info "Installing Bundler..."
    if ruby::gem_install "bundler"; then
        pass "Bundler installed successfully"
        return "${PASS}"
    fi
    fail "Bundler installation failed"
    return "${FAIL}"
}

###############################################################################
# ruby::bundle_install
#------------------------------------------------------------------------------
# Purpose  : Install project dependencies via Bundler.
# Usage    : ruby::bundle_install
# Returns  : PASS if successful, FAIL otherwise.
###############################################################################
function ruby::bundle_install() {
    if ! cmd::exists bundle; then
        ruby::bundler_install || return "${FAIL}"
    fi

    info "Installing bundle dependencies..."

    local proxy_env_str
    local -a proxy_env=()
    proxy_env_str=$(ruby::_build_proxy_env)
    if [[ -n "${proxy_env_str}" ]]; then
        IFS=' ' read -r -a proxy_env <<< "${proxy_env_str}"
    fi

    local install_ok=0
    if [[ ${#proxy_env[@]} -gt 0 ]]; then
        if "${proxy_env[@]}" bundle install > /dev/null 2>&1; then
            install_ok=1
        fi
    else
        if bundle install > /dev/null 2>&1; then
            install_ok=1
        fi
    fi

    if [[ ${install_ok} -eq 1 ]]; then
        pass "Dependencies installed via Bundler"
        return "${PASS}"
    fi

    fail "Bundle installation failed"
    return "${FAIL}"
}

###############################################################################
# ruby::bundle_exec
#------------------------------------------------------------------------------
# Purpose  : Execute a command in bundle context.
# Usage    : ruby::bundle_exec "rake" "db:migrate"
# Arguments:
#   $@ : Command and arguments to execute
# Returns  : Exit code of the executed command.
###############################################################################
function ruby::bundle_exec() {
    if [[ $# -eq 0 ]]; then
        error "ruby::bundle_exec requires a command"
        return "${FAIL}"
    fi

    if ! cmd::exists bundle; then
        error "Bundler not installed"
        return "${FAIL}"
    fi

    debug "Running: bundle exec $*"
    bundle exec "$@"
    return $?
}

###############################################################################
# ruby::run_script
#------------------------------------------------------------------------------
# Purpose  : Execute a Ruby script.
# Usage    : ruby::run_script "./script.rb"
# Returns  : PASS if successful, FAIL otherwise.
###############################################################################
function ruby::run_script() {
    local script="${1:-}"
    if [[ -z "${script}" ]]; then
        error "ruby::run_script requires a script path"
        return "${FAIL}"
    fi

    if [[ ! -f "${script}" ]]; then
        error "Ruby script not found: ${script}"
        return "${FAIL}"
    fi

    info "Running Ruby script: ${script}"
    if ruby "${script}"; then
        pass "Ruby script executed successfully"
        return "${PASS}"
    fi

    fail "Ruby script execution failed"
    return "${FAIL}"
}

#===============================================================================
# Utility Functions
#===============================================================================

###############################################################################
# ruby::list_gems
#------------------------------------------------------------------------------
# Purpose  : List all installed gems.
# Usage    : ruby::list_gems
# Returns  : Prints gem list
###############################################################################
function ruby::list_gems() {
    if ! ruby::gem_available; then
        error "gem not available"
        return "${FAIL}"
    fi

    gem list
    return "${PASS}"
}

###############################################################################
# ruby::gem_outdated
#------------------------------------------------------------------------------
# Purpose  : List outdated gems.
# Usage    : ruby::gem_outdated
# Returns  : Prints outdated gem list
###############################################################################
function ruby::gem_outdated() {
    if ! ruby::gem_available; then
        error "gem not available"
        return "${FAIL}"
    fi

    info "Checking for outdated gems..."
    gem outdated
    return "${PASS}"
}

###############################################################################
# ruby::env_info
#------------------------------------------------------------------------------
# Purpose  : Display Ruby environment information.
# Usage    : ruby::env_info
# Returns  : PASS always
###############################################################################
function ruby::env_info() {
    printf "Ruby Environment Information:\n"
    printf "=============================\n"

    if ruby::is_available; then
        printf "Ruby version: %s\n" "$(ruby::get_version)"
        printf "Ruby path:    %s\n" "$(ruby::get_path)"
    else
        printf "Ruby: NOT INSTALLED\n"
    fi

    if ruby::gem_available; then
        printf "Gem path:     %s\n" "$(command -v gem)"
        local gem_ver
        gem_ver=$(gem --version 2> /dev/null || echo "unknown")
        printf "Gem version:  %s\n" "${gem_ver}"
    else
        printf "Gem: NOT AVAILABLE\n"
    fi

    if ruby::is_gem_installed "bundler"; then
        printf "Bundler:      v%s\n" "$(ruby::get_bundler_version)"
    else
        printf "Bundler:      NOT INSTALLED\n"
    fi

    if ruby::rbenv_available; then
        printf "rbenv:        AVAILABLE\n"
    fi

    if ruby::rvm_available; then
        printf "RVM:          AVAILABLE\n"
    fi

    return "${PASS}"
}

#===============================================================================
# Self-Test
#===============================================================================

###############################################################################
# ruby::self_test
#------------------------------------------------------------------------------
# Purpose  : Self-test for util_ruby.sh functionality
# Usage    : ruby::self_test
# Returns  : PASS (0) if all tests pass, FAIL (1) otherwise
###############################################################################
function ruby::self_test() {
    info "Running util_ruby.sh self-test..."

    local status="${PASS}"

    # Test 1: Check if Ruby detection works
    if ! declare -F ruby::is_available > /dev/null 2>&1; then
        fail "ruby::is_available function not available"
        status="${FAIL}"
    fi

    # Test 2: Test version parsing helpers
    local test_ver
    test_ver=$(ruby::_parse_version_from_spec "nori -v 2.6.0")
    if [[ "${test_ver}" != "2.6.0" ]]; then
        fail "ruby::_parse_version_from_spec failed: expected '2.6.0', got '${test_ver}'"
        status="${FAIL}"
    fi

    test_ver=$(ruby::_parse_version_from_spec "rails --version=7.0.0")
    if [[ "${test_ver}" != "7.0.0" ]]; then
        fail "ruby::_parse_version_from_spec (--version=) failed"
        status="${FAIL}"
    fi

    local test_name
    test_name=$(ruby::_parse_name_from_spec "bundler -v 2.4.0")
    if [[ "${test_name}" != "bundler" ]]; then
        fail "ruby::_parse_name_from_spec failed"
        status="${FAIL}"
    fi

    # Test 3: If Ruby is available, test version retrieval
    if ruby::is_available; then
        if ! ruby::get_version > /dev/null 2>&1; then
            fail "ruby::get_version failed"
            status="${FAIL}"
        fi

        if ! ruby::get_path > /dev/null 2>&1; then
            fail "ruby::get_path failed"
            status="${FAIL}"
        fi
    else
        info "Ruby not available - skipping version tests"
    fi

    # Test 4: Test proxy env builder (should not fail)
    if ! ruby::_build_proxy_env > /dev/null 2>&1; then
        fail "ruby::_build_proxy_env failed"
        status="${FAIL}"
    fi

    if [[ "${status}" -eq "${PASS}" ]]; then
        pass "util_ruby.sh self-test passed"
    else
        fail "util_ruby.sh self-test failed"
    fi

    return "${status}"
}
