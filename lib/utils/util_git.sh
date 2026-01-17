#!/usr/bin/env bash
###############################################################################
# NAME         : util_git.sh
# DESCRIPTION  : Git operations and GitHub release utilities.
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-10-27
###############################################################################
# EDIT HISTORY:
# DATE        | EDITED BY      | DESCRIPTION
# ------------|----------------|-----------------------------------------------
# 2025-10-27  | Adam Compton   | Initial generation (style-guide compliant)
# 2025-11-20  | Adam Compton   | Integrated util_curl.sh, added structured
#                                GitHub release helpers and legacy wrappers.
# 2026-01-03  | Adam Compton   | HIGH: Added input validation for config keys
#             |                | and values, security warnings for sensitive keys.
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Library Guard
#===============================================================================
if [[ -n "${UTIL_GIT_SH_LOADED:-}" ]]; then
    if (return 0 2> /dev/null); then
        return 0
    fi
else
    UTIL_GIT_SH_LOADED=1
fi

#===============================================================================
# Module Dependencies
#===============================================================================
if [[ "${UTIL_PLATFORM_SH_LOADED:-0}" -eq 0 ]]; then
    echo "ERROR: util_platform.sh must be loaded before util_git.sh" >&2
    return 1
fi

if [[ "${UTIL_CONFIG_SH_LOADED:-0}" -eq 0 ]]; then
    echo "ERROR: util_config.sh must be loaded before util_git.sh" >&2
    return 1
fi

if [[ "${UTIL_TRAP_SH_LOADED:-0}" -eq 0 ]]; then
    echo "ERROR: util_trap.sh must be loaded before util_git.sh" >&2
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
# Globals
#===============================================================================
: "${PASS:=0}"
: "${FAIL:=1}"

#===============================================================================
# Globals
#===============================================================================
# none

#===============================================================================
# Availability
#===============================================================================

###############################################################################
# git::is_available
#------------------------------------------------------------------------------
# Purpose  : Check if git is installed and accessible.
# Usage    : git::is_available && info "git found"
# Returns  : PASS if available, FAIL otherwise.
# Requirements:
#   Functions:
#     - cmd::exists
#     - debug
###############################################################################
function git::is_available() {
    if cmd::exists git; then
        debug "git found at $(command -v git)"
        return "${PASS}"
    fi
    debug "git not installed"
    return "${FAIL}"
}

###############################################################################
# git::is_repo
#------------------------------------------------------------------------------
# Purpose  : Check if current directory is a git repository.
# Usage    : git::is_repo
# Returns  : PASS if repository detected, FAIL otherwise.
# Requirements:
#   Functions:
#     - debug
###############################################################################
function git::is_repo() {
    if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        debug "Current directory is a Git repo"
        return "${PASS}"
    fi
    debug "Not a Git repository"
    return "${FAIL}"
}

###############################################################################
# git::set_config
#------------------------------------------------------------------------------
# Purpose  : Set a git configuration value
# Usage    : git::set_config "user.name" "John Doe" [--global]
# Returns  : PASS if successful, FAIL otherwise
# Security : Validates key format, warns on security-sensitive keys
###############################################################################
function git::set_config() {
    local key="${1:-}"
    local value="${2:-}"
    local scope="${3:-}"

    if [[ -z "${key}" || -z "${value}" ]]; then
        error "Usage: git::set_config <key> <value> [--global]"
        return "${FAIL}"
    fi

    # SECURITY FIX: Validate key format (section.key or section.subsection.key)
    if ! [[ "${key}" =~ ^[a-zA-Z][a-zA-Z0-9-]*(\.[a-zA-Z][a-zA-Z0-9-]*)+$ ]]; then
        error "git::set_config: Invalid key format: ${key}"
        error "Expected format: section.key or section.subsection.key"
        return "${FAIL}"
    fi

    # SECURITY FIX: Validate scope if provided
    if [[ -n "${scope}" ]]; then
        case "${scope}" in
            --global | --local | --system | --worktree | --file | --file=*) ;;
            *)
                error "git::set_config: Invalid scope: ${scope}"
                error "Allowed: --global, --local, --system, --worktree, --file"
                return "${FAIL}"
                ;;
        esac
    fi

    # SECURITY FIX: Warn on security-sensitive configuration keys
    local -a sensitive_key_prefixes=(
        "core.gitProxy"
        "core.sshCommand"
        "credential"
        "http.proxy"
        "https.proxy"
        "filter."
        "diff.external"
        "merge.external"
        "receive.denyCurrentBranch"
        "safe.directory"
    )

    local prefix
    for prefix in "${sensitive_key_prefixes[@]}"; do
        if [[ "${key}" == "${prefix}"* ]]; then
            warn "git::set_config: Setting security-sensitive key: ${key}"
            warn "Ensure this is intentional and from trusted input"
            break
        fi
    done

    # BUILD COMMAND AS ARRAY (CORRECT METHOD)
    local -a cmd=(git config)

    # Add optional scope
    [[ -n "${scope}" ]] && cmd+=("${scope}")

    # SECURITY FIX: Add -- separator before key and value
    cmd+=("--" "${key}" "${value}")

    # Execute array (proper quoting preserved)
    if cmd::run "${cmd[@]}"; then
        pass "Git config set: ${key}=${value}"
        return "${PASS}"
    fi

    fail "Failed to set git config: ${key}"
    return "${FAIL}"
}

###############################################################################
# git::stash_save
#------------------------------------------------------------------------------
# Purpose  : Stash current changes with optional message
# Usage    : git::stash_save ["message"]
# Returns  : PASS if successful, FAIL otherwise
###############################################################################
function git::stash_save() {
    local message="${1:-WIP}"

    if ! git::is_repo; then
        error "Not in a Git repository"
        return "${FAIL}"
    fi

    if git::is_clean; then
        info "No changes to stash"
        return "${PASS}"
    fi

    if cmd::run git stash save "${message}"; then
        pass "Changes stashed: ${message}"
        return "${PASS}"
    fi

    fail "Failed to stash changes"
    return "${FAIL}"
}

###############################################################################
# git::stash_pop
#------------------------------------------------------------------------------
# Purpose  : Apply and remove most recent stash
# Usage    : git::stash_pop
# Returns  : PASS if successful, FAIL otherwise
###############################################################################
function git::stash_pop() {
    if ! git::is_repo; then
        error "Not in a Git repository"
        return "${FAIL}"
    fi

    if cmd::run git stash pop; then
        pass "Stash applied and removed"
        return "${PASS}"
    fi

    fail "Failed to pop stash"
    return "${FAIL}"
}

###############################################################################
# git::submodule_update
#------------------------------------------------------------------------------
# Purpose  : Initialize and update submodules
# Usage    : git::submodule_update
# Returns  : PASS if successful, FAIL otherwise
###############################################################################
function git::submodule_update() {
    if ! git::is_repo; then
        error "Not in a Git repository"
        return "${FAIL}"
    fi

    info "Updating git submodules..."
    if cmd::run git submodule update --init --recursive; then
        pass "Submodules updated"
        return "${PASS}"
    fi

    fail "Submodule update failed"
    return "${FAIL}"
}

###############################################################################
# git::create_branch
#------------------------------------------------------------------------------
# Purpose  : Create and checkout a new branch
# Usage    : git::create_branch "feature/new-feature"
# Returns  : PASS if successful, FAIL otherwise
###############################################################################
function git::create_branch() {
    local branch="${1:-}"

    if [[ -z "${branch}" ]]; then
        error "git::create_branch requires a branch name"
        return "${FAIL}"
    fi

    if ! git::is_repo; then
        error "Not in a Git repository"
        return "${FAIL}"
    fi

    if cmd::run git checkout -b "${branch}"; then
        pass "Created and checked out branch: ${branch}"

        # Set upstream branch name if configured
        local default_branch
        default_branch=$(config::get "git.default_branch" "main")
        info "Note: Default branch is configured as '${default_branch}'"

        return "${PASS}"
    fi

    fail "Failed to create branch: ${branch}"
    return "${FAIL}"
}

###############################################################################
# git::delete_branch
#------------------------------------------------------------------------------
# Purpose  : Delete a local branch
# Usage    : git::delete_branch "feature/old-feature" [--force]
# Returns  : PASS if successful, FAIL otherwise
###############################################################################
function git::delete_branch() {
    local branch="${1:-}"
    local force="${2:-}"

    if [[ -z "${branch}" ]]; then
        error "git::delete_branch requires a branch name"
        return "${FAIL}"
    fi

    if ! git::is_repo; then
        error "Not in a Git repository"
        return "${FAIL}"
    fi

    local flag="-d"
    [[ "${force}" == "--force" ]] && flag="-D"

    if cmd::run git branch "${flag}" "${branch}"; then
        pass "Deleted branch: ${branch}"
        return "${PASS}"
    fi

    fail "Failed to delete branch: ${branch}"
    return "${FAIL}"
}

#===============================================================================
# Repository Information
#===============================================================================

###############################################################################
# git::get_branch
#------------------------------------------------------------------------------
# Purpose  : Get the current branch name.
# Usage    : branch=$(git::get_branch)
# Returns  : Prints branch name; PASS on success, FAIL if not a repo.
# Requirements:
#   Functions:
#     - git::is_repo
#     - error
###############################################################################
function git::get_branch() {
    if ! git::is_repo; then
        error "Not in a Git repository"
        return "${FAIL}"
    fi
    local branch
    branch=$(git rev-parse --abbrev-ref HEAD 2> /dev/null || true)
    printf '%s\n' "${branch:-unknown}"
    return "${PASS}"
}

###############################################################################
# git::get_commit
#------------------------------------------------------------------------------
# Purpose  : Get current commit hash.
# Usage    : commit=$(git::get_commit)
# Returns  : Prints hash; PASS on success, FAIL if not a repo.
# Requirements:
#   Functions:
#     - git::is_repo
#     - error
###############################################################################
function git::get_commit() {
    if ! git::is_repo; then
        error "Not in a Git repository"
        return "${FAIL}"
    fi
    local commit
    commit=$(git rev-parse HEAD 2> /dev/null || true)
    printf '%s\n' "${commit:-unknown}"
    return "${PASS}"
}

###############################################################################
# git::get_remote_url
#------------------------------------------------------------------------------
# Purpose  : Get the remote URL for the origin.
# Usage    : url=$(git::get_remote_url)
# Returns  : Prints remote URL; PASS on success, FAIL if not a repo.
# Requirements:
#   Functions:
#     - git::is_repo
#     - error
###############################################################################
function git::get_remote_url() {
    if ! git::is_repo; then
        error "Not in a Git repository"
        return "${FAIL}"
    fi
    local url
    url=$(git config --get remote.origin.url 2> /dev/null || true)
    printf '%s\n' "${url:-unknown}"
    return "${PASS}"
}

###############################################################################
# git::has_changes
#------------------------------------------------------------------------------
# Purpose  : Check if there are uncommitted changes.
# Usage    : git::has_changes && warn "Uncommitted changes exist"
# Returns  : PASS if changes exist, FAIL otherwise.
# Requirements:
#   Functions:
#     - git::is_repo
#     - debug
###############################################################################
function git::has_changes() {
    if ! git::is_repo; then
        return "${FAIL}"
    fi
    if ! git diff --quiet || ! git diff --cached --quiet; then
        debug "Uncommitted changes detected"
        return "${PASS}"
    fi
    return "${FAIL}"
}

###############################################################################
# git::is_clean
#------------------------------------------------------------------------------
# Purpose  : Check if working directory is clean.
# Usage    : git::is_clean && info "Repo is clean"
# Returns  : PASS if clean, FAIL otherwise.
# Requirements:
#   Functions:
#     - git::has_changes
#     - debug
###############################################################################
function git::is_clean() {
    if git::has_changes; then
        debug "Repository has pending changes"
        return "${FAIL}"
    fi
    debug "Repository clean"
    return "${PASS}"
}

#===============================================================================
# Repository Actions
#===============================================================================

###############################################################################
# git::clone
#------------------------------------------------------------------------------
# Purpose  : Clone a repository.
# Usage    : git::clone "https://github.com/user/repo.git" [dest]
# Returns  : PASS if successful, FAIL otherwise.
# Requirements:
#   Functions:
#     - git::is_available
#     - cmd::run
#     - info, pass, fail, error
###############################################################################
function git::clone() {
    local repo="${1:-}"
    local dest="${2:-}"
    shift 2 || true
    local -a extra_args=("$@")

    if [[ -z "${repo}" ]]; then
        error "git::clone requires a repository URL"
        return "${FAIL}"
    fi

    if ! git::is_available; then
        error "git is not installed"
        return "${FAIL}"
    fi

    info "Cloning repository: ${repo}"

    # Build command as array
    local -a cmd=(git clone)
    cmd+=("${extra_args[@]}")
    cmd+=("${repo}")
    [[ -n "${dest}" ]] && cmd+=("${dest}")

    if "${cmd[@]}"; then
        pass "Cloned repository: ${repo}"
        return "${PASS}"
    fi

    fail "Failed to clone: ${repo}"
    return "${FAIL}"
}

###############################################################################
# git::pull
#------------------------------------------------------------------------------
# Purpose  : Pull latest changes from remote.
# Usage    : git::pull
# Returns  : PASS if successful, FAIL otherwise.
# Requirements:
#   Functions:
#     - git::is_repo
#     - cmd::run
#     - info, pass, fail, error
###############################################################################
function git::pull() {
    if ! git::is_repo; then
        error "Not in a Git repository"
        return "${FAIL}"
    fi

    # Auto-fetch if configured
    if config::get_bool "git.auto_fetch"; then
        info "Auto-fetch enabled, fetching latest..."
        cmd::run git fetch || warn "Auto-fetch failed"
    fi

    info "Pulling latest changes..."
    if cmd::run git pull --rebase; then
        pass "Repository updated"
        return "${PASS}"
    fi
    fail "git pull failed"
    return "${FAIL}"
}

###############################################################################
# git::push
#------------------------------------------------------------------------------
# Purpose  : Push changes to remote.
# Usage    : git::push
# Returns  : PASS if successful, FAIL otherwise.
# Requirements:
#   Functions:
#     - git::is_repo
#     - cmd::run
#     - info, pass, fail, error
###############################################################################
function git::push() {
    if ! git::is_repo; then
        error "Not in a Git repository"
        return "${FAIL}"
    fi
    info "Pushing changes to remote..."
    if cmd::run git push; then
        pass "Changes pushed"
        return "${PASS}"
    fi
    fail "git push failed"
    return "${FAIL}"
}

###############################################################################
# git::commit
#------------------------------------------------------------------------------
# Purpose  : Commit changes with a message.
# Usage    : git::commit "Commit message"
# Returns  : PASS if successful, FAIL otherwise.
# Requirements:
#   Functions:
#     - git::is_repo
#     - cmd::run
#     - info, pass, fail, error
###############################################################################
function git::commit() {
    local msg="${1:-}"
    shift || true
    local -a extra_args=("$@")

    if [[ -z "${msg}" ]]; then
        error "git::commit requires a message"
        return "${FAIL}"
    fi

    if ! git::is_repo; then
        error "Not in a Git repository"
        return "${FAIL}"
    fi

    info "Committing changes: ${msg}"

    # Build command as array
    local -a cmd=(git add -A)
    if ! "${cmd[@]}"; then
        fail "git add failed"
        return "${FAIL}"
    fi

    cmd=(git commit)
    cmd+=("${extra_args[@]}")
    cmd+=(-m "${msg}")

    if "${cmd[@]}"; then
        pass "Committed: ${msg}"
        return "${PASS}"
    fi

    fail "git commit failed"
    return "${FAIL}"
}

###############################################################################
# git::tag
#------------------------------------------------------------------------------
# Purpose  : Create or list tags.
# Usage    : git::tag [name]
# Returns  : PASS if successful, FAIL otherwise.
# Requirements:
#   Functions:
#     - git::is_repo
#     - cmd::run
#     - info, pass, fail, error
###############################################################################
function git::tag() {
    local tag="${1:-}"
    if ! git::is_repo; then
        error "Not in a Git repository"
        return "${FAIL}"
    fi

    if [[ -z "${tag}" ]]; then
        git tag
        return "${PASS}"
    fi

    info "Creating tag: ${tag}"
    if cmd::run git tag "${tag}"; then
        pass "Tag created: ${tag}"
        return "${PASS}"
    fi
    fail "Failed to create tag: ${tag}"
    return "${FAIL}"
}

###############################################################################
# git::checkout
#------------------------------------------------------------------------------
# Purpose  : Checkout a branch or commit.
# Usage    : git::checkout "branch_name"
# Returns  : PASS if successful, FAIL otherwise.
# Requirements:
#   Functions:
#     - git::is_repo
#     - cmd::run
#     - info, pass, fail, error
###############################################################################
function git::checkout() {
    local target="${1:-}"
    if [[ -z "${target}" ]]; then
        error "git::checkout requires a branch or commit"
        return "${FAIL}"
    fi
    if ! git::is_repo; then
        error "Not in a Git repository"
        return "${FAIL}"
    fi

    info "Checking out ${target}"
    if cmd::run git checkout "${target}"; then
        pass "Checked out ${target}"
        return "${PASS}"
    fi
    fail "Checkout failed: ${target}"
    return "${FAIL}"
}

###############################################################################
# git::get_root
#------------------------------------------------------------------------------
# Purpose  : Get root directory of current git repo.
# Usage    : root=$(git::get_root)
# Returns  : Prints path; PASS on success, FAIL otherwise.
# Requirements:
#   Functions:
#     - git::is_repo
#     - error
###############################################################################
function git::get_root() {
    if ! git::is_repo; then
        error "Not in a Git repository"
        return "${FAIL}"
    fi
    local root
    root=$(git rev-parse --show-toplevel 2> /dev/null || true)
    printf '%s\n' "${root}"
    return "${PASS}"
}

###############################################################################
# git::get_config
#------------------------------------------------------------------------------
# Purpose  : Get Git configuration value.
# Usage    : git::get_config "user.name"
# Returns  : Prints value; PASS if non-empty, FAIL otherwise.
# Requirements:
#   Functions:
#     - error
###############################################################################
function git::get_config() {
    local key="${1:-}"
    if [[ -z "${key}" ]]; then
        error "git::get_config requires a key"
        return "${FAIL}"
    fi
    local value
    value=$(git config --get "${key}" 2> /dev/null || true)
    printf '%s\n' "${value:-}"
    [[ -n "${value}" ]] && return "${PASS}" || return "${FAIL}"
}

#===============================================================================
# GitHub Release Helpers (using util_curl.sh)
#===============================================================================

###############################################################################
# git::get_latest_release_info
#------------------------------------------------------------------------------
# Purpose  : Fetch latest GitHub release info and expose values via nameref vars.
# Usage    : git::get_latest_release_info "owner/repo" "linux" "amd64" \
#               TAG_VAR NAME_VAR ASSET_URL_VAR
#
#   Example:
#       local tag name asset
#       if git::get_latest_release_info "sharkdp/bat" "linux" "amd64" \
#              tag name asset; then
#           echo "Tag:   ${tag}"
#           echo "Name:  ${name}"
#           echo "Asset: ${asset}"
#       fi
#
# Params   :
#   $1 - repo in "owner/name" form
#   $2 - OS pattern to match in asset URL (e.g., "linux")
#   $3 - Arch pattern to match in asset URL (e.g., "amd64", "x86_64")
#   $4 - (optional) variable name to store tag      (default: GIT_RELEASE_TAG)
#   $5 - (optional) variable name to store name     (default: GIT_RELEASE_NAME)
#   $6 - (optional) variable name to store asset URL(default: GIT_RELEASE_ASSET)
#
# Returns  : PASS on success, FAIL otherwise.
# Requirements:
#   Functions:
#     - curl::is_available
#     - curl::get
#     - cmd::exists
#     - error, fail, debug
###############################################################################
function git::get_latest_release_info() {
    local repo="${1:-}"
    local os_pattern="${2:-}"
    local arch_pattern="${3:-}"
    local tag_var="${4:-GIT_RELEASE_TAG}"
    local name_var="${5:-GIT_RELEASE_NAME}"
    local asset_var="${6:-GIT_RELEASE_ASSET}"

    if [[ -z "${repo}" || -z "${os_pattern}" || -z "${arch_pattern}" ]]; then
        error "Usage: git::get_latest_release_info <owner/repo> <os_pattern> <arch_pattern> [tag_var] [name_var] [asset_var]"
        return "${FAIL}"
    fi

    if ! curl::is_available; then
        error "curl is required for git::get_latest_release_info"
        return "${FAIL}"
    fi

    if ! cmd::exists jq; then
        error "jq is required to parse GitHub API responses"
        error "Install jq: https://stedolan.github.io/jq/download/"
        return "${FAIL}"
    fi

    local api_url="https://api.github.com/repos/${repo}/releases/latest"
    debug "Fetching latest release info from ${api_url}"

    local body
    if ! body="$(curl::get "${api_url}")"; then
        fail "Failed to retrieve release info from GitHub for ${repo}"
        return "${FAIL}"
    fi

    local tag name asset
    tag=$(printf '%s\n' "${body}" | jq -r '.tag_name // empty')
    name=$(printf '%s\n' "${body}" | jq -r '.name // empty')
    asset=$(printf '%s\n' "${body}" |
        jq -r '.assets[].browser_download_url // empty' |
        grep -i "${os_pattern}" |
        grep -i "${arch_pattern}" |
        head -n 1)

    if [[ -z "${tag}" ]]; then
        fail "Unable to determine tag_name from GitHub response for ${repo}"
        return "${FAIL}"
    fi
    if [[ -z "${asset}" ]]; then
        fail "No asset URL matched patterns os='${os_pattern}' arch='${arch_pattern}' for ${repo}"
        return "${FAIL}"
    fi

    # Nameref outputs (Bash 4+)
    declare -n _tag_ref="${tag_var}"
    declare -n _name_ref="${name_var}"
    declare -n _asset_ref="${asset_var}"

    _tag_ref="${tag}"
    _name_ref="${name:-${tag}}"
    _asset_ref="${asset}"

    debug "Latest release for ${repo}: tag=${tag}, asset=${asset}"
    return "${PASS}"
}

###############################################################################
# git::get_release
#------------------------------------------------------------------------------
# Purpose  : Download the latest GitHub release asset matching OS/Arch.
# Usage    : git::get_release "owner/repo" "linux" "amd64" "/tmp/release.tar.gz"
#
# Behavior :
#   - If <dest> is a directory, the asset's filename is preserved inside it.
#   - If <dest> is a file path, the asset is saved exactly there.
#
# Returns  : PASS if download succeeds, FAIL otherwise.
# Requirements:
#   Functions:
#     - git::get_latest_release_info
#     - curl::download
#     - error, info, pass, fail
###############################################################################
function git::get_release() {
    local repo="${1:-}" os="${2:-}" arch="${3:-}" dest="${4:-}"

    if [[ -z "${repo}" || -z "${os}" || -z "${arch}" || -z "${dest}" ]]; then
        error "Usage: git::get_release <owner/repo> <os> <arch> <dest>"
        return "${FAIL}"
    fi

    if ! curl::is_available; then
        error "git::get_release: curl is required but not available."
        return "${FAIL}"
    fi

    local url="https://api.github.com/repos/${repo}/releases/latest"
    info "Fetching latest release metadata for ${repo}"

    # Use trap utility for automatic cleanup
    local json_tmp
    if ! json_tmp=$(trap::with_cleanup platform::mktemp "/tmp/git_release.XXXXXX"); then
        fail "git::get_release: Failed to create temporary JSON file."
        return "${FAIL}"
    fi

    # Download JSON metadata
    if ! curl::download "${url}" "${json_tmp}"; then
        fail "git::get_release: Failed to download release metadata for ${repo}."
        return "${FAIL}"
    fi

    # Extract asset URL matching os/arch
    local asset_url
    asset_url=$(
        grep -E '"browser_download_url"' "${json_tmp}" |
            grep "${os}" |
            grep "${arch}" |
            head -n 1 |
            cut -d '"' -f 4
    )

    if [[ -z "${asset_url}" ]]; then
        fail "git::get_release: No matching release asset found for ${repo} (${os}/${arch})."
        return "${FAIL}"
    fi

    info "Downloading release asset from ${asset_url} -> ${dest}"
    if curl::download "${asset_url}" "${dest}"; then
        pass "Release downloaded to ${dest}"
        return "${PASS}"
    fi

    fail "git::get_release: Failed to download asset from ${asset_url}"
    return "${FAIL}"
}

#===============================================================================
# Self-Test
#===============================================================================

###############################################################################
# git::self_test
#------------------------------------------------------------------------------
# Purpose  : Run basic self-tests for util_git.sh.
# Usage    : git::self_test
# Returns  : PASS (0) on success, FAIL (1) on critical failure.
# Notes    :
#   - Only performs light checks (git availability, repo status if applicable).
#   - GitHub API tests are optional and best-effort.
# Requirements:
#   Functions:
#     - git::is_available
#     - info, warn, pass, fail, debug
###############################################################################
function git::self_test() {
    info "Running util_git.sh self-test..."

    if ! git::is_available; then
        fail "git not available on this system"
        return "${FAIL}"
    fi

    # If we are in a repo, exercise some introspection helpers
    if git::is_repo; then
        local branch commit
        branch=$(git::get_branch 2> /dev/null || echo "unknown")
        commit=$(git::get_commit 2> /dev/null || echo "unknown")
        debug "Self-test: branch=${branch}, commit=${commit}"
    else
        warn "Not inside a Git repository; skipping repo-specific tests"
    fi

    pass "util_git.sh self-test completed."
    return "${PASS}"
}
