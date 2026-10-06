# 002: Implement Stable Shell Commands

Status: Implemented; native activation remains gated by 001
Priority: P1
Dependencies: Existing desktop IPC; 001 gates activation

## Goal

Provide a stable packaged command interface that bindings and Nix integration can
invoke without knowing implementation-specific configuration paths or starting
another shell.

## Implementation

The source and packaged wrapper implement `ACTION [--pid PID]` for all five names.
The first three toggle the existing production controller. Session and lock report
unconfigured errors. Discovery requires an exact unique configuration match or an
explicit PID, followed by validation of the ready desktop status contract. Only a
literal `true` action reply succeeds. JSON parsing uses Nix-declared `jq`.

See [Shell Commands](../shell-commands.md) and the
[five-hook contract](../architecture.md#nix-command-contract).

## Acceptance Criteria

- [x] Document and implement stable dispatch for `launcher`, `dashboard`,
  `settings`, `session`, and `lock`.
- [x] Define show/toggle semantics and document repeated-invocation behavior.
- [x] `dashboard` invokes Quick Controls, never the appearance Settings window.
- [x] Define explicit instance selection and safe behavior when multiple source,
  packaged, preview, or playground instances exist.
- [x] Missing instances, wrong-mode instances, unavailable screens, unsupported
  actions, and rejected IPC replies produce actionable errors and nonzero exit codes.
- [x] Unconfigured session/lock actions fail clearly until 007 supplies their behavior.
- [x] Dispatch does not launch a duplicate process, daemonize, or create appearance
  state directories merely to request an existing surface.
- [x] Preserve literal argument forwarding and avoid shell evaluation of user input.
- [x] Verify the installed package interface, not only a source-path invocation.

## Verification

Add wrapper tests with a recorder executable and real isolated IPC tests. Include
two concurrent test instances and prove only the selected instance changes. Cover
missing-instance and negative replies even when the transport exits successfully.
Exercise packaged behavior across configuration/build identities without targeting
the user's running shell.

## Evidence

Added recorder and real-QML IPC cases failed before implementation (9 recorder
failures and 5 IPC failures). Final coverage includes 10 recorder cases and 7 IPC
cases, including two concurrent identities, an ambiguous shared identity, wrong
mode, foreign controllers, empty runtime, and no-screen rejection. No production
QML surface behavior was changed for this issue.

Commands run through the pinned development environment:

```sh
nix develop --no-write-lock-file --command node --test tests/commands.test.mjs
nix develop --no-write-lock-file --command python3 -m unittest discover -s tests -p commands_integration.py -v
make test
make fmt-check lint
nix flake check path:. --no-write-lock-file --print-build-logs
nix flake check path:. --no-write-lock-file --no-build --all-systems
make ui-check
```

The full x86_64 sandbox passes 51 unit tests, 69 integration tests, package smoke,
module checks, and lint. Its initial missing-`jq` failure was resolved by declaring
the dependency in runtime and test environments. Both supported systems evaluate;
aarch64 execution/build was not performed.

The installed-package smoke uses this build's production controller copied into
isolated configurations, replacing only Wayland layer wrappers. It verifies the
installed entry point and selection/failure behavior, not native surface mapping.
Positive cases use a source override or explicit PID; successful invocation of
the immutable default installed configuration still needs native evidence in 001.
Independent scoped review found no actionable dispatcher implementation issues.

Offscreen regression report:
`artifacts/ui/20261006T053714.413043Z-935204cf/index.html`.
Viewed images: `launcher-gruvbox.png`, `orbit-controls-catppuccin-mocha.png`,
`settings-gruvbox-narrow.png`, `settings-save-failure-narrow.png`,
`settings-newer-schema-narrow.png`, and `bar-keyboard-catppuccin-mocha-360.png`.
All five UI suites pass. These results do not close 001's compositor/GPU or
multi-monitor acceptance gap.

## Boundaries

No global shortcuts, autostart, or external Nix configuration edits. `session`
must not immediately perform a destructive action, and `lock` must never simulate
success with a cosmetic overlay.
