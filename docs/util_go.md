# util_go.sh - Go Environment Management

Go language environment, tooling, and build utilities.

## Overview

This module provides:
- Go availability and version detection
- Go installation (cross-platform: Linux/macOS)
- Cross-compilation support
- Module and workspace management
- Build, test, format, vet, and lint commands
- Tool installation utilities

## Dependencies

- `util_platform.sh` (required - must be loaded before util_go.sh)
- `util_cmd.sh` (for `cmd::exists`, `cmd::run`, `cmd::elevate`)
- `curl::download` (for Go installation)

## Globals

| Variable | Default | Description |
|----------|---------|-------------|
| `GO_VERSION` | `1.23.3` | Default Go version for installation |
| `PASS` | `0` | Success return code |
| `FAIL` | `1` | Failure return code |

## Functions

### Availability and Version

#### go::is_available

Check if Go is installed on the system.

```bash
if go::is_available; then
    info "Go is installed"
fi
```

**Arguments:** None

**Returns:** `PASS` (0) if Go is installed, `FAIL` (1) otherwise

**Outputs:** Debug message to stderr

---

#### go::get_version

Get the installed Go version string.

```bash
version=$(go::get_version)
echo "Go ${version}"
```

**Arguments:** None

**Returns:** `PASS` (0) on success, `FAIL` (1) if Go is not installed

**Outputs:** Version string to stdout (e.g., `1.23.3`)

---

### Installation and Environment

#### go::install

Install Go on the system (cross-platform: Linux/macOS). Supports amd64 and arm64 architectures.

```bash
# Install default version
go::install

# Install specific version
GO_VERSION="1.22.0" go::install
```

**Arguments:** None (uses `GO_VERSION` global)

**Returns:** `PASS` (0) if installed successfully, `FAIL` (1) otherwise

**Outputs:** Progress and status messages to stderr

**Notes:**
- Skips installation if Go is already installed
- Downloads from official go.dev/dl
- Installs to `/usr/local` (requires elevated privileges)

---

#### go::set_module_proxy

Configure Go module proxy for corporate or restricted environments.

```bash
# Use default proxy
go::set_module_proxy

# Use custom proxy
go::set_module_proxy "https://proxy.company.com,direct"
```

**Arguments:**
- `$1` (optional) - Proxy URL (default: `https://proxy.golang.org,direct`)

**Returns:** `PASS` (0)

**Outputs:** Sets `GOPROXY` and `GOSUMDB` environment variables

---

#### go::get_gopath

Get the GOPATH value.

```bash
gopath=$(go::get_gopath)
echo "GOPATH: ${gopath}"
```

**Arguments:** None

**Returns:** `PASS` (0)

**Outputs:** GOPATH to stdout (defaults to `$HOME/go` if not set)

---

#### go::get_goroot

Get the GOROOT path.

```bash
goroot=$(go::get_goroot)
echo "GOROOT: ${goroot}"
```

**Arguments:** None

**Returns:** `PASS` (0)

**Outputs:** GOROOT to stdout (defaults to `/usr/local/go` if not set)

---

### Project Management

#### go::mod_init

Initialize a new Go module.

```bash
go::mod_init "github.com/user/project"
```

**Arguments:**
- `$1` - Module path (required)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Status messages to stderr

---

#### go::mod_tidy

Clean and synchronize go.mod dependencies.

```bash
go::mod_tidy
```

**Arguments:** None

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Status messages to stderr

---

#### go::work_init

Initialize a Go workspace (requires Go 1.18+).

```bash
go::work_init "./module1" "./module2"
```

**Arguments:**
- `$@` - One or more module paths (at least one required)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Status messages to stderr

---

### Building and Testing

#### go::build

Build a Go project or package.

```bash
# Build current directory
go::build

# Build specific target
go::build "./cmd/app"
```

**Arguments:**
- `$1` (optional) - Build target (default: `.`)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Status messages to stderr

---

#### go::build_cross

Build Go binary for a different OS/architecture (cross-compilation).

```bash
# Build for Linux amd64
go::build_cross "linux" "amd64" "./cmd/app" "app-linux-amd64"

# Build for Windows arm64
go::build_cross "windows" "arm64" "./cmd/app" "app-windows-arm64.exe"
```

**Arguments:**
- `$1` - Target OS (required, e.g., `linux`, `darwin`, `windows`)
- `$2` - Target architecture (required, e.g., `amd64`, `arm64`)
- `$3` (optional) - Source path (default: `.`)
- `$4` (optional) - Output binary name

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Status messages to stderr

---

#### go::test

Run Go tests for all packages.

```bash
go::test
```

**Arguments:** None

**Returns:** `PASS` (0) if all tests pass, `FAIL` (1) otherwise

**Outputs:** Test results and status messages to stderr

---

#### go::fmt

Format Go source files using `go fmt`.

```bash
go::fmt
```

**Arguments:** None

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Status messages to stderr

---

#### go::vet

Run `go vet` for static analysis on all packages.

```bash
go::vet
```

**Arguments:** None

**Returns:** `PASS` (0) if no issues found, `FAIL` (1) otherwise

**Outputs:** Vet results and status messages to stderr

---

#### go::lint

Run Go linter (`golangci-lint`). Automatically installs the linter if not available.

```bash
go::lint
```

**Arguments:** None

**Returns:** `PASS` (0) if no lint errors, `FAIL` (1) otherwise

**Outputs:** Lint results and status messages to stderr

**Notes:** Installs `golangci-lint` automatically if not found

---

### Tool Installation

#### go::install_tool

Install a Go-based tool/binary globally using `go install`.

```bash
go::install_tool "github.com/golangci/golangci-lint/cmd/golangci-lint@latest"
go::install_tool "golang.org/x/tools/cmd/goimports@latest"
```

**Arguments:**
- `$1` - Package path with version (required, e.g., `package@version`)

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

**Outputs:** Status messages to stderr

---

### Self-Test

#### go::self_test

Self-test for util_go.sh functionality.

```bash
go::self_test
```

**Arguments:** None

**Returns:** `PASS` (0) if all tests pass, `FAIL` (1) otherwise

**Outputs:** Test progress and results to stderr

---

## Examples

### Project Setup

```bash
#!/usr/bin/env bash
source util.sh

setup_go_project() {
    local module="$1"

    go::mod_init "${module}"
    go::mod_tidy
    go::build

    pass "Go project initialized"
}

setup_go_project "github.com/user/myproject"
```

### Install Development Tools

```bash
#!/usr/bin/env bash
source util.sh

# Install common Go development tools
go::install_tool "github.com/golangci/golangci-lint/cmd/golangci-lint@latest"
go::install_tool "golang.org/x/tools/cmd/goimports@latest"
go::install_tool "github.com/air-verse/air@latest"
go::install_tool "github.com/go-delve/delve/cmd/dlv@latest"
```

### Cross-Compilation Build Script

```bash
#!/usr/bin/env bash
source util.sh

build_all_platforms() {
    local app_name="myapp"
    local source="./cmd/app"

    # Build for multiple platforms
    go::build_cross "linux" "amd64" "${source}" "${app_name}-linux-amd64"
    go::build_cross "linux" "arm64" "${source}" "${app_name}-linux-arm64"
    go::build_cross "darwin" "amd64" "${source}" "${app_name}-darwin-amd64"
    go::build_cross "darwin" "arm64" "${source}" "${app_name}-darwin-arm64"
    go::build_cross "windows" "amd64" "${source}" "${app_name}-windows-amd64.exe"

    pass "All platforms built"
}
```

### CI/CD Pipeline

```bash
#!/usr/bin/env bash
source util.sh

ci_pipeline() {
    info "Starting CI pipeline..."

    # Ensure dependencies are clean
    go::mod_tidy || return "${FAIL}"

    # Format check
    go::fmt || return "${FAIL}"

    # Static analysis
    go::vet || return "${FAIL}"

    # Lint
    go::lint || return "${FAIL}"

    # Tests
    go::test || return "${FAIL}"

    # Build
    go::build || return "${FAIL}"

    pass "CI pipeline completed successfully"
}
```

### Workspace Setup (Multi-Module)

```bash
#!/usr/bin/env bash
source util.sh

setup_workspace() {
    # Initialize workspace with multiple modules
    go::work_init "./api" "./cli" "./shared"

    pass "Go workspace initialized"
}
```

### Configure Corporate Proxy

```bash
#!/usr/bin/env bash
source util.sh

# Set up for corporate environment
go::set_module_proxy "https://goproxy.company.com,https://proxy.golang.org,direct"

# Now install dependencies
go::mod_tidy
```

## Self-Test

```bash
source util.sh
go::self_test
```
