# Roadmap

This file outlines near-term goals and may change based on feedback.

## Done

- `Makefile` exposing `make ci` (fmt-check + lint + bats) and the
  surrounding `fmt`, `lint`, `test`, `style`, `install`, versioning,
  and `clean` targets.
- GitHub Actions CI (`.github/workflows/main.yml`) running shellcheck,
  shfmt -d, and bats on push and PR.
- BATS unit coverage for `str::`, `env::`, `file::`, `dir::`, and
  `cmd::` helpers (108 tests).
- Style-compliance pass across `tools/*.sh` (`function name()` form,
  reserved-variable disables with rationale).
- Doc/source drift cleanup: `docs/CHANGELOG.md` now points at the
  canonical root `CHANGELOG.md`; README badge and "various" typo fixed.

## Next

- Expand BATS coverage to: `util_git`, `util_curl`, `util_net`,
  `util_apt`, `util_brew`, `util_os`, `util_platform`, `util_config`,
  `util_trap`, `util_tui`, `util_py`, `util_py_multi`, `util_ruby`,
  `util_go`, `util_menu`, `util_tools`. Modules that depend on external
  package managers, network access, or the host shell belong in
  `tests/integration/` rather than `tests/unit/`.
- Populate `tests/integration/` (currently a `.gitkeep`) with
  end-to-end tests for installer flows and external-tool wrappers.
- Rewrite the five `docs/util_*.md` files that currently reference
  functions absent from their source modules (detected by
  `tools/check_docs.sh`, runnable as `make check-docs`):
  - `docs/util_apt.md`: `apt::add_repo` (source name is
    `apt::add_repository`), `apt::full_upgrade`, `apt::purge`,
    `apt::remove`, `apt::search`.
  - `docs/util_brew.md`: `brew::cask_install` (source name is
    `brew::install_cask`), `brew::cask_uninstall`, `brew::reinstall`,
    `brew::search`, `brew::untap`.
  - `docs/util_config.md`: `config::load` (source is
    `config::load_from_file`), `config::save` (source is
    `config::save_to_file`), `config::from_env` (source is
    `config::load_from_env`), `config::unset`, `config::is_locked`,
    `config::get_path`.
  - `docs/util_curl.md`: `curl::get_content_type`,
    `curl::is_url_reachable`, `curl::url_encode`, `curl::with_bearer`.
  - `docs/util_tui.md`: `tui::get_terminal_height`,
    `tui::prompt_password`.
- Once the rewrites are in, promote `make check-docs` to a CI gate so
  drift can't reappear.
- Consider splitting `install.sh` (~29 KB single file) once it grows
  further; current size is acceptable but invites drift.

## Later

- Replace the manual color-palette `# shellcheck disable=SC2034`
  blocks with a single sourced `lib/colors.sh` (or similar) once a
  caller actually wants them; today they are documented placeholders.
- Reconsider `lib/util.sh`'s level-filtered fallback loggers: the
  current `_util_should_log <lvl> && printf …; return 0` form works,
  but a single `case` dispatch would be easier to reason about and
  would not depend on the `return 0` workaround.
