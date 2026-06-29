# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Log messages no longer split multi-arg commands onto separate lines.
  Under the project-mandated `IFS=$'\n\t'`, expansions like
  `${cmd[*]}` and `$*` join with a newline (the first character of
  IFS), so a call such as

      cp -p /root/bash_setup/dotfiles/bashrc /root/.bashrc

  was being logged as four lines instead of one:

      [DEBUG] Silent command succeeded: cp
      -p
      /root/bash_setup/dotfiles/bashrc
      /root/.bashrc

  Added `local IFS=' '` to the helper functions that build such log
  messages so the join uses a space without changing the caller's
  strict-mode IFS. Affected:
    - `lib/util.sh`: fallback `info` / `warn` / `error` / `debug` /
      `pass` / `fail`.
    - `lib/utils/util_cmd.sh::cmd::run_silent` (the function whose
      output the user reported).
    - `lib/utils/util_apt.sh::_apt_run`, `apt::install`.
    - `lib/utils/util_brew.sh::_brew_run`, `brew::install`,
      `brew::install_cask`.
    - `lib/utils/util_py_multi.sh::py_multi::set_versions`,
      `py_multi::pip_install_all`.
    - `lib/utils/util_tui.sh::tui::show_timer`.


## [2026.06.29.5] - 2026-06-29

### Added

- `install_extras.sh` (top-level, sibling to `install.sh`). One-shot
  system-side helper that installs the optional tools the
  `bash_setup` interactive shell expects (`eza`, `fzf`, `freeze`,
  `bat`, `duf`, `btop`), adds the eza-community signed apt repository
  under `/etc/apt/keyrings/gierens.gpg` +
  `/etc/apt/sources.list.d/gierens.list`, sweeps known-stale
  `/pentest/*` directory remnants, and runs apt cleanup.
  Previously lived at `bash_setup/install_extras.sh` (added in
  bash_setup v2026.06.29.2); moved here so it sits alongside the
  `net::proxy_auto_detect` helper it consumes. Prefers the in-repo
  `lib/util.sh` copy (works on a fresh `git clone` before
  `./install.sh` has been run), falls back to the deployed copy at
  `~/.config/bash/lib/common_core/util.sh`, and finally to inline
  log fallbacks if neither is reachable. Proxy detection delegates
  to `net::proxy_auto_detect` (added v2026.06.29.4) so installs
  pick the right transport by actual reachability, not by
  `command -v proxychains4`. CLI flags `--no-proxy`, `--proxy CMD`,
  and `--dry-run`; env vars `PROXY`, `DRY_RUN` honored.

## [2026.06.29.4] - 2026-06-29

### Added

- `lib/utils/util_net.sh`: three new helpers for proxy auto-detection
  based on actual reachability, not just whether `proxychains4`
  happens to be on PATH.
  - `net::has_direct_internet [timeout=2]` — silent TCP/443 probe
    against `1.1.1.1`, `8.8.8.8`, `9.9.9.9`. Returns PASS on the
    first endpoint that responds. Uses `platform::timeout` +
    bash's `/dev/tcp/` (matching `net::check_port`).
  - `net::proxychains_usable` — verifies `proxychains4` is on PATH
    AND a config file at `${PROXYCHAINS_CONFIG:-/etc/proxychains4.conf}`
    (or `/etc/proxychains.conf` or `${HOME}/.proxychains/proxychains.conf`)
    contains at least one real `socks4|socks5|http|raw` entry inside
    its `[ProxyList]` section. Rules out the common false-positive
    where the binary is installed but the dist-default config only
    has commented-out examples.
  - `net::proxy_auto_detect` — the high-level helper. Honors an
    explicitly-set `PROXY` (even an empty string) without probing,
    otherwise sets and exports `PROXY=""` when direct Internet
    works, `PROXY="proxychains4 -q"` when direct fails and
    proxychains4 is usable, or `PROXY=""` with a warn when neither
    is true (downstream calls likely to fail, surfaced loudly).
  Both downstream installers (`bash_setup/install_extras.sh`,
  `pentest_setup/config/config.sh`) now call
  `net::proxy_auto_detect` at startup instead of assuming
  `proxychains4` is correct just because it is installed.

## [2026.06.29.3] - 2026-06-29

### Fixed

- `util.sh` source-guard no longer exports `UTILS_SH_LOADED`.
  Previously `export UTILS_SH_LOADED=1` was the only `export`-style
  source-guard in the five-repo stack (every other dotfile uses
  `declare -g X_LOADED=true`). Combined with a parent shell that had
  `set -a` (`allexport`) on, the flag leaked into the env for every
  child process. SHELLOPTS is itself auto-exported by bash, so a
  child `./install.sh` would inherit `allexport`, then inherit
  `UTILS_SH_LOADED=1`, hit this guard, return immediately, and never
  define its fallback log functions (`info` / `pass` / `debug` /
  `warn` / `error` / `fail`) or declare its associative-array
  config registry (`UTIL_CONFIG`). The user-visible symptoms were
  `pass: command not found` / `debug: command not found` cascading
  through `install.sh`, and `file.safe_mode: syntax error: invalid
  arithmetic operator` -- the latter because `${UTIL_CONFIG[key]}`
  fell back to indexed-array semantics (arithmetic-evaluated
  subscript) when the associative-array declaration was missing.
  Changed to `declare -g UTILS_SH_LOADED=1`. The guard still works
  within a single shell (no double-source) but no longer poisons
  child processes that legitimately need a fresh init.

## [2026.06.29.2] - 2026-06-29

### Fixed

- `_apt_run` (lib/utils/util_apt.sh) no longer swallows stderr.
  Previously `tui::show_spinner -- "${cmd[@]}" > /dev/null 2>&1`
  threw away apt-get's actual error output, so a failed
  `apt-get update` surfaced as a generic "APT update failed" line
  with no underlying diagnostic. Captures combined stdout+stderr to
  a tempfile during the spinner run; on failure, dumps the last 40
  lines through the project logger at ERROR level so the real cause
  (network, sources.list, GPG, etc.) is visible. On success the
  tempfile is removed silently.
- `_curl_validate_proxy` / `_curl_build_proxy_args`
  (lib/utils/util_curl.sh) handle the project's dual PROXY
  convention without shouting. The downstream stack (bash_setup's
  bash.env.sh, pentest_setup's config.sh, scripts/bash/wireless.sh
  and pentest_setup/modules/tools/*.sh) uses `${PROXY}` as a
  command prefix ("proxychains4 -q "). common_core's curl helpers
  expect a URL form ("http://host:port"). On a fresh install with
  proxychains-style PROXY, `_curl_validate_proxy` was logging two
  ERROR lines for every curl operation and `_curl_build_proxy_args`
  was warning "Invalid PROXY format ignored". Added
  `_curl_proxy_is_url` heuristic: when `${PROXY}` does NOT contain
  `://`, it is treated as a command prefix and curl helpers skip
  `--proxy` injection silently (single debug line). URL form
  continues to be validated and injected as before.
- `dir::ensure_exists` (lib/utils/util_dir.sh) replaced the internal
  `dir::exists` call with a direct `[[ -d … ]]` test. `dir::exists`
  emits a WARN when a path is missing -- which is correct for an
  *existence query* -- but `dir::ensure_exists`'s only job is to
  create the path if missing, so callers that first probe with
  `dir::exists` and then call `dir::ensure_exists` were getting
  paired "Directory not found:" warnings for every required path.
  Affected callers include `pentest_setup/menus/01_environment.sh`,
  which iterates ~30 required directories and previously emitted ~60
  warnings on a fresh install.

## [2026.06.29.1] - 2026-06-29

### Added

- `install.sh` flag `-v, --version`. Prints the installer name and
  version (sourced from the `VERSION` global, which is loaded from the
  `VERSION` file at startup) and exits. Closes the last gap in the
  universal flag taxonomy across the four-repo stack — `common_core`
  now exposes the same `-h / -v / -q / -n / -f` set as `bash_setup`,
  `scripts`, and `pentest_setup`.

### Changed

- `README.md` rewritten end-to-end. The previous version was 52 lines
  with a duplicate `# H1` (`# Common Core` followed by
  `# Project Badges`), a stale "Last Commit" badge URL pointing at
  `/commits/main` (this repo's default branch is `master`), and no
  structured sections beyond a one-paragraph "Features" list. The new
  version mirrors the layout the other 3 repos in the stack adopted
  during their rewrites: overview, requirements, quick start (with
  every install.sh flag), repository layout (every `lib/utils/*.sh`
  module annotated), make-targets table, cross-repo contract, release
  workflow, style conventions.
- `.github/workflows/codacy.yml`: trigger branches `main` → `master`
  to match this repo's default branch. The workflow had never run
  because GitHub Actions silently no-ops when the `branches:` filter
  excludes every push / PR target. Same workflow body, same schedule
  (cron `39 20 * * 6`), same Codacy CLI pinned digest — only the
  branch filter changed.

## [2026.06.28.0] - 2026-06-28

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
