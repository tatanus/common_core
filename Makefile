SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

SHFMT_OPTS := -i 4 -ci -sr

# Versioning
VERSION_FILE ?= VERSION
SEMVER_RE    := ^[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?$

# --------------------------------------------------------------------
# Help
# --------------------------------------------------------------------
.PHONY: help
help: ## Show help
	@awk 'BEGIN{FS=":.*##"; print "Targets:"} /^[a-zA-Z0-9_.-]+:.*##/{printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# --------------------------------------------------------------------
# Code quality
# --------------------------------------------------------------------
.PHONY: fmt fmt-check lint test ci style
fmt: ## Format with shfmt (writes in place)
	@bash tools/format.sh

fmt-check: ## Check formatting without writing
	@bash tools/format.sh --check

lint: ## Lint with shellcheck
	@bash tools/lint.sh

test: ## Run bats tests (unit + integration)
	@bash tools/test.sh all

style: ## Run comprehensive style checks
	@bash tools/check_bash_style.sh

check-docs: ## Detect drift between docs/util_*.md and lib/utils/util_*.sh
	@bash tools/check_docs.sh

ci: fmt-check lint test ## Format check + lint + test (non-mutating)

# --------------------------------------------------------------------
# Versioning
# --------------------------------------------------------------------
.PHONY: version show-version set-version tag release release-today check-version
version show-version: ## Print current version
	@if [ ! -f "$(VERSION_FILE)" ]; then echo "0.0.0" > $(VERSION_FILE); fi
	@echo "Version: $$(cat $(VERSION_FILE))"

set-version: ## Set VERSION file (V=MAJOR.MINOR.PATCH)
	@test -n "$(V)" || (echo "Usage: make set-version V=1.2.3" && exit 2)
	@echo "$(V)" | grep -Eq '$(SEMVER_RE)' || (echo "Invalid version: $(V)"; exit 2)
	@echo "$(V)" > $(VERSION_FILE)
	@git add $(VERSION_FILE)
	@git commit -m "chore: bump version to $(V)" || true
	@echo "Set version to $(V)"

tag: ## Create annotated git tag from VERSION
	@test -f $(VERSION_FILE) || (echo "Missing $(VERSION_FILE)"; exit 2)
	@v=$$(cat $(VERSION_FILE)); \
		echo "$$v" | grep -Eq '$(SEMVER_RE)' || { echo "Invalid version: $$v"; exit 2; }; \
		git tag -a "v$$v" -m "Release v$$v"; \
		echo "Tagged v$$v"

release: ci ## Cut release: stamp CHANGELOG + bump VERSION + commit + tag + push (V=YYYY.MM.DD.N)
	@test -n "$(V)" || { echo "Usage: make release V=2026.06.25.0"; exit 2; }
	@echo "$(V)" | grep -Eq '$(SEMVER_RE)' || { echo "Invalid version: $(V)"; exit 2; }
	@test -z "$$(git status --porcelain)" || { echo "Working tree not clean; commit or stash first"; exit 2; }
	@test -f CHANGELOG.md || { echo "CHANGELOG.md not found"; exit 2; }
	@grep -q '^## \[Unreleased\]' CHANGELOG.md || { echo "CHANGELOG.md has no [Unreleased] section"; exit 2; }
	@! grep -q "^## \[$(V)\] " CHANGELOG.md || { echo "CHANGELOG.md already has [$(V)] entry"; exit 2; }
	@today=$$(date -u +%Y-%m-%d); \
		awk -v v="$(V)" -v d="$$today" '/^## \[Unreleased\]/{print; print ""; print "## [" v "] - " d; next} 1' CHANGELOG.md > CHANGELOG.md.tmp \
		&& mv CHANGELOG.md.tmp CHANGELOG.md \
		|| { rm -f CHANGELOG.md.tmp; echo "Failed to stamp CHANGELOG"; exit 2; }
	@echo "$(V)" > $(VERSION_FILE)
	@git add $(VERSION_FILE) CHANGELOG.md
	@git commit -m "chore(release): cut $(V)"
	@git tag -a "v$(V)" -m "Release v$(V)"
	@git push --follow-tags
	@echo "Released v$(V)"

release-today: ## Cut release using today's UTC date (override with N=1 for 2nd cut of day)
	@$(MAKE) --no-print-directory release V=$$(date -u +%Y.%m.%d).$${N:-0}

check-version: ## Validate VERSION file format
	@test -f $(VERSION_FILE) || (echo "Missing $(VERSION_FILE)"; exit 2)
	@v=$$(cat $(VERSION_FILE)); \
		echo "$$v" | grep -Eq '$(SEMVER_RE)' || { echo "Invalid version: $$v"; exit 2; }; \
		echo "VERSION OK: $$v"

# --------------------------------------------------------------------
# Install
# --------------------------------------------------------------------
.PHONY: install
install: ## Install the library to ~/.config/bash/lib/common_core
	@bash install.sh

# --------------------------------------------------------------------
# Cleanup
# --------------------------------------------------------------------
.PHONY: clean
clean: ## Clean temp files
	find . -type f -name '*.tmp' -delete 2>/dev/null || true
	find . -type f -name '.DS_Store' -delete 2>/dev/null || true
