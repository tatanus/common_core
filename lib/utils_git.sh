#!/usr/bin/env bash
set -uo pipefail

# =============================================================================
# NAME        : utils_git.sh
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
if [[ -z "${UTILS_GIT_SH_LOADED:-}" ]]; then
    declare -g UTILS_GIT_SH_LOADED=true

    # -----------------------------------------------------------------------------
    # ---------------------------------- GIT FUNCTIONS ----------------------------
    # -----------------------------------------------------------------------------

    # Clone a Git repository
    function _git_clone() {
        local url="$1"
        local dest="${2:-}"  # Optional second argument for custom directory name

        # Ensure the URL is provided
        if [[ -z "${url}" ]]; then
            fail "Git repository URL cannot be empty."
            return "${FAIL}"
        fi

        # Extract repository name from the URL
        local repo_name="${url##*/}"
        repo_name=${repo_name%.git}

        # Determine the destination directory name
        local dname="${dest:-${repo_name}}"  # Use custom name if provided, otherwise repo name

        # Create the directory if it does not exist
        mkdir -p "${TOOLS_DIR}/${dname}"

        # Attempt to clone the repository
        if ${PROXY} git clone --recurse-submodules -q "${url}" "${TOOLS_DIR}/${dname}" > /dev/null 2>&1; then
            pass "Cloned repository ${url} into ${TOOLS_DIR}/${dname}."
            return "${PASS}"
        else
            fail "Failed to clone repository ${url} into ${TOOLS_DIR}/${dname}."
            return "${FAIL}"
        fi
    }

    # Download the latest release of a GitHub repository
    function _git_release() {
        local full_repo_name="$1"
        local release_name="$2"
        local path="$3"

        # Validate input parameters
        if [[ -z "${full_repo_name}" ]] || [[ -z "${release_name}" ]] || [[ -z "${path}" ]]; then
            fail "Usage: _Git_Release <full_repo_name> <release_name> <path>"
            return "${FAIL}"
        fi

        # Create the directory if it does not exist
        mkdir -p "${path}"

        # Attempt to download the release asset
        api_response=$(${PROXY} curl -sSL "https://api.github.com/repos/${full_repo_name}/releases/latest")
        download_urls=$(echo "${api_response}" | jq -r '.assets[].browser_download_url' | grep "${release_name}")

        if echo "${download_urls}" | xargs -r wget --no-check-certificate -P "${path}" > /dev/null 2>&1; then
            pass "Downloaded latest release '${release_name}' from repository '${full_repo_name}' to '${path}'."
            return "${PASS}"
        else
            fail "Failed to download latest release '${release_name}' from repository '${full_repo_name}'."
            return "${FAIL}"
        fi
    }
fi
