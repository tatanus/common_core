#!/usr/bin/env bash
###############################################################################
# NAME         : update.sh
# DESCRIPTION  : Auto-discovering updater for Bash projects
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-01-04
###############################################################################
# EDIT HISTORY:
# DATE       | EDITED BY    | DESCRIPTION
# -----------|--------------|-----------------------------------------------
# 2025-01-04 | Adam Compton | Initial creation with auto-discovery
# 2026-01-09 | Claude       | SECURITY: Replaced unsafe eval with safe path
#            |              | expansion function (expand_path)
###############################################################################
# USAGE:
#   Projects automatically register themselves during installation.
#   No manual editing required - just install projects and they'll update!
#
# REGISTRY:
#   Location: ~/.config/bash/update-registry
#   Format: name|repo_url|branch|install_dir|version_file|install_cmd
#
# ADDING PROJECTS:
#   Projects add themselves automatically via:
#     update::register "name" "repo_url" "branch" "install_dir" "version_file" "install_cmd"
#
#   Or manually:
#     ~/.config/bash/update.sh --register "my_tool" \
#         "https://github.com/user/my_tool" \
#         "main" \
#         "${HOME}/.local/bin" \
#         "${HOME}/.local/bin/VERSION" \
#         "./install.sh --force"
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Global Constants
#===============================================================================
readonly PASS=0
readonly FAIL=1
readonly REQUIRED_BASH_VERSION=4

# Registry location
readonly REGISTRY_FILE="${HOME}/.config/bash/update-registry"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Flags
VERBOSE=false
DRY_RUN=false
UPDATE_ALL=true
SKIP_TESTS=false
REGISTER_PROJECT=false
UNREGISTER_PROJECT=false
LIST_PROJECTS=false

# Registration parameters
REGISTER_NAME=""
REGISTER_REPO=""
REGISTER_BRANCH=""
REGISTER_INSTALL_DIR=""
REGISTER_VERSION_FILE=""
REGISTER_INSTALL_CMD=""

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
# Path Expansion (Security-Safe)
#===============================================================================

###############################################################################
# expand_path
#------------------------------------------------------------------------------
# Purpose  : Safely expand ~ and common environment variables in paths
# Usage    : expanded=$(expand_path "~/path/${HOME}/file")
# Arguments:
#   $1 : Path string to expand
# Returns  : Expanded path on stdout
# Security : Does NOT use eval - only expands known safe patterns
###############################################################################
function expand_path() {
    local path="${1:-}"

    # Expand leading ~ to HOME
    # shellcheck disable=SC2088
    if [[ "${path}" == "~" ]]; then
        path="${HOME}"
    elif [[ "${path}" == "~/"* ]]; then
        path="${HOME}/${path:2}"
    fi

    # Expand ${HOME} and $HOME patterns
    path="${path//\$\{HOME\}/${HOME}}"
    path="${path//\$HOME/${HOME}}"

    # Expand ${USER} and $USER patterns
    path="${path//\$\{USER\}/${USER:-}}"
    path="${path//\$USER/${USER:-}}"

    printf '%s' "${path}"
}

#===============================================================================
# Validation Functions
#===============================================================================

###############################################################################
# check_bash_version
#------------------------------------------------------------------------------
# Purpose  : Verify Bash version meets minimum requirements
# Returns  : PASS if version OK, FAIL otherwise
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
# check_prerequisites
#------------------------------------------------------------------------------
# Purpose  : Check for required tools
# Returns  : PASS if all found, FAIL otherwise
###############################################################################
function check_prerequisites() {
    info "Checking prerequisites..."

    local -a missing_tools=()
    local -a required_cmds=(git curl)

    for tool in "${required_cmds[@]}"; do
        if ! command -v "${tool}" > /dev/null 2>&1; then
            missing_tools+=("${tool}")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        error "Missing required tools: ${missing_tools[*]}"
        error "Install with: sudo apt-get install ${missing_tools[*]}"
        return "${FAIL}"
    fi

    pass "All prerequisites found"
    return "${PASS}"
}

#===============================================================================
# Registry Management
#===============================================================================

###############################################################################
# registry::init
#------------------------------------------------------------------------------
# Purpose  : Initialize registry file if it doesn't exist
# Returns  : PASS
###############################################################################
function registry::init() {
    local registry_dir
    registry_dir="$(dirname "${REGISTRY_FILE}")"

    if [[ ! -d "${registry_dir}" ]]; then
        mkdir -p "${registry_dir}" || {
            error "Failed to create registry directory: ${registry_dir}"
            return "${FAIL}"
        }
    fi

    if [[ ! -f "${REGISTRY_FILE}" ]]; then
        cat > "${REGISTRY_FILE}" << 'EOF'
# Bash Project Update Registry
# Format: name|repo_url|branch|install_dir|version_file|install_cmd
# Lines starting with # are ignored
# DO NOT edit manually - use: update.sh --register or project installers
EOF
        debug "Created registry file: ${REGISTRY_FILE}"
    fi

    return "${PASS}"
}

###############################################################################
# registry::add
#------------------------------------------------------------------------------
# Purpose  : Add or update a project in the registry
# Arguments:
#   $1 : Project name
#   $2 : Repository URL
#   $3 : Branch name
#   $4 : Installation directory
#   $5 : Version file path
#   $6 : Installation command
# Returns  : PASS on success, FAIL on error
###############################################################################
function registry::add() {
    local name="${1}"
    local repo="${2}"
    local branch="${3}"
    local install_dir="${4}"
    local version_file="${5}"
    local install_cmd="${6:-}"

    # Validate inputs
    if [[ -z "${name}" ]] || [[ -z "${repo}" ]] || [[ -z "${branch}" ]]; then
        error "Missing required arguments for registry::add"
        return "${FAIL}"
    fi

    # Initialize registry if needed
    registry::init || return "${FAIL}"

    # Remove existing entry if present
    registry::remove "${name}" 2> /dev/null || true

    # Add new entry
    local entry="${name}|${repo}|${branch}|${install_dir}|${version_file}|${install_cmd}"
    echo "${entry}" >> "${REGISTRY_FILE}"

    debug "Added to registry: ${name}"
    return "${PASS}"
}

###############################################################################
# registry::remove
#------------------------------------------------------------------------------
# Purpose  : Remove a project from the registry
# Arguments:
#   $1 : Project name
# Returns  : PASS on success, FAIL if not found
###############################################################################
function registry::remove() {
    local name="${1}"

    if [[ ! -f "${REGISTRY_FILE}" ]]; then
        warn "Registry file does not exist"
        return "${FAIL}"
    fi

    local temp_file
    temp_file="$(mktemp)"

    # Copy all lines except the one to remove
    if grep -v "^${name}|" "${REGISTRY_FILE}" > "${temp_file}"; then
        mv "${temp_file}" "${REGISTRY_FILE}"
        debug "Removed from registry: ${name}"
        return "${PASS}"
    else
        rm -f "${temp_file}"
        warn "Project not found in registry: ${name}"
        return "${FAIL}"
    fi
}

###############################################################################
# registry::list
#------------------------------------------------------------------------------
# Purpose  : List all registered projects
# Returns  : PASS
###############################################################################
function registry::list() {
    if [[ ! -f "${REGISTRY_FILE}" ]]; then
        info "No projects registered yet"
        return "${PASS}"
    fi

    info "Registered projects:"
    printf '\n'

    local count=0
    while IFS='|' read -r name repo branch install_dir version_file install_cmd; do
        # Skip comments and empty lines
        [[ "${name}" =~ ^#.*$ ]] && continue
        [[ -z "${name}" ]] && continue

        ((count++))
        printf '  %s\n' "${name}"
        printf '    Repository: %s\n' "${repo}"
        printf '    Branch:     %s\n' "${branch}"
        printf '    Location:   %s\n' "${install_dir}"

        # Show version if available
        if [[ -f "${version_file}" ]]; then
            local version
            version="$(cat "${version_file}" 2> /dev/null || echo "unknown")"
            printf '    Version:    %s\n' "${version}"
        fi
        printf '\n'
    done < "${REGISTRY_FILE}"

    if ((count == 0)); then
        info "No projects registered yet"
    else
        pass "Total: ${count} project(s)"
    fi

    return "${PASS}"
}

###############################################################################
# registry::read
#------------------------------------------------------------------------------
# Purpose  : Read all registered projects into arrays
# Returns  : PASS on success
# Notes    : Sets global arrays: PROJECT_NAMES, PROJECT_REPOS, etc.
###############################################################################
function registry::read() {
    # Initialize arrays
    PROJECT_NAMES=()
    PROJECT_REPOS=()
    PROJECT_BRANCHES=()
    PROJECT_INSTALL_DIRS=()
    PROJECT_VERSION_FILES=()
    PROJECT_INSTALL_CMDS=()

    if [[ ! -f "${REGISTRY_FILE}" ]]; then
        debug "Registry file does not exist yet"
        return "${PASS}"
    fi

    while IFS='|' read -r name repo branch install_dir version_file install_cmd; do
        # Skip comments and empty lines
        [[ "${name}" =~ ^#.*$ ]] && continue
        [[ -z "${name}" ]] && continue

        PROJECT_NAMES+=("${name}")
        PROJECT_REPOS+=("${repo}")
        PROJECT_BRANCHES+=("${branch}")
        PROJECT_INSTALL_DIRS+=("${install_dir}")
        PROJECT_VERSION_FILES+=("${version_file}")
        PROJECT_INSTALL_CMDS+=("${install_cmd}")
    done < "${REGISTRY_FILE}"

    debug "Read ${#PROJECT_NAMES[@]} projects from registry"
    return "${PASS}"
}

#===============================================================================
# Usage and Argument Parsing
#===============================================================================

###############################################################################
# usage
#------------------------------------------------------------------------------
# Purpose  : Display usage information
# Returns  : PASS
###############################################################################
function usage() {
    cat << EOF
Usage: ${0##*/} [OPTIONS] [PROJECT...]

Auto-discovering updater for Bash projects

OPTIONS:
    -a, --all                  Update all registered projects (default)
    -n, --dry-run              Show what would be updated without updating
    -s, --skip-tests           Skip self-tests during installation
    -v, --verbose              Enable verbose output
    -h, --help                 Display this help message

REGISTRY MANAGEMENT:
    -l, --list                 List all registered projects
    -r, --register NAME REPO BRANCH DIR VERSION_FILE [CMD]
                               Register a new project
    -u, --unregister NAME      Unregister a project

PROJECTS:
    If no project specified, updates all registered projects.
    Otherwise, only updates specified projects.

EXAMPLES:
    ${0##*/}                           # Update all registered projects
    ${0##*/} --list                    # Show registered projects
    ${0##*/} common_core               # Update only common_core
    ${0##*/} --dry-run                 # Preview updates

    # Register a new project
    ${0##*/} --register my_tool \\
        "https://github.com/user/my_tool" \\
        "main" \\
        "\${HOME}/.local/bin" \\
        "\${HOME}/.local/bin/VERSION" \\
        "./install.sh --force"

    # Unregister a project
    ${0##*/} --unregister my_tool

DESCRIPTION:
    This script automatically discovers and updates registered Bash projects.
    Projects register themselves during installation - no manual editing needed!

    The registry is stored at: ${REGISTRY_FILE}

    When you install a Bash project, it automatically adds itself to the
    registry. Running this script will then update all registered projects.

AUTO-REGISTRATION:
    Project installers should call:
      source ~/.config/bash/update.sh
      update::register "project_name" "repo_url" "branch" "install_dir" "version_file" "install_cmd"

EOF
    return "${PASS}"
}

###############################################################################
# parse_arguments
#------------------------------------------------------------------------------
# Purpose  : Parse command line arguments
# Returns  : PASS on success, exits on error
###############################################################################
function parse_arguments() {
    local -a projects=()

    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -a | --all)
                UPDATE_ALL=true
                shift
                ;;
            -n | --dry-run)
                DRY_RUN=true
                shift
                ;;
            -s | --skip-tests)
                SKIP_TESTS=true
                shift
                ;;
            -v | --verbose)
                VERBOSE=true
                shift
                ;;
            -l | --list)
                LIST_PROJECTS=true
                shift
                ;;
            -r | --register)
                REGISTER_PROJECT=true
                if [[ -z "${2:-}" ]]; then
                    error "--register requires: NAME REPO BRANCH DIR VERSION_FILE [CMD]"
                    exit "${FAIL}"
                fi
                REGISTER_NAME="${2}"
                REGISTER_REPO="${3:-}"
                REGISTER_BRANCH="${4:-}"
                REGISTER_INSTALL_DIR="${5:-}"
                REGISTER_VERSION_FILE="${6:-}"
                REGISTER_INSTALL_CMD="${7:-}"
                shift 7 || shift $#
                ;;
            -u | --unregister)
                UNREGISTER_PROJECT=true
                if [[ -z "${2:-}" ]]; then
                    error "--unregister requires project name"
                    exit "${FAIL}"
                fi
                REGISTER_NAME="${2}"
                shift 2
                ;;
            -h | --help)
                usage
                exit "${PASS}"
                ;;
            -*)
                error "Unknown option: ${1}"
                usage
                exit "${FAIL}"
                ;;
            *)
                # Project name
                projects+=("${1}")
                UPDATE_ALL=false
                shift
                ;;
        esac
    done

    # Export selected projects if any specified
    if [[ ${#projects[@]} -gt 0 ]]; then
        SELECTED_PROJECTS=("${projects[@]}")
    fi

    return "${PASS}"
}

#===============================================================================
# Generic Update Framework
#===============================================================================

###############################################################################
# update_repo_generic
#------------------------------------------------------------------------------
# Purpose  : Generic function to update a repository-based tool
# Arguments:
#   $1 : Repository name
#   $2 : GitHub repository URL
#   $3 : Branch name
#   $4 : Local installation directory
#   $5 : Local version file path
#   $6 : Post-install command (optional)
# Returns  : PASS on success, FAIL on error
###############################################################################
function update_repo_generic() {
    local repo_name="${1}"
    local repo_url="${2}"
    local branch="${3:-main}"
    local install_dir="${4}"
    local local_version_file="${5}"
    local post_install_cmd="${6:-}"

    info "Checking ${repo_name} for updates..."

    # Expand variables in paths (SECURITY: no eval)
    install_dir=$(expand_path "${install_dir}")
    local_version_file=$(expand_path "${local_version_file}")

    # Construct version URL
    local version_url="${repo_url}/raw/${branch}/VERSION"

    # Get local version
    local local_version="not installed"
    if [[ -f "${local_version_file}" ]]; then
        if ! local_version=$(cat "${local_version_file}" 2> /dev/null); then
            local_version="unknown"
        fi
    fi

    info "  Current version: ${local_version}"

    # Get remote version
    local remote_version
    if ! remote_version=$(curl -fsSL "${version_url}" 2> /dev/null); then
        error "  Failed to fetch remote version from ${version_url}"
        return "${FAIL}"
    fi

    # Trim whitespace
    remote_version=$(echo "${remote_version}" | tr -d '[:space:]')

    info "  Latest version:  ${remote_version}"

    # Compare versions
    if [[ "${local_version}" == "${remote_version}" ]]; then
        pass "  ${repo_name} is up to date (${local_version})"
        debug "  No update needed - skipping download"
        return "${PASS}"
    fi

    # Version check passed - update is needed
    if [[ "${local_version}" == "not installed" ]]; then
        info "  ${repo_name} not currently installed"
        info "  Will install version: ${remote_version}"
    else
        info "  Update available: ${local_version} → ${remote_version}"
    fi

    # Dry-run mode
    if [[ "${DRY_RUN}" == "true" ]]; then
        info "  [DRY-RUN] Would download and install ${repo_name} ${remote_version}"
        return "${PASS}"
    fi

    # Create temporary directory with cleanup trap
    local temp_dir
    temp_dir=$(mktemp -d) || {
        error "  Failed to create temporary directory"
        return "${FAIL}"
    }

    # Set up cleanup trap
    trap 'rm -rf "${temp_dir}"' EXIT

    # Clone repository
    info "  Downloading ${repo_name}..."
    if ! git clone --depth 1 --branch "${branch}" --quiet "${repo_url}" "${temp_dir}/${repo_name}" 2> /dev/null; then
        error "  Failed to clone repository"
        rm -rf "${temp_dir}"
        trap - EXIT
        return "${FAIL}"
    fi

    # Run post-install command if specified
    if [[ -n "${post_install_cmd}" ]]; then
        info "  Installing update..."

        # Build command array
        local -a cmd_array=()
        IFS=' ' read -ra cmd_array <<< "${post_install_cmd}"

        # Add --force (we've already checked versions in update.sh)
        if [[ "${post_install_cmd}" != *"--force"* ]]; then
            cmd_array+=(--force)
            debug "  Added --force flag (version already verified)"
        fi

        # Add --skip-tests if global flag set
        if [[ "${SKIP_TESTS}" == "true" ]] && [[ "${post_install_cmd}" != *"--skip-tests"* ]]; then
            cmd_array+=(--skip-tests)
            debug "  Added --skip-tests flag"
        fi

        debug "  Running: ${cmd_array[*]}"

        # Execute from the cloned directory
        if (cd "${temp_dir}/${repo_name}" && "${cmd_array[@]}" 2>&1 | sed 's/^/    /'); then
            pass "  Updated ${repo_name} to ${remote_version}"
            rm -rf "${temp_dir}"
            trap - EXIT
            return "${PASS}"
        else
            error "  Installation failed"
            rm -rf "${temp_dir}"
            trap - EXIT
            return "${FAIL}"
        fi
    else
        # Manual installation - just copy files
        info "  Copying files to ${install_dir}..."
        if cp -rf "${temp_dir}/${repo_name}/"* "${install_dir}/"; then
            pass "  Updated ${repo_name} to ${remote_version}"
            rm -rf "${temp_dir}"
            trap - EXIT
            return "${PASS}"
        else
            error "  Failed to copy files"
            rm -rf "${temp_dir}"
            trap - EXIT
            return "${FAIL}"
        fi
    fi
}

###############################################################################
# should_update_project
#------------------------------------------------------------------------------
# Purpose  : Determine if a project should be updated
# Arguments:
#   $1 : Project name
# Returns  : PASS if should update, FAIL if should skip
###############################################################################
function should_update_project() {
    local project_name="${1}"

    # If updating all, always return PASS
    if [[ "${UPDATE_ALL}" == "true" ]]; then
        return "${PASS}"
    fi

    # Check if project is in selected list
    for selected in "${SELECTED_PROJECTS[@]}"; do
        if [[ "${selected}" == "${project_name}" ]]; then
            return "${PASS}"
        fi
    done

    return "${FAIL}"
}

#===============================================================================
# Public API for Project Installers
#===============================================================================

###############################################################################
# update::register
#------------------------------------------------------------------------------
# Purpose  : Public API for projects to register themselves
# Usage    : update::register "name" "repo" "branch" "dir" "version" "cmd"
# Returns  : PASS on success
# Notes    : This function is called by project installers
###############################################################################
function update::register() {
    registry::add "$@"
    return "${?}"
}

###############################################################################
# update::unregister
#------------------------------------------------------------------------------
# Purpose  : Public API for projects to unregister themselves
# Usage    : update::unregister "name"
# Returns  : PASS on success
# Notes    : This function is called by project uninstallers
###############################################################################
function update::unregister() {
    registry::remove "$@"
    return "${?}"
}

#===============================================================================
# Self-Update Functionality
#===============================================================================

###############################################################################
# self_update_check
#------------------------------------------------------------------------------
# Purpose  : Check if update.sh itself needs updating
# Returns  : PASS on success
# Notes    : Checks if common_core has newer update.sh and updates if needed
###############################################################################
function self_update_check() {
    local update_script="${BASH_SOURCE[0]}"
    local common_core_lib="${HOME}/.config/bash/lib"
    local source_update="${common_core_lib}/update.sh"

    # Only check if we're the installed version
    if [[ "${update_script}" != "${HOME}/.config/bash/update.sh" ]]; then
        debug "Not running from installed location, skipping self-update"
        return "${PASS}"
    fi

    # Check if common_core is installed
    if [[ ! -d "${common_core_lib}" ]]; then
        debug "common_core not installed, skipping self-update"
        return "${PASS}"
    fi

    # Check if source update.sh exists
    if [[ ! -f "${source_update}" ]]; then
        debug "No update.sh in common_core installation"
        return "${PASS}"
    fi

    # Compare files (simple diff check)
    if cmp -s "${update_script}" "${source_update}"; then
        debug "update.sh is up to date"
        return "${PASS}"
    fi

    info "Newer version of update.sh detected in common_core"
    info "Self-updating update.sh..."

    # Backup current version
    local backup
    backup="${update_script}.backup.$(date +%Y%m%d_%H%M%S)"
    if cp "${update_script}" "${backup}"; then
        debug "Created backup: ${backup}"
    else
        warn "Failed to create backup (non-fatal)"
    fi

    # Copy new version
    if cp "${source_update}" "${update_script}"; then
        pass "Successfully self-updated update.sh"
        info "Restart recommended: ~/.config/bash/update.sh"
        return "${PASS}"
    else
        error "Failed to self-update (continuing with current version)"
        return "${FAIL}"
    fi
}

#===============================================================================
# Main Update Logic
#===============================================================================

###############################################################################
# main
#------------------------------------------------------------------------------
# Purpose  : Main entry point
# Returns  : PASS on success, FAIL on error
###############################################################################
function main() {
    # Validate environment
    if ! check_bash_version; then
        return "${FAIL}"
    fi

    # Parse arguments
    parse_arguments "$@"

    # Handle registry management
    if [[ "${LIST_PROJECTS}" == "true" ]]; then
        registry::list
        return "${PASS}"
    fi

    if [[ "${REGISTER_PROJECT}" == "true" ]]; then
        info "Registering project: ${REGISTER_NAME}"
        if registry::add "${REGISTER_NAME}" "${REGISTER_REPO}" "${REGISTER_BRANCH}" \
            "${REGISTER_INSTALL_DIR}" "${REGISTER_VERSION_FILE}" \
            "${REGISTER_INSTALL_CMD}"; then
            pass "Successfully registered ${REGISTER_NAME}"
        else
            error "Failed to register ${REGISTER_NAME}"
            return "${FAIL}"
        fi
        return "${PASS}"
    fi

    if [[ "${UNREGISTER_PROJECT}" == "true" ]]; then
        info "Unregistering project: ${REGISTER_NAME}"
        if registry::remove "${REGISTER_NAME}"; then
            pass "Successfully unregistered ${REGISTER_NAME}"
        else
            error "Failed to unregister ${REGISTER_NAME}"
            return "${FAIL}"
        fi
        return "${PASS}"
    fi

    # Normal update process
    printf '\n'
    info "Bash Project Updater"

    if [[ "${DRY_RUN}" == "true" ]]; then
        warn "DRY-RUN MODE: No changes will be made"
    fi

    printf '\n'

    # Check prerequisites
    if ! check_prerequisites; then
        error "Update failed: missing required tools"
        return "${FAIL}"
    fi

    printf '\n'

    # Read registry
    if ! registry::read; then
        error "Failed to read registry"
        return "${FAIL}"
    fi

    # Check if any projects registered
    if [[ ${#PROJECT_NAMES[@]} -eq 0 ]]; then
        warn "No projects registered yet"
        info "Install Bash projects to automatically register them"
        info "Or manually register with: ${0} --register ..."
        return "${PASS}"
    fi

    info "Starting update process..."
    printf '\n'

    local error_count=0
    local update_count=0

    # Update all registered projects
    for i in "${!PROJECT_NAMES[@]}"; do
        local name="${PROJECT_NAMES[i]}"
        local repo="${PROJECT_REPOS[i]}"
        local branch="${PROJECT_BRANCHES[i]}"
        local install_dir="${PROJECT_INSTALL_DIRS[i]}"
        local version_file="${PROJECT_VERSION_FILES[i]}"
        local install_cmd="${PROJECT_INSTALL_CMDS[i]}"

        if should_update_project "${name}"; then
            if update_repo_generic "${name}" "${repo}" "${branch}" \
                "${install_dir}" "${version_file}" \
                "${install_cmd}"; then
                ((update_count++))
            else
                ((error_count++))
            fi
            printf '\n'
        fi
    done

    # Summary
    if [[ "${DRY_RUN}" == "true" ]]; then
        info "Dry-run complete"
        return "${PASS}"
    fi

    if ((error_count > 0)); then
        error "Update process completed with ${error_count} error(s)"
        return "${FAIL}"
    fi

    if ((update_count == 0)); then
        pass "All projects are up to date"
    else
        pass "Successfully updated ${update_count} project(s)"
    fi

    # Check if update.sh itself needs updating
    printf '\n'
    self_update_check

    return "${PASS}"
}

#===============================================================================
# Script Entry Point
#===============================================================================

# Only run main if script is executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit_code="${?}"
    exit "${exit_code}"
fi

# If sourced, export public API functions
export -f update::register 2> /dev/null || true
export -f update::unregister 2> /dev/null || true
