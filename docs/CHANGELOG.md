# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.3] - 2026-01-17

### Added

- `CLAUDE.md` and `CLAUDE_HUMAN.md` - Project contract documentation for Claude Code

### Fixed

- Fixed shfmt formatting: spacing around redirections (`2>/dev/null` → `2> /dev/null`)
- Fixed function syntax in `tools/check_bash_style.sh`: added `function` keyword to `info()` and `error()`
- Added missing strict mode (`set -uo pipefail`) and IFS to example scripts
- Added proc-doc blocks to 12 functions in `lib/logger.sh`, `lib/utils/util_trap.sh`, and `examples/logging_example.sh`

### Changed

- All project gates now pass (style_blocks, function_syntax, proc_docs, shfmt, shellcheck)

## [0.0.2] - 2026-01-11

### Added

- `platform::timeout` - Cross-platform command timeout wrapper (GNU timeout / bash-native fallback)
- `platform::dns_flush` - Cross-platform DNS cache flush (macOS dscacheutil, Linux systemd-resolve/nscd)
- `platform::network_restart` - Cross-platform network service restart (macOS networksetup, Linux NetworkManager/systemd)

### Fixed

- Fixed temp file race condition in `platform::self_test` - now uses `mktemp` with restrictive permissions instead of predictable `$$` PID-based names
- Added proper cleanup trap using `RETURN` signal for temp file cleanup

### Security

- Addressed TOCTOU (time-of-check-time-of-use) vulnerability in self_test temp file handling
- Temp files now created with mode 600 immediately after creation

## [0.0.1] - 2024-12-15

### Added

- Initial release of common_core bash utility library
- Core utility loader (`lib/util.sh`) with dependency-ordered module loading
- Platform detection module (`util_platform.sh`) - Linux, macOS, WSL support
- Configuration management (`util_config.sh`) - centralized config with validation
- Trap handling (`util_trap.sh`) - signal and cleanup management
- String utilities (`util_str.sh`) - string manipulation functions
- Environment utilities (`util_env.sh`) - environment variable management
- Command utilities (`util_cmd.sh`) - command existence and execution helpers
- File utilities (`util_file.sh`) - safe file operations with path validation
- TUI utilities (`util_tui.sh`) - terminal user interface helpers
- OS utilities (`util_os.sh`) - OS-specific operations and detection
- Directory utilities (`util_dir.sh`) - directory management
- cURL utilities (`util_curl.sh`) - HTTP request wrappers
- Git utilities (`util_git.sh`) - Git operations
- Network utilities (`util_net.sh`) - network operations
- APT utilities (`util_apt.sh`) - Debian/Ubuntu package management
- Homebrew utilities (`util_brew.sh`) - macOS package management
- Python utilities (`util_py.sh`, `util_py_multi.sh`) - Python environment management
- Ruby utilities (`util_ruby.sh`) - Ruby/Gem management
- Go utilities (`util_go.sh`) - Go toolchain management
- Menu utilities (`util_menu.sh`) - interactive menu system
- Tools utilities (`util_tools.sh`) - external tool management
- Self-test functions (`::self_test`) in every module
- Cross-platform installer (`install.sh`) with `.bashrc` integration
- Bootstrap script (`bootstrap.sh`) for initial setup
- Comprehensive documentation in `docs/`
- GitHub Actions CI/CD workflows
- ShellCheck configuration (`.shellcheckrc`)
- EditorConfig for consistent formatting

### Security

- No `eval` in user-facing APIs
- Proper quoting throughout
- Input validation on all public functions
- Path traversal protection in file operations
