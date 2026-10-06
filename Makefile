.DEFAULT_GOAL := help

NIX ?= nix
NIX_FLAGS ?= --no-write-lock-file
DEV := $(NIX) develop $(NIX_FLAGS) --command

.PHONY: help run-preview run-desktop playground develop fmt fmt-check lint \
	test-unit test-integration test ui-check ui-inspect test-package-smoke package-smoke build check ci clean

help:
	@printf '%s\n' \
		'Senntisten Shell commands:' \
		'  make run-preview       Run the bar/launcher at the bottom without reserving space' \
		'  make run-desktop       Run the top-bar desktop mode (does not stop another shell)' \
		'  make playground         Run the standalone theme playground' \
		'  make develop            Enter the pinned Quickshell development shell' \
		'  make fmt                Format Nix and QML sources in place' \
		'  make fmt-check          Check Nix/QML formatting and whitespace' \
		'  make lint               Run ShellCheck and qmllint' \
		'  make test-unit          Run Node unit tests' \
		'  make test-integration   Run real offscreen Quickshell integration tests' \
		'  make test               Run unit and integration tests' \
		'  make ui-check           Run UI regressions and collect fresh screenshots/logs' \
		'  make ui-inspect         Inspect real QML; UI_ARGS="--scene settings --actions ..."' \
		'  make test-package-smoke Build the package and test its launcher/duplicate guard' \
		'  make build              Build the packaged shell' \
		'  make check              Run the complete Nix flake checks' \
		'  make ci                 Run formatting, lint, tests, and Nix checks' \
		'  make clean              Remove ignored local artifacts'

run-preview:
	$(NIX) run $(NIX_FLAGS) . -- --preview

run-desktop:
	$(NIX) run $(NIX_FLAGS) . -- --desktop

playground:
	$(NIX) run $(NIX_FLAGS) . -- --playground

develop:
	$(NIX) develop $(NIX_FLAGS)

fmt:
	$(DEV) nixfmt flake.nix nix/package.nix
	$(DEV) bash -c 'for file in shell/*.qml shell/components/*.qml shell/desktop/*.qml shell/services/*.qml tests/*.qml; do test -f "$$file" && qmlformat -i "$$file"; done'

fmt-check:
	$(DEV) nixfmt --check flake.nix nix/package.nix
	$(DEV) bash -c 'set -e; tmp=$$(mktemp); trap "rm -f $$tmp" EXIT; for file in shell/*.qml shell/components/*.qml shell/desktop/*.qml shell/services/*.qml tests/*.qml; do if test -f "$$file"; then qmlformat "$$file" > "$$tmp"; diff -u "$$file" "$$tmp"; fi; done'
	git diff --check

lint:
	$(DEV) bash -n bin/senntisten-shell
	$(DEV) shellcheck bin/senntisten-shell
	$(DEV) bash -c 'qs=$$(readlink -f "$$(command -v quickshell)"); imports=$$(dirname "$$(dirname "$$qs")")/lib/qt-6/qml; qmllint -I "$$imports" shell/shell.qml'

test-unit:
	$(DEV) node --test tests/*.test.mjs

test-integration:
	$(DEV) python3 -m unittest discover -s tests -p '*integration.py' -v

test: test-unit test-integration

ui-check:
	$(DEV) python3 tests/ui_check.py $(UI_ARGS)

ui-inspect:
	$(DEV) python3 tests/ui_harness.py $(UI_ARGS)

test-package-smoke:
	@package=$$($(NIX) build $(NIX_FLAGS) --no-link --print-out-paths); \
	$(DEV) env SENNTISTEN_PACKAGE="$$package" python3 -W error::ResourceWarning tests/package_smoke.py

package-smoke: test-package-smoke

build:
	$(NIX) build $(NIX_FLAGS) --no-link --print-out-paths

check:
	$(NIX) flake check $(NIX_FLAGS) --print-build-logs

ci: fmt-check lint test check

clean:
	git clean -fdX -- artifacts
