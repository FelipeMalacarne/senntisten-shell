# 002: Implement Stable Shell Commands

Status: Planned
Priority: P1
Dependencies: Existing desktop IPC; 001 gates activation

## Goal

Provide a stable packaged command interface that bindings and Nix integration can
invoke without knowing implementation-specific configuration paths or starting
another shell.

## Current Gap

Raw IPC exposes launcher, dashboard, and Settings toggles. The launch wrapper is
not yet an action dispatcher, and configuration identities differ between source
and packaged builds. The exact command syntax and show/toggle semantics are not
finalized. Follow the [five-hook contract](../architecture.md#planned-nix-command-contract).

## Acceptance Criteria

- [ ] Document and implement stable dispatch for `launcher`, `dashboard`,
  `settings`, `session`, and `lock`.
- [ ] Define show/toggle semantics and document repeated-invocation behavior.
- [ ] `dashboard` invokes Quick Controls, never the appearance Settings window.
- [ ] Define explicit instance selection and safe behavior when multiple source,
  packaged, preview, or playground instances exist.
- [ ] Missing instances, wrong-mode instances, unavailable screens, unsupported
  actions, and rejected IPC replies produce actionable errors and nonzero exit codes.
- [ ] Unconfigured session/lock actions fail clearly until 007 supplies their behavior.
- [ ] Dispatch does not launch a duplicate process, daemonize, or create appearance
  state directories merely to request an existing surface.
- [ ] Preserve literal argument forwarding and avoid shell evaluation of user input.
- [ ] Verify the installed package interface, not only a source-path invocation.

## Verification

Add wrapper tests with a recorder executable and real isolated IPC tests. Include
two concurrent test instances and prove only the selected instance changes. Cover
missing-instance and negative replies even when the transport exits successfully.
Exercise packaged behavior across configuration/build identities without targeting
the user's running shell.

## Boundaries

No global shortcuts, autostart, or external Nix configuration edits. `session`
must not immediately perform a destructive action, and `lock` must never simulate
success with a cosmetic overlay.
