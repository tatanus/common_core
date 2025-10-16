#!/usr/bin/env bash
set -uo pipefail

# =============================================================================
# NAME        : utils_os.sh
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
if [[ -z "${UTILS_OS_SH_LOADED:-}" ]]; then
    declare -g UTILS_OS_SH_LOADED=true

    # Get OS Architecture
    function _get_arch() {
        local arch
        arch=$(uname -m)

        case "${arch}" in
            x86_64) echo "amd64" ;;
            aarch64 | arm64) echo "arm64" ;;
            i[3-6]86) echo "386" ;;
            armv7l) echo "armhf" ;;
            *)
                echo "unsupported"
                return 1
                ;;
        esac
    }

    # Get the Ubuntu version
    function _get_ubuntu_version() {
        local ubuntu_version

        # Extract the version from /etc/os-release or lsb_release
        if [[ -f /etc/os-release ]]; then
            ubuntu_version=$(grep -oP 'VERSION_ID="\K[^"]+' /etc/os-release)
        elif command -v lsb_release > /dev/null 2>&1; then
            ubuntu_version=$(lsb_release -rs)
        else
            fail "Unable to determine Ubuntu version."
            exit "${_FAIL}"
        fi

        echo "${ubuntu_version}"
    }

    # Get the macOS version
    function _get_macos_version() {
        local macos_version

        # Use the `sw_vers` command to fetch the macOS version
        if command -v sw_vers > /dev/null 2>&1; then
            macos_version=$(sw_vers -productVersion)
        else
            fail "Unable to determine macOS version. 'sw_vers' command not found."
            exit "${_FAIL}"
        fi

        echo "${macos_version}"
    }

    # Get the Windows version
    function _get_windows_version() {
        local windows_version

        # Check if running on Windows
        if [[ "$(uname -s)" =~ (CYGWIN|MINGW|MSYS|Linux) ]]; then
            # Use `cmd.exe` to fetch the Windows version
            if command -v cmd.exe > /dev/null 2>&1; then
                windows_version=$(cmd.exe /c "ver" 2> /dev/null | grep -oP '\[Version\s\K[^\]]+')
            else
                fail "Unable to determine Windows version. 'cmd.exe' not found."
                exit "${_FAIL}"
            fi
        else
            fail "This does not appear to be a Windows environment."
            exit "${_FAIL}"
        fi

        echo "${windows_version}"
    }

    # -----------------------------------------------------------------------------
    # ---------------------------------- OS VER CHECK -----------------------------
    # -----------------------------------------------------------------------------

    # Determine the operating system and version
    OS_NAME="$(uname -s)" # Get the OS name
    OS_NAME="${OS_NAME:-unknown}"
    export OS_NAME

    # Initialize version variables for supported operating systems
    export UBUNTU_VER=""
    export MACOS_VER=""
    export WINDOWS_VER=""

    # Case statement to handle different operating systems
    case "${OS_NAME}" in
        Linux)
            # Check if the _get_ubuntu_version function is available
            if ! command -v _get_ubuntu_version &> /dev/null; then
                fail "Function _get_ubuntu_version is not defined."
                exit "${_FAIL}"
            fi

            UBUNTU_VER=$(_get_ubuntu_version) || {
                fail "Failed to determine Ubuntu version."
                exit "${_FAIL}"
            }

            export UBUNTU_VER
            info "Detected Ubuntu version: ${UBUNTU_VER}"
            ;;
        Darwin)
            # Check if the _get_macos_version function is available
            if ! command -v _get_macos_version &> /dev/null; then
                fail "Function _get_macos_version is not defined."
                exit "${_FAIL}"
            fi

            MACOS_VER=$(_get_macos_version) || {
                fail "Failed to determine macOS version."
                exit "${_FAIL}"
            }

            export MACOS_VER
            info "Detected macOS version: ${MACOS_VER}"
            ;;
        CYGWIN* | MINGW* | MSYS* | Windows_NT)
            # Handle Windows platforms
            # Check if the _get_windows_version function is available
            if ! command -v _get_windows_version &> /dev/null; then
                fail "Function _get_windows_version is not defined."
                exit "${_FAIL}"
            fi

            WINDOWS_VER=$(_get_windows_version) || {
                fail "Failed to determine Windows version."
                exit "${_FAIL}"
            }

            export WINDOWS_VER
            pass "Detected Windows version: ${WINDOWS_VER}"
            ;;
        *)
            # Handle unsupported operating systems
            fail "Unsupported operating system detected: ${OS_NAME}"
            exit "${_FAIL}"
            ;;
    esac
fi
