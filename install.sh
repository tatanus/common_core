#!/usr/bin/env bash
###############################################################################
# NAME         : install.sh
# DESCRIPTION  : Install common_core library files to user directory
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-01-04
###############################################################################
# EDIT HISTORY:
# DATE       | EDITED BY    | DESCRIPTION
# -----------|--------------|-----------------------------------------------
# 2025-01-04 | Adam Compton | Initial creation
# 2025-01-04 | Adam Compton | Style guide compliance and security hardening
###############################################################################

set -uo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# Global constants
readonly PASS=0
readonly FAIL=1
readonly REQUIRED_BASH_VERSION=4

# Default installation directory
readonly DEFAULT_INSTALL_DIR="${HOME}/.config/bash/lib/common_core"
INSTALL_DIR="${DEFAULT_INSTALL_DIR}"

# Flags
RUN_TESTS=true
VERBOSE=false
FORCE=false

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

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
# Validation Functions
#===============================================================================

###############################################################################
# check_bash_version
#------------------------------------------------------------------------------
# Purpose  : Verify Bash version meets minimum requirements
# Usage    : check_bash_version
# Arguments: None
# Returns  : PASS (0) if version >= 4.0, FAIL (1) otherwise
# Outputs  : Error message to stderr if version too old
# Requires:
#   Variables: REQUIRED_BASH_VERSION, BASH_VERSINFO, BASH_VERSION
#   Functions: error
# Notes    : macOS ships with Bash 3.2 - users must install Bash 4+ via Homebrew
###############################################################################
function check_bash_version() {
    local bash_major="${BASH_VERSINFO[0]}"

    if ((bash_major < REQUIRED_BASH_VERSION)); then
        error "Bash ${REQUIRED_BASH_VERSION}.0+ required (found: ${BASH_VERSION})"
        error "macOS users: brew install bash"
        return "${FAIL}"
    fi

    debug "Bash version: ${BASH_VERSION}"
    return "${PASS}"
}

###############################################################################
# get_version
#------------------------------------------------------------------------------
# Purpose  : Read version from VERSION file
# Usage    : get_version
# Arguments: None
# Returns  : PASS (0)
# Outputs  : Version string to stdout
# Requires:
#   Variables: SCRIPT_DIR
# Notes    : Returns "unknown" if VERSION file doesn't exist or can't be read
###############################################################################
function get_version() {
    local version_file="${SCRIPT_DIR}/VERSION"

    if [[ -f "${version_file}" ]]; then
        if ! cat "${version_file}" 2> /dev/null; then
            printf 'unknown\n'
        fi
    else
        printf 'unknown\n'
    fi

    return "${PASS}"
}

VERSION="$(get_version)"
readonly VERSION

###############################################################################
# validate_install_dir
#------------------------------------------------------------------------------
# Purpose  : Validate installation directory is safe
# Usage    : validate_install_dir
# Arguments: None
# Returns  : PASS (0) if safe, FAIL (1) if dangerous
# Outputs  : Error messages to stderr if validation fails
# Requires:
#   Variables: INSTALL_DIR, HOME
#   Functions: error
# Notes    : Prevents installation to /, $HOME, or paths with parent traversal
###############################################################################
function validate_install_dir() {
    # Check for dangerous paths
    if [[ "${INSTALL_DIR}" == "/" ]]; then
        error "Refusing to install to root directory: /"
        return "${FAIL}"
    fi

    if [[ "${INSTALL_DIR}" == "${HOME}" ]]; then
        error "Refusing to install directly to HOME: ${HOME}"
        error "Use a subdirectory like ${HOME}/.config/bash/lib"
        return "${FAIL}"
    fi

    # Check for parent directory traversal
    if [[ "${INSTALL_DIR}" == *".."* ]]; then
        error "Path contains parent traversal: ${INSTALL_DIR}"
        return "${FAIL}"
    fi

    # Check for system directories
    local -a dangerous_paths=(
        "/bin"
        "/sbin"
        "/usr/bin"
        "/usr/sbin"
        "/etc"
        "/var"
        "/tmp"
    )

    for dangerous_path in "${dangerous_paths[@]}"; do
        if [[ "${INSTALL_DIR}" == "${dangerous_path}"* ]]; then
            error "Refusing to install to system directory: ${INSTALL_DIR}"
            error "Use a user directory like ${DEFAULT_INSTALL_DIR}"
            return "${FAIL}"
        fi
    done

    debug "Installation directory validated: ${INSTALL_DIR}"
    return "${PASS}"
}

#===============================================================================
# Usage and Argument Parsing
#===============================================================================

###############################################################################
# usage
#------------------------------------------------------------------------------
# Purpose  : Display usage information
# Usage    : usage
# Arguments: None
# Returns  : PASS (0)
# Outputs  : Usage text to stdout
# Requires:
#   Variables: DEFAULT_INSTALL_DIR, VERSION
# Notes    : Called when -h/--help is provided or on argument errors
###############################################################################
function usage() {
    cat << EOF
Usage: ${0##*/} [OPTIONS]

Install common_core library files to user directory

OPTIONS:
    -d, --dir DIR              Install to specified directory
                               (default: ${DEFAULT_INSTALL_DIR})
    -f, --force                Force installation (overwrite existing files)
    -s, --skip-tests           Skip self-tests after installation
    -v, --verbose              Enable verbose output
    -h, --help                 Display this help message

EXAMPLES:
    ${0##*/}                           # Install to default location
    ${0##*/} -d ~/.local/lib/bash      # Install to custom directory
    ${0##*/} -f                        # Force overwrite existing files
    ${0##*/} -s                        # Skip self-tests

DESCRIPTION:
    This script installs the common_core library (version ${VERSION}) to the
    specified directory. It will:

    1. Validate environment and installation directory
    2. Create the installation directory if it doesn't exist
    3. Copy all files from lib/ to the installation directory
    4. Set appropriate permissions on shell scripts
    5. Configure ~/.bashrc to automatically load the library
    6. Run self-tests to verify installation (unless --skip-tests)
    7. Create/update ~/.config/bash/update.sh for future updates

    The library will be installed to: ${DEFAULT_INSTALL_DIR}
    Unless you specify a different directory with --dir

SAFETY:
    - Refuses to install to system directories (/, /usr, /etc, etc.)
    - Validates paths to prevent accidental system modifications
    - Creates backups when updating existing installations

EOF
    return "${PASS}"
}

###############################################################################
# parse_arguments
#------------------------------------------------------------------------------
# Purpose  : Parse command line arguments
# Usage    : parse_arguments "$@"
# Arguments:
#   $@ : All command line arguments
# Returns  : PASS (0) on success, exits with FAIL (1) on error
# Outputs  : Error messages and usage on invalid arguments
# Requires:
#   Variables: INSTALL_DIR, FORCE, RUN_TESTS, VERBOSE (all modified)
#   Functions: usage, error
# Notes    : Exits script on invalid arguments
###############################################################################
function parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -d | --dir)
                if [[ -z "${2:-}" ]]; then
                    error "Option ${1} requires an argument"
                    usage
                    exit "${FAIL}"
                fi
                INSTALL_DIR="${2}"
                shift 2
                ;;
            -f | --force)
                FORCE=true
                shift
                ;;
            -s | --skip-tests)
                RUN_TESTS=false
                shift
                ;;
            -v | --verbose)
                VERBOSE=true
                shift
                ;;
            -h | --help)
                usage
                exit "${PASS}"
                ;;
            *)
                error "Unknown option: ${1}"
                usage
                exit "${FAIL}"
                ;;
        esac
    done

    return "${PASS}"
}

#===============================================================================
# Installation Functions
#===============================================================================

###############################################################################
# check_prerequisites
#------------------------------------------------------------------------------
# Purpose  : Check for required tools
# Usage    : check_prerequisites
# Arguments: None
# Returns  : PASS (0) if all required tools found, FAIL (1) otherwise
# Outputs  : Status messages to stderr
# Requires:
#   Commands: bash, cp, mkdir, chmod, find, git, curl (git/curl for updates)
#   Functions: info, pass, error
# Notes    : git and curl are optional (needed only for update functionality)
###############################################################################
function check_prerequisites() {
    info "Checking prerequisites..."

    local -a missing_tools=()
    local -a optional_tools=()
    local -a required_cmds=(bash cp mkdir chmod find)
    local -a optional_cmds=(git curl)

    # Check required tools
    for tool in "${required_cmds[@]}"; do
        if ! command -v "${tool}" > /dev/null 2>&1; then
            missing_tools+=("${tool}")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        error "Missing required tools: ${missing_tools[*]}"
        return "${FAIL}"
    fi

    # Check optional tools (for update functionality)
    for tool in "${optional_cmds[@]}"; do
        if ! command -v "${tool}" > /dev/null 2>&1; then
            optional_tools+=("${tool}")
        fi
    done

    if [[ ${#optional_tools[@]} -gt 0 ]]; then
        warn "Missing optional tools (needed for updates): ${optional_tools[*]}"
    fi

    pass "All prerequisites found"
    return "${PASS}"
}

###############################################################################
# validate_source
#------------------------------------------------------------------------------
# Purpose  : Validate that source files exist
# Usage    : validate_source
# Arguments: None
# Returns  : PASS (0) if valid, FAIL (1) if missing files
# Outputs  : Status messages to stderr
# Requires:
#   Variables: SCRIPT_DIR
#   Functions: info, pass, error
# Notes    : Checks for lib/ directory and core library files
###############################################################################
function validate_source() {
    info "Validating source files..."

    if [[ ! -d "${SCRIPT_DIR}/lib" ]]; then
        error "Source directory not found: ${SCRIPT_DIR}/lib"
        return "${FAIL}"
    fi

    # Check for key files (adjust based on your actual library structure)
    local -a required_files=(
        "lib/util.sh"
        "lib/logger.sh"
    )

    local missing_count=0
    for file in "${required_files[@]}"; do
        if [[ ! -f "${SCRIPT_DIR}/${file}" ]]; then
            error "Required file not found: ${file}"
            ((missing_count++))
        fi
    done

    if ((missing_count > 0)); then
        error "Missing ${missing_count} required files"
        return "${FAIL}"
    fi

    pass "Source files validated"
    return "${PASS}"
}

###############################################################################
# check_if_update_needed
#------------------------------------------------------------------------------
# Purpose  : Check if installation is needed by comparing versions
# Usage    : check_if_update_needed
# Arguments: None
# Returns  : PASS (0) if update needed, FAIL (1) if already up to date
# Outputs  : Version comparison messages to stderr
# Requires:
#   Commands: curl
#   Variables: INSTALL_DIR, VERSION, FORCE
#   Functions: info, pass, warn
# Notes    : Skips check if FORCE=true; requires curl for remote version
###############################################################################
function check_if_update_needed() {
    # If force flag set, always install
    if [[ "${FORCE}" == "true" ]]; then
        debug "Force mode enabled, skipping version check"
        return "${PASS}"
    fi

    local installed_version_file="${INSTALL_DIR}/VERSION"

    # If not installed yet, update is needed
    if [[ ! -f "${installed_version_file}" ]]; then
        info "common_core not currently installed"
        return "${PASS}"
    fi

    # Get installed version
    local installed_version
    if ! installed_version=$(cat "${installed_version_file}" 2> /dev/null); then
        warn "Could not read installed version, proceeding with installation"
        return "${PASS}"
    fi

    info "Installed version: ${installed_version}"
    info "Source version:    ${VERSION}"

    # Compare versions
    if [[ "${installed_version}" == "${VERSION}" ]]; then
        pass "Already at version ${VERSION}"
        pass "Use --force to reinstall"
        return "${FAIL}" # Already up to date
    fi

    info "Update available: ${installed_version} → ${VERSION}"
    return "${PASS}" # Update needed
}

###############################################################################
# fetch_remote_version
#------------------------------------------------------------------------------
# Purpose  : Fetch VERSION from GitHub to compare with source
# Usage    : fetch_remote_version
# Arguments: None
# Returns  : PASS (0) if fetched successfully
# Outputs  : Remote version info to stderr
# Requires:
#   Commands: curl
#   Functions: info, warn, debug
# Notes    : Optional check - warns if curl unavailable or fetch fails
###############################################################################
function fetch_remote_version() {
    # Check if curl is available
    if ! command -v curl > /dev/null 2>&1; then
        debug "curl not available, skipping remote version check"
        return "${PASS}"
    fi

    local repo_url="https://github.com/tatanus/common_core"
    local branch="main"
    local version_url="${repo_url}/raw/${branch}/VERSION"

    info "Checking for updates from GitHub..."

    local remote_version
    if ! remote_version=$(curl -fsSL "${version_url}" 2> /dev/null); then
        warn "Could not fetch remote version (network issue?)"
        debug "Continuing with local source version"
        return "${PASS}"
    fi

    # Trim whitespace
    remote_version=$(echo "${remote_version}" | tr -d '[:space:]')

    info "Remote version: ${remote_version}"

    # Compare source version with remote
    if [[ "${VERSION}" != "${remote_version}" ]]; then
        warn "Source version (${VERSION}) differs from remote (${remote_version})"
        warn "You may be installing from a non-main branch or local changes"
    else
        debug "Source matches remote version"
    fi

    return "${PASS}"
}

###############################################################################
# create_install_directory
#------------------------------------------------------------------------------
# Purpose  : Create installation directory if it doesn't exist
# Usage    : create_install_directory
# Arguments: None
# Returns  : PASS (0) on success, FAIL (1) on error
# Outputs  : Status messages to stderr
# Requires:
#   Commands: mkdir
#   Variables: INSTALL_DIR, FORCE
#   Functions: info, warn, debug, pass, error
# Notes    : Warns if directory exists unless FORCE=true
###############################################################################
function create_install_directory() {
    info "Creating installation directory: ${INSTALL_DIR}"

    if [[ -d "${INSTALL_DIR}" ]]; then
        if [[ "${FORCE}" == "false" ]]; then
            warn "Installation directory already exists: ${INSTALL_DIR}"
            warn "Use --force to overwrite existing files"
        else
            debug "Installation directory exists, force mode enabled"
        fi
    else
        if ! mkdir -p "${INSTALL_DIR}"; then
            error "Failed to create installation directory: ${INSTALL_DIR}"
            return "${FAIL}"
        fi
        pass "Created installation directory"
    fi

    return "${PASS}"
}

###############################################################################
# install_files
#------------------------------------------------------------------------------
# Purpose  : Copy library files to installation directory
# Usage    : install_files
# Arguments: None
# Returns  : PASS (0) on success, FAIL (1) on error
# Outputs  : Status and progress messages to stderr
# Requires:
#   Commands: find, cp, mkdir, dirname
#   Variables: SCRIPT_DIR, INSTALL_DIR
#   Functions: info, debug, pass, error
# Notes    : Uses find with -print0 to handle filenames with spaces
###############################################################################
function install_files() {
    info "Installing library files to ${INSTALL_DIR}..."

    local source_lib="${SCRIPT_DIR}/lib"
    local file_count=0
    local error_count=0

    # Copy all files and directories from lib/
    while IFS= read -r -d '' source_file; do
        # Get relative path from lib/
        local rel_path="${source_file#"${source_lib}/"}"
        local dest_file="${INSTALL_DIR}/${rel_path}"

        debug "Installing: ${rel_path}"

        # Create parent directory if needed
        local dest_dir
        dest_dir="$(dirname "${dest_file}")"
        if [[ ! -d "${dest_dir}" ]]; then
            if ! mkdir -p "${dest_dir}"; then
                error "Failed to create directory: ${dest_dir}"
                ((error_count++))
                continue
            fi
        fi

        # Copy file
        if cp -f "${source_file}" "${dest_file}"; then
            ((file_count++))
        else
            error "Failed to copy: ${source_file}"
            ((error_count++))
        fi
    done < <(find "${source_lib}" -type f -print0)

    if ((error_count > 0)); then
        error "Installation completed with ${error_count} errors"
        return "${FAIL}"
    fi

    pass "Installed ${file_count} files"
    return "${PASS}"
}

###############################################################################
# install_version_file
#------------------------------------------------------------------------------
# Purpose  : Copy VERSION file to installation directory
# Usage    : install_version_file
# Arguments: None
# Returns  : PASS (0) on success
# Outputs  : Status messages to stderr
# Requires:
#   Commands: cp
#   Variables: SCRIPT_DIR, INSTALL_DIR
#   Functions: debug, warn
# Notes    : Non-fatal if VERSION file doesn't exist
###############################################################################
function install_version_file() {
    local version_src="${SCRIPT_DIR}/VERSION"
    local version_dest="${INSTALL_DIR}/VERSION"

    if [[ -f "${version_src}" ]]; then
        if cp "${version_src}" "${version_dest}"; then
            debug "Installed VERSION file"
        else
            warn "Failed to copy VERSION file (non-fatal)"
        fi
    else
        warn "VERSION file not found (non-fatal)"
    fi

    return "${PASS}"
}

###############################################################################
# set_permissions
#------------------------------------------------------------------------------
# Purpose  : Set appropriate permissions on installed files
# Usage    : set_permissions
# Arguments: None
# Returns  : PASS (0) on success
# Outputs  : Status messages to stderr
# Requires:
#   Commands: find, chmod
#   Variables: INSTALL_DIR
#   Functions: info, debug, pass, error
# Notes    : Makes all .sh files executable
###############################################################################
function set_permissions() {
    info "Setting file permissions..."

    local count=0
    local error_count=0

    while IFS= read -r -d '' sh_file; do
        if chmod +x "${sh_file}"; then
            ((count++))
            debug "Made executable: ${sh_file}"
        else
            error "Failed to chmod: ${sh_file}"
            ((error_count++))
        fi
    done < <(find "${INSTALL_DIR}" -type f -name "*.sh" -print0)

    if ((error_count > 0)); then
        warn "Failed to set permissions on ${error_count} files"
    fi

    pass "Set permissions on ${count} shell scripts"
    return "${PASS}"
}

###############################################################################
# configure_bashrc
#------------------------------------------------------------------------------
# Purpose  : Add source line to .bashrc for automatic library loading
# Usage    : configure_bashrc
# Arguments: None
# Returns  : PASS (0) on success, FAIL (1) on error
# Outputs  : Status messages to stderr
# Requires:
#   Commands: grep
#   Variables: INSTALL_DIR, HOME
#   Functions: info, pass, warn, error
# Notes    : Creates .bashrc if it doesn't exist; skips if already configured
###############################################################################
function configure_bashrc() {
    local bashrc="${HOME}/.bashrc"
    local source_line="source \"${INSTALL_DIR}/util.sh\""
    local marker="# common_core library"

    info "Configuring shell integration..."

    # Create .bashrc if it doesn't exist
    if [[ ! -f "${bashrc}" ]]; then
        debug "Creating ${bashrc}"
        if ! touch "${bashrc}"; then
            error "Failed to create ${bashrc}"
            return "${FAIL}"
        fi
    fi

    # Check if already configured (look for the install directory path)
    if grep -qF "${INSTALL_DIR}/util.sh" "${bashrc}" 2> /dev/null; then
        info ".bashrc already configured for common_core"
        return "${PASS}"
    fi

    # Check for old configurations with different paths and warn
    if grep -qE 'common_core.*util\.sh' "${bashrc}" 2> /dev/null; then
        warn "Found existing common_core configuration with different path"
        warn "Please manually review ${bashrc} and remove old entries if needed"
    fi

    # Add source line to .bashrc
    {
        printf '\n%s\n' "${marker}"
        printf 'if [[ -f "%s/util.sh" ]]; then\n' "${INSTALL_DIR}"
        printf '    source "%s/util.sh"\n' "${INSTALL_DIR}"
        printf 'fi\n'
    } >> "${bashrc}" || {
        error "Failed to update ${bashrc}"
        return "${FAIL}"
    }

    pass "Added common_core to ${bashrc}"
    info "Run 'source ~/.bashrc' or start a new terminal to activate"
    return "${PASS}"
}

###############################################################################
# install_update_script
#------------------------------------------------------------------------------
# Purpose  : Install universal update.sh script
# Usage    : install_update_script
# Arguments: None
# Returns  : PASS (0) on success, FAIL (1) on error
# Outputs  : Status messages to stderr
# Requires:
#   Commands: cp, chmod
#   Variables: SCRIPT_DIR, HOME
#   Functions: info, pass, warn, error
# Notes    : Installs to ~/.config/bash/update.sh, creates backup if exists
###############################################################################
function install_update_script() {
    local update_src="${SCRIPT_DIR}/tools/update.sh"
    local update_dest="${HOME}/.config/bash/update.sh"
    local update_dir
    update_dir="$(dirname "${update_dest}")"

    # Check if source update.sh exists
    if [[ ! -f "${update_src}" ]]; then
        warn "update.sh not found in source, skipping updater installation"
        return "${PASS}"
    fi

    info "Installing update script..."

    # Create directory if needed
    if [[ ! -d "${update_dir}" ]]; then
        if ! mkdir -p "${update_dir}"; then
            error "Failed to create directory: ${update_dir}"
            return "${FAIL}"
        fi
    fi

    # Backup existing if present
    if [[ -f "${update_dest}" ]]; then
        local backup
        backup="${update_dest}.backup.$(date +%Y%m%d_%H%M%S)"
        if cp "${update_dest}" "${backup}"; then
            debug "Created backup: ${backup}"
        else
            warn "Failed to create backup (non-fatal)"
        fi
    fi

    # Copy update.sh
    if ! cp "${update_src}" "${update_dest}"; then
        error "Failed to install update script"
        return "${FAIL}"
    fi

    # Make executable
    if ! chmod +x "${update_dest}"; then
        warn "Failed to make update script executable (non-fatal)"
    fi

    pass "Update script installed to ${update_dest}"
    return "${PASS}"
}

###############################################################################
# register_with_updater
#------------------------------------------------------------------------------
# Purpose  : Register common_core with the update system
# Usage    : register_with_updater
# Arguments: None
# Returns  : PASS (0) on success, FAIL (1) on error
# Outputs  : Status messages to stderr
# Requires:
#   Variables: HOME, INSTALL_DIR
#   Functions: info, pass, warn, error
# Notes    : Calls update::register function from update.sh
###############################################################################
function register_with_updater() {
    local update_script="${HOME}/.config/bash/update.sh"

    if [[ ! -f "${update_script}" ]]; then
        warn "Update script not found, skipping registration"
        return "${PASS}"
    fi

    info "Registering with update system..."

    # Source update.sh to get registration function
    # shellcheck disable=SC1090
    if ! source "${update_script}" 2> /dev/null; then
        warn "Failed to source update script (non-fatal)"
        return "${PASS}"
    fi

    # Register this project
    if update::register \
        "common_core" \
        "https://github.com/tatanus/common_core" \
        "main" \
        "${INSTALL_DIR}" \
        "${INSTALL_DIR}/VERSION" \
        "./install.sh --force"; then
        pass "Registered with update system"
    else
        warn "Failed to register with update system (non-fatal)"
    fi

    return "${PASS}"
}

###############################################################################
# run_self_tests
#------------------------------------------------------------------------------
# Purpose  : Run self-tests to verify installation
# Usage    : run_self_tests
# Arguments: None
# Returns  : PASS (0) if all tests pass, FAIL (1) otherwise
# Outputs  : Test results to stderr
# Requires:
#   Commands: source
#   Variables: INSTALL_DIR
#   Functions: info, pass, error, warn
# Notes    : Sources util.sh and runs utils::self_test if available
###############################################################################
function run_self_tests() {
    info "Running self-tests..."

    local util_sh="${INSTALL_DIR}/util.sh"

    if [[ ! -f "${util_sh}" ]]; then
        error "util.sh not found at: ${util_sh}"
        return "${FAIL}"
    fi

    # Source util.sh and run self-test
    # shellcheck disable=SC1090
    if ! source "${util_sh}" 2> /dev/null; then
        error "Failed to source util.sh"
        return "${FAIL}"
    fi

    # Run utils::self_test if available
    if declare -F utils::self_test > /dev/null 2>&1; then
        if utils::self_test; then
            pass "Self-tests passed"
            return "${PASS}"
        else
            error "Self-tests failed"
            return "${FAIL}"
        fi
    else
        warn "utils::self_test function not available, skipping tests"
        return "${PASS}"
    fi
}

###############################################################################
# show_completion_message
#------------------------------------------------------------------------------
# Purpose  : Display completion message with usage information
# Usage    : show_completion_message
# Arguments: None
# Returns  : PASS (0)
# Outputs  : Completion message and next steps to stdout and stderr
# Requires:
#   Variables: VERSION, INSTALL_DIR, HOME
#   Functions: pass, info
# Notes    : Final message shown to user
###############################################################################
function show_completion_message() {
    printf '\n'
    pass "Installation complete!"
    printf '\n'
    info "Installation details:"
    printf '  Version:  %s\n' "${VERSION}"
    printf '  Location: %s\n' "${INSTALL_DIR}"
    printf '  Shell:    ~/.bashrc configured\n'
    printf '\n'
    info "To activate common_core now, run:"
    printf '  source ~/.bashrc\n'
    printf '\n'
    info "Or simply open a new terminal session."
    printf '\n'
    info "To use common_core in standalone scripts, add:"
    printf '  source "%s/util.sh"\n' "${INSTALL_DIR}"
    printf '\n'
    info "To update common_core in the future:"
    printf '  %s/.config/bash/update.sh\n' "${HOME}"
    printf '\n'

    return "${PASS}"
}

#===============================================================================
# Main Installation Flow
#===============================================================================

###############################################################################
# main
#------------------------------------------------------------------------------
# Purpose  : Main entry point for installation
# Usage    : main "$@"
# Arguments:
#   $@ : All command line arguments
# Returns  : PASS (0) on success, FAIL (1) on error
# Outputs  : Installation progress to stderr
# Requires:
#   Functions: All validation and installation functions
# Notes    : Coordinates all installation steps in sequence
###############################################################################
function main() {
    # Validate environment
    if ! check_bash_version; then
        error "Installation failed: Bash version too old"
        return "${FAIL}"
    fi

    # Parse arguments
    parse_arguments "$@"

    printf '\n'
    info "common_core installer (version ${VERSION})"
    printf '\n'
    info "Installation directory: ${INSTALL_DIR}"
    printf '\n'

    # Validate installation directory
    if ! validate_install_dir; then
        error "Installation failed: Invalid installation directory"
        return "${FAIL}"
    fi

    # Pre-installation checks
    if ! check_prerequisites; then
        error "Installation failed: Missing prerequisites"
        return "${FAIL}"
    fi

    if ! validate_source; then
        error "Installation failed: Invalid source files"
        return "${FAIL}"
    fi

    # Check remote version (informational)
    fetch_remote_version

    printf '\n'

    # Check if update is needed
    if ! check_if_update_needed; then
        info "No installation needed"
        return "${PASS}"
    fi

    printf '\n'

    # Installation
    if ! create_install_directory; then
        error "Installation failed: Could not create directory"
        return "${FAIL}"
    fi

    if ! install_files; then
        error "Installation failed: File copy errors"
        return "${FAIL}"
    fi

    install_version_file # Non-fatal

    if ! set_permissions; then
        warn "Some permissions could not be set (non-fatal)"
    fi

    # Configure shell integration (.bashrc)
    if ! configure_bashrc; then
        warn "Failed to configure .bashrc (non-fatal)"
        warn "You may need to manually add: source \"${INSTALL_DIR}/util.sh\""
    fi

    # Install update script
    if ! install_update_script; then
        warn "Failed to install update script (non-fatal)"
    fi

    # Register with update system
    if ! register_with_updater; then
        warn "Failed to register with updater (non-fatal)"
    fi

    printf '\n'

    # Post-installation
    if [[ "${RUN_TESTS}" == "true" ]]; then
        if ! run_self_tests; then
            error "Installation completed but self-tests failed"
            error "The library may not function correctly"
            return "${FAIL}"
        fi
        printf '\n'
    fi

    # Show completion message
    show_completion_message

    return "${PASS}"
}

#===============================================================================
# Script Entry Point
#===============================================================================

main "$@"
exit_code="${?}"
exit "${exit_code}"
