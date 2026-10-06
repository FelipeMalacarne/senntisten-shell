# 003: Export The Opt-In Nix Module

Status: Implemented; external integration and activation remain separate
Priority: P1
Dependencies: 002

## Goal

Export a typed, reusable Nix/Home Manager integration from this repository while
keeping package installation, command availability, and desktop activation distinct.

## Acceptance Criteria

- [x] Export and document the module through the flake.
- [x] Provide typed package and shell-default options using the pinned dependencies.
- [x] Support the consumer's `my.desktop.shellCommands` contract for `launcher`,
  `dashboard`, `settings`, `session`, and `lock`.
- [x] Each command hook is `lib.types.nullOr lib.types.str`, defaulting to `null`;
  populate values only for explicitly configured, usable capabilities.
- [x] Generated commands use 002's packaged dispatcher and instance-selection rules.
- [x] Enabling package installation alone does not enable autostart, global
  keybindings, notification ownership, or lock replacement.
- [x] Nix owns defaults/dependencies, not the mutable appearance file.
- [x] Evaluate disabled and configured module fixtures, including type failures
  and unconfigured session/lock hooks.
- [x] Document the separately approved external provider integration/activation steps.

## Verification

Use repository-local module evaluation fixtures and Nix checks. Verify generated
command strings and defaults without activating NixOS or Home Manager. Build the
resulting package and test command behavior with disposable instances.

## Implementation And Evidence

`homeManagerModules.default` exposes `programs.senntisten-shell`. Installation,
command exposure, optional positive PID selection, and the declarative `distroId`
default are typed independently. The default package retains this flake's pin;
custom packages are used unchanged. All five output hooks are read-only nullable
strings, with session and lock remaining null.

See [Home Manager Integration](../home-manager.md) for options and the explicit
external consumer bridge.

The initial evaluation failed before the module export existed. GREEN commands:

```sh
make test-module
make test
make fmt-check lint
nix flake check path:. --no-write-lock-file --print-build-logs
nix flake check path:. --no-write-lock-file --no-build --all-systems
```

All 17 module cases pass. The report is
`/nix/store/zyh4h87ava9d0yvnm5sh7xgc1mwd4rs9-senntisten-shell-home-manager-tests`.
Coverage includes disabled/install-only/commands-only modes, custom packages,
escaping, explicit PID, invalid types, unknown options, null unavailable hooks,
and absence of startup/state/provider definitions. An independent scoped review
found no actionable Nix implementation issues.

Full x86_64 sandbox checks also pass the installed-package dispatcher smoke,
51 unit tests, and 69 integration tests. Both systems evaluate; aarch64 was not
built. Fixtures declare only the minimal `home.packages` boundary, not a full
Home Manager deployment. No configuration was activated.

## Boundaries

Do not edit `/home/felipe/repos/nix-config`, register a live `senntisten` provider,
stop Noctalia/Caelestia, or change session startup under this issue's implementation
approval. External integration and activation require a separate decision.
