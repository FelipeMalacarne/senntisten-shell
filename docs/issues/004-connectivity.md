# 004: Implement Connectivity Controls

Status: Planned
Priority: P2
Dependencies: Confirm pinned network/Bluetooth APIs and service capabilities

## Goal

Replace the Planned network and Bluetooth tiles with real status and deliberate
actions while preserving Orbit's compact Quick Controls layout.

## Acceptance Criteria

- [ ] Select native adapters supported by the pinned Quickshell/Qt environment;
  any additional dependencies are declared through Nix.
- [ ] Network status handles wired, Wi-Fi, disconnected, connecting, unavailable,
  and failed states without invented connection information.
- [ ] Provide deliberate network selection/connect/disconnect actions and visible
  authentication or permission failures.
- [ ] Bluetooth exposes adapter state and device discovery, pairing, connection,
  and disconnection with visible transitions and errors.
- [ ] Prevent duplicate pending actions and correctly handle externally changed state.
- [ ] Keep frequent actions in Quick Controls and deeper preferences in Settings.
- [ ] Use shared icons/tokens, accessible names, keyboard navigation, and responsive
  layouts in both palettes.
- [ ] Remove Planned labels only for capabilities that actually work.
- [ ] Never store credentials in appearance state, repository files, or diagnostic logs.

## Verification

Add failing adapter/interaction tests with controlled provider fixtures before
implementation. Cover missing adapters/services, permission denial, cancellation,
timeouts, device disappearance, and live model changes. Inspect production QML
through the UI harness. Real network or pairing actions require explicit approval.

## Boundaries

Do not install system-wide dependencies imperatively, change the machine's network
configuration, or disconnect an active connection merely to validate the UI.
