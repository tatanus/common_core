# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `install.sh` flags `-q, --quiet` and `-n, --dry-run`. Brings the
  universal flag set in line with `bash_setup`, `pentest_setup`, and
  `scripts`. `--quiet` is wired into the fallback log functions
  (suppresses `info` / `pass` / `debug`; keeps `warn` / `error` / `fail`).
  `--dry-run` reports what the install would do (create directory,
  copy `lib/*`, write VERSION marker, set permissions, run self-tests)
  and exits before any mutation.

### Changed

- `tools/check_bash_style.sh` updated from `scripts`' canonical version.
  Adds a filter that skips backslash-escaped backticks (`\\\``) when
  searching for command-substitution backticks. Heredocs that emit
  Markdown READMEs use escaped backticks for inline-code formatting;
  the previous check would have false-positive on those. The four
  repos in the stack (`common_core`, `bash_setup`, `pentest_setup`,
  `scripts`) now share a byte-identical `tools/check_bash_style.sh`.

## [2026.06.27.0] - 2026-06-27

### Fixed

- Four ShellCheck disable directives extended from `SC2329` to
  `SC2317,SC2329` so they cover both older and newer ShellCheck
  versions. ShellCheck 0.10 split the original SC2317
  ("Command appears to be unreachable") into SC2317 (general
  unreachable code) and SC2329 (function never invoked). My local
  ShellCheck 0.11 reports SC2329 for log-fallback declarations and
  trap-callback helpers; the Ubuntu LTS apt-installed ShellCheck used
  by CI (older than 0.10) still reports SC2317 for the same condition,
  so the SC2329-only disables silenced nothing on CI. Affected sites:
    - `install.sh:53` — `fail()` log-fallback declaration
    - `lib/utils/util_trap.sh:388` — `_trap_test_cleanup_func` (invoked
      indirectly by `trap::add_cleanup` in the same self-test)
    - `tests/run_self_tests.sh:74,79` — `error()` and `debug()`
      log-fallback declarations
  No behavior change. The disable comments now also explicitly note
  why both rule numbers are listed so future readers do not strip one.

## [2026.06.25.0] - 2026-06-25

### Added

- `Makefile` exposing the documented `make ci` workflow plus `help`, `fmt`,
  `fmt-check`, `lint`, `test`, `style`, `install`, `version`, `set-version`,
  `tag`, `release`, `check-version`, `clean` targets. All quality targets
  delegate to `tools/*.sh` so they remain the single source of truth.
- `.github/workflows/main.yml` CI pipeline (Ubuntu) installing pinned
  `shfmt` v3.8.0, running `make lint`, `make fmt-check`, `make test`.
  Resolves the previously broken `main.yml` build-status badge in
  `README.md`.
- BATS unit-test suite under `tests/unit/`:
  - `test_util_str.bats` (43 tests, `str::` helpers)
  - `test_util_env.bats` (16 tests, `env::` helpers)
  - `test_util_file.bats` (18 tests, `file::` helpers)
  - `test_util_dir.bats`  (15 tests, `dir::` helpers)
  - `test_util_cmd.bats`  (16 tests, `cmd::` helpers + `cmd::exists`)
  - Total: 108 tests, all passing locally.
- `tests/helpers/load_lib.bash` BATS helper that bootstraps `lib/util.sh`
  with logging silenced.

### Changed

- `tools/lint.sh` and `tools/format.sh` now exclude `.claude/` from
  discovery (matching `tools/check_bash_style.sh`). The `.claude/`
  directory is agent toolchain scaffolding maintained externally.
- `tools/check_bash_style.sh`, `tools/format.sh`, `tools/lint.sh`,
  `tools/test.sh`: converted bare `name() {` declarations to the
  mandated `function name() {` form (matching `lib/`).
- `docs/CHANGELOG.md` is now a one-line pointer to the canonical root
  `CHANGELOG.md` to eliminate drift between the two copies.

### Fixed

- **`str::to_title_case`** (lib/utils/util_str.sh): only the first word
  was being capitalized because the function relied on space-splitting,
  but `util.sh` sets `IFS=$'\n\t'`. Restored a local `IFS=$' \t\n'` so
  word-splitting actually splits on spaces.
- **Fallback log functions in `lib/util.sh`** (`info`/`warn`/`error`/
  `debug`/`pass`/`fail`): each was implemented as
  `_util_should_log <lvl> && printf …`. When the configured log level
  filtered the message, the `&&` chain short-circuited and the function
  returned 1, causing callers under `set -e` to abort silently. Each
  fallback now ends with `return 0`.
- `tools/lint.sh`: fixed "Adam COmpton" typo in file header.
- `README.md`: fixed "varius" typo (now "various"); broken `main.yml`
  build-status badge now resolves to the new CI workflow.
- ShellCheck cleanup across the library and tooling:
  - `lib/utils/util_cmd.sh:735` and `lib/utils/util_tools.sh:468`:
    removed dead `output=$(…)` captures that were never read; replaced
    with silent execution (`> /dev/null 2>&1`).
  - `lib/utils/util_file.sh:1254`: dropped unused `test_file` local.
  - `lib/utils/util_platform.sh`: brace-quoted `$key` array indices
    (`${arr_ref[$key]}` → `${arr_ref[${key}]}`).
  - Reserved-but-unused color palettes, exposed config defaults, and
    nameref-accessed arrays now carry explicit
    `# shellcheck disable=…` directives with rationale.

### Removed

- `tests/unit/test_example.{sh,bats}` scaffolding (the in-file note said
  "delete when adding your own tests").

## [2026.01.19.0] - 2026-01-19


## [2026.01.17.0] - 2026-01-17

### Added

- `CLAUDE.md` and `CLAUDE_HUMAN.md` - Project contract documentation for Claude Code

### Fixed

- Fixed shfmt formatting: spacing around redirections (`2>/dev/null` → `2> /dev/null`)
- Fixed function syntax in `tools/check_bash_style.sh`: added `function` keyword to `info()` and `error()`
- Added missing strict mode (`set -uo pipefail`) and IFS to example scripts
- Added proc-doc blocks to 12 functions in `lib/logger.sh`, `lib/utils/util_trap.sh`, and `examples/logging_example.sh`

### Changed

- All project gates now pass (style_blocks, function_syntax, proc_docs, shfmt, shellcheck)

## [2026.01.11.0] - 2026-01-11

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

## [2024.12.15.0] - 2024-12-15

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
