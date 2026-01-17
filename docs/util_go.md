# util_go.sh - Go Environment Management

Go language environment and module management utilities.

## Overview

This module provides:
- Go availability and version detection
- Package/module installation
- Build and test commands
- Module management

## Dependencies

- `util_cmd.sh`

## Functions

### Availability

#### go::is_available

Check if Go is available.

```bash
if go::is_available; then
    go::get_version
fi
```

**Returns:** `PASS` (0) if available, `FAIL` (1) otherwise

#### go::get_version

Get the Go version.

```bash
version=$(go::get_version)
echo "Go ${version}"
```

**Outputs:** Version string

### Package Installation

#### go::install

Install a Go package/tool.

```bash
go::install "github.com/golangci/golangci-lint/cmd/golangci-lint@latest"
```

**Arguments:**
- `$1` - Package path with version

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

### Build and Test

#### go::build

Build the current module.

```bash
go::build
go::build "-o" "myapp"
```

**Arguments:**
- `$@` - Additional build flags

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### go::test

Run tests.

```bash
go::test
go::test "./..."
```

**Arguments:**
- `$@` - Test arguments

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

### Module Management

#### go::mod_init

Initialize a new module.

```bash
go::mod_init "github.com/user/project"
```

**Arguments:**
- `$1` - Module path

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

#### go::mod_tidy

Tidy module dependencies.

```bash
go::mod_tidy
```

**Returns:** `PASS` (0) on success, `FAIL` (1) on error

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
```

### Install Development Tools

```bash
#!/usr/bin/env bash
source util.sh

go::install "github.com/golangci/golangci-lint/cmd/golangci-lint@latest"
go::install "golang.org/x/tools/cmd/goimports@latest"
go::install "github.com/air-verse/air@latest"
```

## Self-Test

```bash
source util.sh
go::self_test
```
