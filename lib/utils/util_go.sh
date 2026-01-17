#!/usr/bin/env bash
###############################################################################
# NAME         : util_go.sh
# DESCRIPTION  : Go (Golang) environment, tooling, and build utilities.
# AUTHOR       : Adam Compton
# DATE CREATED : 2025-10-27
###############################################################################
# EDIT HISTORY:
# DATE        | EDITED BY      | DESCRIPTION
# ------------|----------------|-----------------------------------------------
# 2025-10-27  | Adam Compton   | Initial generation (style-guide compliant)
###############################################################################

set -uo pipefail
IFS=$'\n\t'

#===============================================================================
# Library Guard
#===============================================================================
if [[ -n "${UTIL_GO_SH_LOADED:-}" ]]; then
    if (return 0 2> /dev/null); then
        return 0
    fi
else
    UTIL_GO_SH_LOADED=1
fi

#===============================================================================
# Module Dependencies
#===============================================================================
if [[ "${UTIL_PLATFORM_SH_LOADED:-0}" -eq 0 ]]; then
    echo "ERROR: util_platform.sh must be loaded before util_go.sh" >&2
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
GO_VERSION="${GO_VERSION:-1.23.3}"

#===============================================================================
# Availability and Version
#===============================================================================

###############################################################################
# go::is_available
#------------------------------------------------------------------------------
# Purpose  : Check if Go is installed.
# Usage    : go::is_available && info "Go is installed"
# Returns  : PASS if installed, FAIL otherwise.
###############################################################################
function go::is_available() {
    if cmd::exists go; then
        debug "Go available at $(command -v go)"
        return "${PASS}"
    fi
    debug "Go not installed"
    return "${FAIL}"
}

###############################################################################
# go::get_version
#------------------------------------------------------------------------------
# Purpose  : Get installed Go version.
# Usage    : ver=$(go::get_version)
# Returns  : Prints version string or FAIL.
###############################################################################
function go::get_version() {
    if ! go::is_available; then
        error "Go not installed"
        return "${FAIL}"
    fi
    local version
    version=$(go version 2> /dev/null | awk '{print $3}' | sed 's/go//')
    printf '%s\n' "${version:-unknown}"
    return "${PASS}"
}

#===============================================================================
# Installation and Environment
#===============================================================================

###############################################################################
# go::install
#------------------------------------------------------------------------------
# Purpose  : Install Go (cross-platform: Linux/macOS).
# Usage    : go::install
# Returns  : PASS if installed successfully, FAIL otherwise.
###############################################################################
function go::install() {
    if go::is_available; then
        info "Go is already installed"
        return "${PASS}"
    fi

    info "Installing Go ${GO_VERSION}..."
    local url archive tmpfile dest
    dest="/usr/local"

    # Use platform abstraction
    if ! tmpfile="$(platform::mktemp "/tmp/go_download.XXXXXX")"; then
        error "Failed to create temporary file"
        return "${FAIL}"
    fi

    # Determine OS and architecture
    local os_name arch_name
    if os::is_macos; then
        os_name="darwin"
    elif os::is_linux; then
        os_name="linux"
    else
        error "Unsupported OS for Go installation"
        rm -f "${tmpfile}"
        return "${FAIL}"
    fi

    arch_name="$(os::get_arch)"
    case "${arch_name}" in
        amd64) arch_name="amd64" ;;
        arm64) arch_name="arm64" ;;
        *)
            error "Unsupported architecture for Go: ${arch_name}"
            rm -f "${tmpfile}"
            return "${FAIL}"
            ;;
    esac

    archive="go${GO_VERSION}.${os_name}-${arch_name}.tar.gz"
    url="https://go.dev/dl/${archive}"

    info "Downloading ${url}"
    if ! curl::download "${url}" "${tmpfile}"; then
        fail "Failed to download Go archive"
        rm -f "${tmpfile}"
        return "${FAIL}"
    fi

    info "Extracting to ${dest}"
    if cmd::elevate tar -C "${dest}" -xzf "${tmpfile}"; then
        rm -f "${tmpfile}"
        pass "Go ${GO_VERSION} installed successfully"
        return "${PASS}"
    fi

    rm -f "${tmpfile}"
    fail "Go installation failed"
    return "${FAIL}"
}

###############################################################################
# go::set_module_proxy
#------------------------------------------------------------------------------
# Purpose  : Configure Go module proxy (for corporate/restricted environments)
# Usage    : go::set_module_proxy "https://proxy.golang.org,direct"
# Returns  : PASS if set, FAIL otherwise
###############################################################################
function go::set_module_proxy() {
    local proxy="${1:-https://proxy.golang.org,direct}"

    export GOPROXY="${proxy}"
    export GOSUMDB="sum.golang.org"

    info "Go module proxy set to: ${proxy}"
    return "${PASS}"
}

###############################################################################
# go::build_cross
#------------------------------------------------------------------------------
# Purpose  : Build Go binary for different OS/architecture
# Usage    : go::build_cross "linux" "amd64" "./cmd/app" "app-linux-amd64"
# Returns  : PASS if successful, FAIL otherwise
###############################################################################
function go::build_cross() {
    local target_os="${1:-}"
    local target_arch="${2:-}"
    local source="${3:-.}"
    local output="${4:-}"

    if [[ -z "${target_os}" || -z "${target_arch}" ]]; then
        error "Usage: go::build_cross <os> <arch> [source] [output]"
        return "${FAIL}"
    fi

    info "Cross-compiling for ${target_os}/${target_arch}..."

    # Build command as array with environment variables
    local -a env_vars=(
        "GOOS=${target_os}"
        "GOARCH=${target_arch}"
    )

    local -a cmd=(env)
    cmd+=("${env_vars[@]}")
    cmd+=(go build)

    [[ -n "${output}" ]] && cmd+=(-o "${output}")
    cmd+=("${source}")

    if "${cmd[@]}"; then
        pass "Build successful: ${target_os}/${target_arch}"
        return "${PASS}"
    fi

    fail "Cross-compilation failed"
    return "${FAIL}"
}

###############################################################################
# go::work_init
#------------------------------------------------------------------------------
# Purpose  : Initialize Go workspace (Go 1.18+)
# Usage    : go::work_init "./module1" "./module2"
# Returns  : PASS if successful, FAIL otherwise
###############################################################################
function go::work_init() {
    if [[ $# -eq 0 ]]; then
        error "go::work_init requires at least one module path"
        return "${FAIL}"
    fi

    info "Initializing Go workspace..."
    if cmd::run go work init "$@"; then
        pass "Workspace initialized"
        return "${PASS}"
    fi

    fail "Workspace initialization failed"
    return "${FAIL}"
}

###############################################################################
# go::get_gopath
#------------------------------------------------------------------------------
# Purpose  : Get the GOPATH value.
# Usage    : go::get_gopath
# Returns  : Prints GOPATH or default.
###############################################################################
function go::get_gopath() {
    local gopath="${GOPATH:-$(go env GOPATH 2> /dev/null || echo "${HOME}/go")}"
    printf '%s\n' "${gopath}"
    return "${PASS}"
}

###############################################################################
# go::get_goroot
#------------------------------------------------------------------------------
# Purpose  : Get the GOROOT path.
# Usage    : go::get_goroot
# Returns  : Prints GOROOT.
###############################################################################
function go::get_goroot() {
    local goroot="${GOROOT:-$(go env GOROOT 2> /dev/null || echo "/usr/local/go")}"
    printf '%s\n' "${goroot}"
    return "${PASS}"
}

#===============================================================================
# Project Management
#===============================================================================

###############################################################################
# go::mod_init
#------------------------------------------------------------------------------
# Purpose  : Initialize a new Go module.
# Usage    : go::mod_init "github.com/user/project"
# Returns  : PASS if successful, FAIL otherwise.
###############################################################################
function go::mod_init() {
    local module="${1:-}"
    if [[ -z "${module}" ]]; then
        error "Usage: go::mod_init <module_path>"
        return "${FAIL}"
    fi
    info "Initializing Go module: ${module}"
    if cmd::run go mod init "${module}"; then
        pass "Go module initialized: ${module}"
        return "${PASS}"
    fi
    fail "Failed to initialize module"
    return "${FAIL}"
}

###############################################################################
# go::mod_tidy
#------------------------------------------------------------------------------
# Purpose  : Clean and sync go.mod dependencies.
# Usage    : go::mod_tidy
# Returns  : PASS if successful, FAIL otherwise.
###############################################################################
function go::mod_tidy() {
    info "Tidying Go modules..."
    if cmd::run go mod tidy; then
        pass "Go modules tidied"
        return "${PASS}"
    fi
    fail "go mod tidy failed"
    return "${FAIL}"
}

#===============================================================================
# Building and Testing
#===============================================================================

###############################################################################
# go::build
#------------------------------------------------------------------------------
# Purpose  : Build a Go project or package.
# Usage    : go::build "./cmd/app"
# Returns  : PASS if successful, FAIL otherwise.
###############################################################################
function go::build() {
    local target="${1:-.}"
    info "Building Go target: ${target}"
    if cmd::run go build "${target}"; then
        pass "Build successful: ${target}"
        return "${PASS}"
    fi
    fail "Build failed: ${target}"
    return "${FAIL}"
}

###############################################################################
# go::test
#------------------------------------------------------------------------------
# Purpose  : Run Go tests.
# Usage    : go::test
# Returns  : PASS if all tests pass, FAIL otherwise.
###############################################################################
function go::test() {
    info "Running Go tests..."
    if cmd::run go test ./...; then
        pass "All tests passed"
        return "${PASS}"
    fi
    fail "Tests failed"
    return "${FAIL}"
}

###############################################################################
# go::install_tool
#------------------------------------------------------------------------------
# Purpose  : Install a Go-based tool/binary globally.
# Usage    : go::install_tool "github.com/golangci/golangci-lint/cmd/golangci-lint@latest"
# Returns  : PASS if successful, FAIL otherwise.
###############################################################################
function go::install_tool() {
    local pkg="${1:-}"
    if [[ -z "${pkg}" ]]; then
        error "Usage: go::install_tool <package@version>"
        return "${FAIL}"
    fi
    info "Installing Go tool: ${pkg}"
    if cmd::run go install "${pkg}"; then
        pass "Installed Go tool: ${pkg}"
        return "${PASS}"
    fi
    fail "Failed to install Go tool"
    return "${FAIL}"
}

###############################################################################
# go::fmt
#------------------------------------------------------------------------------
# Purpose  : Format Go source files.
# Usage    : go::fmt
# Returns  : PASS if successful, FAIL otherwise.
###############################################################################
function go::fmt() {
    info "Formatting Go code..."
    if cmd::run go fmt ./...; then
        pass "Code formatted successfully"
        return "${PASS}"
    fi
    fail "Code formatting failed"
    return "${FAIL}"
}

###############################################################################
# go::vet
#------------------------------------------------------------------------------
# Purpose  : Run go vet for static analysis.
# Usage    : go::vet
# Returns  : PASS if no issues, FAIL otherwise.
###############################################################################
function go::vet() {
    info "Running go vet..."
    if cmd::run go vet ./...; then
        pass "go vet completed successfully"
        return "${PASS}"
    fi
    fail "go vet found issues"
    return "${FAIL}"
}

###############################################################################
# go::lint
#------------------------------------------------------------------------------
# Purpose  : Run Go linter if available.
# Usage    : go::lint
# Returns  : PASS if successful, FAIL otherwise.
###############################################################################
function go::lint() {
    if ! cmd::exists golangci-lint; then
        warn "golangci-lint not found. Installing..."
        go::install_tool "github.com/golangci/golangci-lint/cmd/golangci-lint@latest" || {
            fail "Failed to install golangci-lint"
            return "${FAIL}"
        }
    fi
    info "Running Go linter..."
    if cmd::run golangci-lint run; then
        pass "Linting completed successfully"
        return "${PASS}"
    fi
    fail "Linting failed"
    return "${FAIL}"
}

###############################################################################
# go::self_test
#------------------------------------------------------------------------------
# Purpose  : Self-test for util_go.sh functionality
# Usage    : go::self_test
# Returns  : PASS (0) if all tests pass, FAIL (1) otherwise
# Globals  : None
###############################################################################
function go::self_test() {
    info "Running util_go.sh self-test..."

    local status="${PASS}"

    # Test 1: Check if Go detection works
    if ! declare -F go::is_available > /dev/null 2>&1; then
        fail "go::is_available function not available"
        status="${FAIL}"
    fi

    # Test 2: If Go is available, test version retrieval
    if go::is_available; then
        if ! go::get_version > /dev/null 2>&1; then
            fail "go::get_version failed"
            status="${FAIL}"
        fi

        if ! go::get_gopath > /dev/null 2>&1; then
            debug "go::get_gopath failed (may be expected if not set)"
        fi
    else
        info "Go not available - skipping version tests"
    fi

    if [[ "${status}" -eq "${PASS}" ]]; then
        pass "util_go.sh self-test passed"
    else
        fail "util_go.sh self-test failed"
    fi

    return "${status}"
}
