# 007: Add Session Actions And Trusted Lock Delegation

Status: Planned
Priority: P2; security-sensitive
Dependencies: 002, 003, and explicit lock-provider/session-policy selection

## Goal

Make the session and lock command hooks functional through deliberate UI actions
and a trusted existing lock provider, without claiming session-lock ownership.

## Decisions Before Implementation

- Select the trusted lock provider and its command/readiness contract.
- Establish how successful locking is confirmed before suspend proceeds.
- Confirm which session actions are permitted and which require confirmation.
- Define availability and failure behavior when a provider or session service is missing.

## Acceptance Criteria

- [ ] The `session` command opens a keyboard-accessible menu; it does not immediately
  suspend, log out, reboot, or shut down.
- [ ] Destructive actions have deliberate confirmation and a safe cancellation path.
- [ ] The `lock` command delegates only to the explicitly configured secure provider.
- [ ] A cosmetic overlay, accepted command, or merely spawned process is not treated
  as proof that the session is securely locked.
- [ ] Missing providers, rejected requests, timeouts, and failed actions are visible
  and return appropriate nonzero command status.
- [ ] Suspend follows the agreed lock-before-suspend policy and aborts when the
  required lock confirmation fails.
- [ ] Prevent duplicate pending session requests and keep failed actions retryable.
- [ ] Nix hooks remain `null` for unconfigured capabilities.
- [ ] The menu follows Orbit's tokens, focus/escape behavior, and both palettes.

## Verification

Use recorder providers and a fake session boundary to assert ordering, confirmation,
cancellation, timeout, failure, and duplicate-request behavior. Test packaged
dispatch and real QML menu interaction without performing actual session actions.
Live lock/suspend/logout/power verification requires explicit approval.

## Boundaries

Do not stop or replace Noctalia/Caelestia, claim the session-lock protocol, register
global shortcuts, or enable startup services. Notification ownership and a native
Senntisten lock implementation remain separate later decisions.
