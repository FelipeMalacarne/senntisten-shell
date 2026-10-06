# 003: Export The Opt-In Nix Module

Status: Planned
Priority: P1
Dependencies: 002

## Goal

Export a typed, reusable Nix/Home Manager integration from this repository while
keeping package installation, command availability, and desktop activation distinct.

## Acceptance Criteria

- [ ] Export and document the module through the flake.
- [ ] Provide typed package and shell-default options using the pinned dependencies.
- [ ] Support the consumer's `my.desktop.shellCommands` contract for `launcher`,
  `dashboard`, `settings`, `session`, and `lock`.
- [ ] Each command hook is `lib.types.nullOr lib.types.str`, defaulting to `null`;
  populate values only for explicitly configured, usable capabilities.
- [ ] Generated commands use 002's packaged dispatcher and instance-selection rules.
- [ ] Enabling package installation alone does not enable autostart, global
  keybindings, notification ownership, or lock replacement.
- [ ] Nix owns defaults/dependencies, not the mutable appearance file.
- [ ] Evaluate disabled and configured module fixtures, including type failures
  and unconfigured session/lock hooks.
- [ ] Document the separately approved external provider integration/activation steps.

## Verification

Use repository-local module evaluation fixtures and Nix checks. Verify generated
command strings and defaults without activating NixOS or Home Manager. Build the
resulting package and test command behavior with disposable instances.

## Boundaries

Do not edit `/home/felipe/repos/nix-config`, register a live `senntisten` provider,
stop Noctalia/Caelestia, or change session startup under this issue's implementation
approval. External integration and activation require a separate decision.
