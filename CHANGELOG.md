# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2026.09.16.1] - 2026-09-16


### Fixed

- `py::get_pip_args` no longer drops flags after the pip operation. Under the
  file-wide `IFS=$'\n\t'` its `"${args[*]}"` joined arguments with a newline, so
  every caller's `read` grabbed only the first line ("install") and silently
  dropped `--break-system-packages`. It now space-joins on one line, and the
  four `py::pip_*` callers that used a bare `read` now split on whitespace
  (`IFS=$' \t\n' read -ra`), matching the two that already did. Net effect: on
  PEP 668 hosts (Ubuntu 24.04) system-wide `pip install` was failing with
  "externally-managed-environment" because the override flag never reached pip.
- `py::pip_supports_break_system_packages` detection is now version-based
  (pip major >= 23, where `--break-system-packages` landed in 23.0.1) with the
  previous `pip help install` scrape kept as a secondary signal. The scrape
  alone returned no match on some hosts, so the flag was reported unsupported
  even where pip supports it.

## [2026.09.16.0] - 2026-09-16


### Changed

- `tools::install_git_python` creates the per-tool venv with `uv venv` when
  `PY_INSTALLER=uv` (faster; provisions its own interpreter, so it no longer
  depends on a working `python -m venv`), falling back to `python -m venv`
  otherwise. The `./venv` layout is unchanged, so `run_tools_command` finds it
  either way.

### Fixed

- APT operations now wait for the dpkg lock on **every** call. `_apt_run`
  waits before each apt/dpkg invocation and passes
  `-o DPkg::Lock::Timeout` (inert on apt < 2.0, whose config parser ignores
  unknown keys) so apt-get blocks instead of exiting 100, retrying up to
  `APT_LOCK_RETRIES` times on pure lock contention. `apt::_wait_for_lock` was
  previously called from exactly one place -- `apt::update` -- so on a freshly
  booted cloud image, where unattended-upgrades holds the lock for minutes,
  every `apt::install` failed instantly: 9 of 15 packages in one
  `install_tools.sh` run (tree, unzip, eza, fzf, bat, ncat, duf, btop, dialog)
  were lost, while the tail of the same list installed fine once the lock
  cleared.
- `apt::install` no longer runs the repair cascade on a lock failure. `dpkg
  --configure -a` and `apt-get -f install` need the very lock they cannot get,
  so "repairing" produced ~40 lines of identical lock errors per package and
  buried the real cause; it now fails fast with an actionable message. The
  duplicated repair-and-reinstall block (one copy gated on `apt.auto_repair`,
  an identical one unconditionally after it) is collapsed into one, which also
  makes `apt.auto_repair` meaningful again -- the unconditional copy had been
  repairing regardless of the setting.
- `apt::_wait_for_lock` honors `APT_LOCK_TIMEOUT` and no longer returns a false
  all-clear when `fuser` is missing (it ships in psmisc, absent from minimal
  images; the loop exited immediately on command-not-found).
- `install_tools.sh`: `have_command` also looks in `${GOPATH:-~/go}/bin`, so a
  binary `go install` just placed there (`freeze`) no longer verifies as
  missing and fails the run. The bootstrap runs before `bash_setup` deploys
  `bash.path.sh`, and in a non-login shell, so `~/go/bin` is legitimately not
  on PATH yet; `check_go_path` now says that plainly instead of implying
  something is misconfigured.
- `go::install_tool` now pins `GOTOOLCHAIN` to the latest release (resolved via
  new `go::latest_version`) and installs Go if absent. `GOTOOLCHAIN=auto` only
  upgrades when a module's go.mod has a `go >=` directive, so `+incompatible`
  modules (e.g. bettercap) built with a too-old base toolchain and failed
  (`requires go >= 1.26.0`). Pinning forces a modern toolchain download.
- `dir::exists` is now a quiet predicate -- a missing directory logs at debug,
  not `warn`. It is used as `if dir::exists X` before creating/cloning, so the
  negative case was emitting false-alarm "Directory not found" noise.
- `tools::install_git_python`'s legacy `setup.py install` fallback is now debug
  only. Modern setuptools removed `setup.py install` and the pip steps already
  install the package, so the "setup.py install failed (non-fatal)" WARN was
  pure noise.
- `py::install_uv` now bootstraps uv via **pipx** first (PEP 668-safe, isolated
  venv), falling back to system pip. It previously ran `python3 -m pip install
  -U uv` system-wide, which Ubuntu 24 refuses with
  `externally-managed-environment`, so `PY_INSTALLER=uv` could never install uv.
- `py::_use_uv` attempts the uv bootstrap at most once per run and caches
  failure. Previously every `py::pip_install`/`py::pipx_install`/`tools::_pip`
  call retried the failing install, repeating the PEP 668 error for every
  package. On failure it now warns once and falls back to pip/pipx quietly.
- `py::install_python` no longer reduces a bare `major.minor` version to the
  major only. `${version%.*}` turned `3.13` into `3`, so it installed the
  generic `python3` and falsely reported "Python 3.13 installed" while
  `python3.13` never existed (downstream pip/lib steps then silently skipped).
  Now strips only a patch component, and verifies the versioned interpreter is
  actually present before claiming success (apt/brew can report success for a
  meta-package).
- `_apt_run` now reports the real command exit code. An `if cmd; then ...; fi`
  with no `else` yields 0 when the condition is false, so the code read after
  `fi` was always 0 -- failures logged as "APT command failed (exit 0)". The
  status is now captured inline (`|| rc=$?`).
- `apt::repair` now runs `dpkg --configure -a` (unproxied; dpkg is local)
  before `apt-get -f install`. An interrupted dpkg blocks every apt operation
  with "dpkg was interrupted..."; `apt-get -f install` alone cannot clear it,
  so installs and the auto-repair both looped and failed.
- `_apt_package_exists` no longer prefixes the LOCAL `apt-cache show`/`policy`
  with `${PROXY}`. Under the project-wide `IFS=$'\n\t'` the multi-token
  prefix did not word-split, so `${PROXY} apt-cache ...` tried to exec the
  literal `proxychains4 -q ` and failed for EVERY package -- marking valid
  packages "invalid or unavailable". It also ran a full `apt-get update` per
  missing package (minutes each); the index is now refreshed at most once per
  run (`_APT_CACHE_REFRESHED`).
- `_brew_package_exists` / cask validation had the same word-split bug on
  `${PROXY} brew search`; now routed through `net::proxy_prepend` (brew search
  is networked, so the proxy is kept but split into argv correctly).

### Added

- `apt::package_available <pkg>` -- public check for whether a package exists
  in the APT repos (thin wrapper over the local apt-cache lookup). Lets callers
  distinguish a legitimately-absent package (skip) from a real install failure.
- `git::` and `py::` helpers now route through `${PROXY}` on hosts that need
  proxychains, via a new shared `net::proxy_prepend`. Previously `git::clone`
  (used by ~24 pentest_setup tool modules), `git::pull`, `py::pipx_install`,
  `py::pip_install`, `py::install_pipx`, and `py::install_uv` shelled out to
  `git`/`pipx`/`pip` directly, so on a proxy-only host every git-clone and
  pip/pipx-based tool install failed to reach the network. `${PROXY}` empty
  (direct Internet) leaves the commands unchanged. Matches the earlier
  `curl::` fix; tools/scripts still only ever set `${PROXY}`.
- `tools::install_git_python` (the helper behind ~58 pentest_setup tool
  modules) now routes its in-venv `pip install` steps and `setup.py install`
  through `${PROXY}` (new `tools::_pip`), matching the `git::clone` it already
  uses. Previously the clone could be proxied but the package installs went
  direct, so tools still failed to install on a proxy-only host.
- Python installer backend selection via `PY_INSTALLER` (`pip` default | `uv`).
  `py::pip_install`/`py::pipx_install` and `tools::install_git_python`'s
  `tools::_pip` now route through `uv pip` / `uv tool` when `PY_INSTALLER=uv`
  (auto-installing uv if missing); `py::uv_install` gained a `py::uv_tool_install`
  sibling. All uv paths are proxied via `${PROXY}` like the pip paths.

- `PROXYCHAINS_CMD` is now defined canonically in `lib/utils/util_net.sh` (the
  stack's base library), honoring an override: `: "${PROXYCHAINS_CMD:=proxychains4 -q }"`.
  `net::proxy_auto_detect` now BUILDS `PROXY` from it (`PROXY="${PROXYCHAINS_CMD% }"`,
  trailing space trimmed) instead of a separate hardcoded literal, so there is
  one source of truth for the proxychains invocation.

- Unified persistent env API in `lib/utils/util_env.sh`: `env::file` (the one
  sourceable env file, `~/.config/bash/pentest.env.sh`, override `PENTEST_ENV_FILE`),
  `env::persist KEY VALUE` (upsert a value into the file's MANAGED block and
  export it, so new shells inherit it), and `env::reload` (re-source the file
  now). Complements the existing in-shell `env::set`/`get`/`unset`.

### Fixed

- `curl::` helpers now route through a command-prefix `${PROXY}` (e.g.
  `proxychains4 -q`). `_curl_exec_body`/`_curl_exec_file` previously only
  honored URL-form PROXY (via `--proxy`) and silently ran `curl` directly for
  the command-prefix form, so every `curl::download`/`curl::get` caller across
  the stack (the pentest_setup tool installers, etc.) bypassed proxychains on
  proxy-only hosts. New `_curl_prepend_proxy` prepends the prefix to the curl
  command array.

### Added

- `net::proxy_load` / `net::proxy_save` / `net::proxy_conf_path` in
  `lib/utils/util_net.sh`: a persisted `${PROXY}` default. `net::proxy_save`
  auto-detects (via `net::proxy_auto_detect`) and writes `PROXY=...` to
  `~/.config/bash/proxy.conf` (override with `PROXY_CONF`); `net::proxy_load`
  reads it at shell/script startup without touching the network. Precedence:
  an explicit `PROXY` in the environment wins, then the config file, then empty.

### Changed

- `install_tools.sh` now configures the signed eza-community apt repository
  (`/etc/apt/keyrings/gierens.gpg` + `/etc/apt/sources.list.d/gierens.list`)
  on Debian/Kali before installing `eza`, since `eza` is not in the base apt
  repos. The step is a no-op on macOS/Homebrew and when `eza` is already
  present or not selected; it honors `--dry-run` and `${PROXY}`.

### Removed

- `install_extras.sh` — its tool installation duplicated `install_tools.sh`,
  and the one thing it uniquely owned (the eza-community apt repo setup) is
  now folded into `install_tools.sh`. System maintenance already lives in
  `system_maintenance.sh`.

### Added

- `install_tools.sh` — OS-aware external-tool bootstrapper for the whole
  stack. A single declarative table (`group | platforms | mode | commands |
  apt | brew | description`) drives install and verification across both apt
  (Debian/Kali) and Homebrew (macOS). It resolves the package manager from
  the detected OS rather than from PATH-probe order (so a Linux host with
  Homebrew installed still installs Debian package names), and never probes,
  installs, or reports a tool that does not apply to the host — the GNU `g*`
  tools are macOS-only, `xclip`/`wl-paste` are Linux-only. Supports
  `--check` (audit, no privileges), `--list` (prints the table, marking rows
  this host will skip), `--group`, `--dry-run`, and a `PROXY` prefix.
  Consolidates the tool-install intent previously scattered across
  `install_extras.sh`, `bash_setup`'s `RECOMMENDED_TOOLS`, and each repo's
  `Makefile` gates.
- `system_maintenance.sh` — standalone Debian/Kali maintenance pass extracted
  from `install_extras.sh`: `apt update && apt upgrade`, removal of stale
  `/pentest/*` tool checkouts, `apt` cleanup, and a disk-usage report. Phase
  flags `--no-upgrade` / `--no-sweep` / `--no-cleanup`; OS-guarded,
  root-required, proxy-aware, dry-run capable. Holds the single canonical
  copy of the stale-directory list.

### Changed

- `install.sh` now detects a previous install (via the `VERSION` marker at
  `INSTALL_DIR`) and, when run interactively, prompts before overwriting or
  updating it. `-f`/`--force` bypasses the prompt; `--dry-run` never prompts;
  a non-interactive shell proceeds (the prompt is an interactive safety net).
- `install_extras.sh` is now OS-aware: `require_apt_platform` refuses to run
  on non-apt hosts (before demanding a sudo password) with a pointer to
  `install_tools.sh`. Raises the log level to `info` so success is no longer
  silent, and adds `ncat` to the apt tool list (declared by `bash_setup` but
  previously never installed by anything).
- `install_extras.sh` no longer runs `go install` as root — it drops to the
  invoking `SUDO_USER` so `freeze` lands in that user's `GOPATH/bin` instead
  of `/root/go/bin`, off their PATH.
- `install_extras.sh` no longer performs system maintenance: the `apt
  upgrade` step, the `/pentest/*` sweep, `apt` cleanup, and the disk-usage
  report moved to `system_maintenance.sh`. This removes a second copy of the
  stale-directory list and keeps provisioning from silently upgrading every
  installed package as a side effect.

## [2026.06.29.8] - 2026-06-29

### Fixed

- `py::install_pipx` now prefers `apt install pipx` on systems where
  apt is available, falling back to `python3 -m pip install -U pipx`
  with `--break-system-packages` if apt cannot deliver. Previously
  it went straight to pip, which fails with
  `error: externally-managed-environment` on Ubuntu 24+ and Debian
  bookworm+ (PEP 668). The new ordering matches what those distros
  document as the supported install path. The `--break-system-packages`
  flag is harmless on older pip releases that do not recognise PEP
  668.


## [2026.06.29.7] - 2026-06-29

### Fixed

- `_apt_run`, `_brew_run` (homebrew install + general brew calls),
  and `net::get_external_ip` were using `read -ra cmd <<< "${PROXY}"`
  to split a multi-token PROXY prefix like `"proxychains4 -q"` into
  argv elements. `read` honors IFS, and the project-wide
  `IFS=$'\n\t'` does NOT include a space, so PROXY ended up as a
  single token (`cmd[0]="proxychains4 -q "` — with the trailing
  space). Bash then tried to exec that literal string as a binary
  name, producing the cascading error:

      util_tui.sh: line 303: proxychains4 -q : command not found

  on every apt / brew call. Switched the four sites to
  `IFS=$' \t\n' read -ra cmd <<< "${PROXY}"` so the read uses the
  default field splitter only for that one command, leaving the
  rest of the calling shell's IFS untouched.


## [2026.06.29.6] - 2026-06-29

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
