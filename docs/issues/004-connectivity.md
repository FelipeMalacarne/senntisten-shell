# 004: Implement Connectivity Controls

Status: Partially implemented and integrated; isolated verification complete; full native authentication/pairing acceptance open
Priority: P2
Dependencies: Pinned native Quickshell Networking/Bluetooth, system NetworkManager/BlueZ

## Goal

Replace the Planned network and Bluetooth tiles with real status and deliberate
actions while preserving Orbit's compact Quick Controls layout.

## Acceptance Criteria

- [x] Select native adapters supported by the pinned Quickshell/Qt environment;
  any additional dependencies are declared through Nix.
- [x] Network status handles wired, Wi-Fi, disconnected, connecting, unavailable,
  and failed states without invented connection information.
- [ ] Provide deliberate network selection/connect/disconnect actions and visible
  authentication or permission failures.
- [ ] Bluetooth exposes adapter state and device discovery, pairing, connection,
  and disconnection with visible transitions and errors.
- [x] Prevent duplicate pending actions and correctly handle externally changed state.
- [x] Keep frequent actions in Quick Controls and deeper preferences in Settings.
- [x] Use shared icons/tokens, accessible names, keyboard navigation, and responsive
  layouts in both palettes.
- [x] Remove Planned labels only for capabilities that actually work.
- [x] Never store credentials in appearance state, repository files, or diagnostic logs.

Unchecked items include full secured-network authentication and native Bluetooth
error/pairing-agent acceptance. The native action calls exist
and are fixture-verified; no live network, radio, or pairing action was performed.

## Provider Contract

`NetworkService.qml` and `BluetoothService.qml` are separate `Item` providers
composed as readonly `network` and `bluetooth` properties in `BarServices`.
They do not create windows, own notifications, start
agents, persist connectivity state, or execute CLI commands.

Both expose `available`, truthful human `status`, `error`, `pending`,
`pendingStatus`, `canCancel`, `cancel()`, `clearError()`, an injectable `provider`,
and `actionTimeoutMs` (30000 by default). Action methods return whether a request
was accepted, not whether it succeeded. Completion requires observed provider
state. External transitions also block duplicates. Timeouts end the local wait,
not the underlying connection; pending native transitions can remain visible.

| Provider | Models/State | Deliberate Actions |
| --- | --- | --- |
| Network | `devices`, flat `networks`, `wifiDevices`, `wifiAvailable`, `wifiEnabled`, `wifiHardwareEnabled`, `scanning` | `canConnect(network)`, `connectNetwork(network)`, `disconnectNetwork(network)`, `disconnectDevice(device)`, `setWifiEnabled(bool)`, `setScanning(bool)` |
| Bluetooth | `adapters`, selected default/fallback `adapter`, its `devices`, `radioEnabled`, `blocked`, `discovering` | `canAct(device)`, `setEnabled(bool)`, `setDiscovering(bool)`, `pairDevice(device)`, `connectDevice(device)`, `disconnectDevice(device)` |

Bluetooth radio state is **`radioEnabled`**, not `Item.enabled`. Network cancel
deliberately calls the selected pending network's `disconnect()`; Bluetooth cancel
uses `cancelPair()` only for a locally requested pairing. Power, discovery,
Bluetooth connect/disconnect, and external transitions have no supported cancel
action. A pairing timeout requests cancellation without advertising success.

Injected network providers supply `backendAvailable`, `devices` (array or object
model), `wifiEnabled`, and `wifiHardwareEnabled`. Bluetooth providers supply
`adapters` and `defaultAdapter`. Objects in those models follow the pinned native
QML properties/enums. Both boundaries implement `request(action, target, value)`,
`cancel(action, target)`, and signal `failed(string category)`. Network action tags
are `connect`, `disconnect`, `deviceDisconnect`, `wifi`, and `scan`; Bluetooth tags
are `power`, `discovery`, `pair`, `connect`, and `disconnect`. Failure categories
are sanitized to fixed user text; raw provider diagnostics/exceptions are discarded.

`NetworkControls.qml` and `BluetoothControls.qml` are expanding `ColumnLayout`
components with `required property var service`. They use shared tokens/icons and
fit 252px internal width. `AudioPanel` hosts them in `ShellScrollView` so Tab focus
reveals offscreen controls. Its initial tiles expand mutually exclusive detail
views and retain error text/accessibility when collapsed. Settings routing remains
separate. Pending/blocked/unsupported actions are disabled.

## Pinned APIs And Limits

Inspected installed qmltypes through `nix develop`: Quickshell **0.3.0**, Qt
**6.11.2**, nixpkgs `9fbb54b33e91ee4ca368e35a78e0613c720600b3`.
Metadata lives under
`/nix/store/j1xwwpwicfgbpwri1fqqk4p1n9fi2i7d-quickshell-0.3.0/lib/qt-6/qml/Quickshell/{Networking,Bluetooth}/`.
No dependency source was cloned. No new Nix/runtime executable dependency is
needed; `nmcli` is not used (the development shell's discovered system `nmcli`
was not a pinned package dependency).

Network uses `Networking.devices`, backend and Wi-Fi properties,
`Network.connect()/disconnect()`, `NetworkDevice.disconnect()`,
`WifiDevice.scannerEnabled`, and typed `connectionFailed(ConnectionFailReason)`.
Only open or saved networks are supported here. Unknown secured Wi-Fi is disabled
with an external-credential-agent explanation. No password field,
`connectWithPsk()`, secret CLI argument, or secret logging/storage is introduced.
Launching/configuring a native external NetworkManager credential agent for new
secured networks remains unimplemented, not silently claimed as working.

Bluetooth uses `Bluetooth.adapters/defaultAdapter`, adapter `enabled`/
`discovering`, live device states, `pair()/cancelPair()/connect()/disconnect()`.
The pinned Bluetooth API has **no operation-result/error signal or pairing-agent
API**. Native permission/auth failures can therefore surface only as bounded
timeout feedback explaining system authorization/agent requirements. Categorized
fixture failures verify the UI error path, not nonexistent native failure signals.
Pairing requiring PIN/confirmation relies on an existing system BlueZ agent;
this implementation neither registers nor starts one. Only the selected adapter's
devices are controlled. Live multi-adapter, RF-kill, authorization and agent flows
need explicitly approved native verification.

## Verification

Add failing adapter/interaction tests with controlled provider fixtures before
implementation. Cover missing adapters/services, permission denial, cancellation,
timeouts, device disappearance, and live model changes. Inspect production QML
through the UI harness. Real network or pairing actions require explicit approval.

### Recorded Evidence (2026-10-06)

- RED: `nix develop --command python3 tests/connectivity_integration.py` failed on
  missing production connectivity types before implementation.
  Log: `artifacts/connectivity/20261006T125119-680335Z/quickshell.log`.
- Additional RED/GREEN: external radio-off left a connection pending
  (`20261006T130120-281365Z`); fixed to end the wait with visible feedback
  (`20261006T130149-571659Z`). A provider-Item/radio-state regression failed before
  the `radioEnabled` split (`20261006T130752-621683Z`) and passed after it.
- Evidence-harness RED/GREEN: PNG dimension assertions caught a clipped 252px image
  mislabeled as 340px (`20261006T130452-051151Z`). Resizing the real Qt window,
  rather than its content item, fixed it. Checkpoint controls are also asserted
  nonempty, not inferred from screenshots.
- GREEN: `nix develop --command python3 -W error::ResourceWarning tests/connectivity_integration.py`:
  **17 real QtTest behavioral cases, 18 PNG/checkpoint pairs**.
  Evidence: `artifacts/connectivity/20261006T131226-019891Z/`.
  Coverage includes native startup on dead buses, states, live models, duplicates,
  cancellation, timeout, auth/permission feedback, discarded diagnostics, radio-off,
  disappearance/object destruction, pointer selection/cancellation, normal Tab
  traversal, 252/340px widths, and a 200px-tall containing scroll view.
- Viewed actual PNGs in that final evidence directory: `selection-network-pending.png`,
  `selection-bluetooth-pending.png`,
  `catppuccin-mocha-340.png`, `gruvbox-252.png`,
  `gruvbox-short-keyboard-focus.png`, `catppuccin-mocha-unavailable.png`,
  `gruvbox-errors.png`, and `gruvbox-empty.png`. Read the final
  `gruvbox-short-keyboard-focus.json`, including accessible names, clipping and
  actual focused/revealed Bluetooth power control.
- Shared owner integration replay passed with
  `nix develop --command env TMPDIR=/home/felipe/repos/senntisten-shell python3 tests/ui_harness.py --scene controls --actions tests/ui-actions/connectivity.json --width 340 --height 520 --theme catppuccin-mocha`.
  Report: `artifacts/ui/20261006T130852.376513Z-1c1e80f2/index.html`.
  The same command with `--theme gruvbox --reduced-motion` passed:
  `artifacts/ui/20261006T131250.171301Z-cc651649/index.html`.
  Viewed the former report's `001-click.png` and the latter report's `004-click.png`.
- Historical shared regression command at the lane handoff
  `nix develop --command env TMPDIR=/home/felipe/repos/senntisten-shell python3 tests/ui_check.py --suite controls --suite bar`
  **failed**, while its connectivity suite passed. Report:
  `artifacts/ui/20261006T131250.159283Z-4216cfdd/index.html`.
  The Quick Controls fixture still used Bluetooth `enabled` instead of
  `radioEnabled`; the bar fixture lacked required connectivity/media services.
  The older bar runner also exceeded the IPC socket-path limit with the
  repository-local `TMPDIR`. These shared files were not edited in this scope.
- Owned QML files were formatted via `qmlformat -i`; comparison against
  `qmlformat` output passed. `qmllint` with both pinned Quickshell and Qt import
  roots retained two Bluetooth qmltypes resolution warnings (`UntypedObjectModel`
  and `BluetoothAdapter` references); native QML execution passed without those
  errors. No lint suppression or pinned-store edit was added.
- `nix develop --command env TMPDIR=/home/felipe/repos/senntisten-shell node --test tests/bar.test.mjs tests/launcher.test.mjs tests/search.test.mjs tests/theme.test.mjs`:
  **41 passed**. Full flake/package/live acceptance was not claimed.

The dedicated runner creates disposable HOME/XDG/state/source/runtime directories
inside the repository and removes them afterward. Both D-Bus addresses point to
nonexistent isolated paths; PipeWire is unavailable; DISPLAY, WAYLAND identities
and HYPRLAND variables are removed. Evidence is offscreen/software Qt, not proof
of compositor focus, layer surfaces, real NetworkManager/BlueZ actions, native
authorization, GPU rendering, or daemon recovery. No shared production/test/Nix
file was modified by the connectivity lane. Shared integration changes and final
verification are recorded below; no commit was made.

### Final Integration (2026-10-06)

- The single integration owner composed the providers in `BarServices` and all
  feature controls in `AudioPanel`. Native bar composition had a behavioral RED
  before the binding change, then GREEN. Collapsed error feedback also had a
  failing behavioral case before its implementation. The shared fixture now uses
  `radioEnabled` and tests populated output/microphone controls rather than only
  disabled placeholders.
- `make test`, `make ui-check`, `make fmt-check`, `make lint`, and
  `nix flake check path:. --no-write-lock-file --print-build-logs` all pass.
  This includes 51 unit tests, 72 Python integration tests, 17 named connectivity
  Qt cases, 11 Quick Controls Qt cases, and 20 bar Qt cases. Flake verification
  includes the packaged shell/smoke checks on x86_64-linux, not aarch64-linux.
- Final UI report: `artifacts/ui/20261006T132436.477703Z-f48ee91c/index.html`.
  The integration owner opened `orbit-controls-catppuccin-mocha.png` and
  `orbit-controls-bluetooth-gruvbox.png` there, plus earlier full-panel and
  unavailable captures in both palettes.
- Final provider artifacts: `artifacts/connectivity/20261006T132516-142391Z/`.
  Viewed `selection-network-pending.png` and `gruvbox-errors.png` there. The fixed
  wide capture `artifacts/connectivity/20261006T131226-019891Z/catppuccin-mocha-340.png`
  was opened and is genuinely 340px wide, without the earlier host clipping.
- Final short-panel pointer/keyboard replays passed in both palettes, including
  output selection, independent microphone volume/mute, Settings and close actions.
  Exact replay commands and reports are in [006's final evidence](006-audio-media.md#final-integration-2026-10-06).
- The earlier handoff failures are superseded for the standard pinned environment
  and Nix sandbox. Arbitrarily long custom `TMPDIR` paths still inherit Unix IPC
  path-length limits. Native network/radio/pairing actions, credential/PIN agents,
  compositor behavior and daemon recovery remain unverified and require approval.

## Boundaries

Do not install system-wide dependencies imperatively, change the machine's network
configuration, or disconnect an active connection merely to validate the UI.
