# 001: Close The Native Verification Gap

Status: Planned
Priority: P0
Dependencies: Explicit approval for the target display or a supplied disposable compositor

## Goal

Establish that the implemented Orbit bar, launcher, Quick Controls, and Settings
behave correctly on Wayland, rather than treating offscreen or injected Qt events
as sufficient evidence of compositor interaction.

## Current Gap

Offscreen rendering and interaction checks pass. Native Qt surface tests also
exercise the real wrappers, but recent compositor-pointer retries were affected
by game pointer constraints or hardware input interference. The current pointer
smoke test only supports one scale-1 monitor at origin 0,0. GPU rendering and
multi-monitor behavior still need explicit evidence.

## Acceptance Criteria

- [ ] Reproduce compositor-delivered clicks in an idle, ungrabbed-pointer session.
- [ ] Launcher, Settings, and Quick Controls open both before and after hover hints.
- [ ] Launcher receives keyboard focus; search, navigation, native fixture
  activation, Escape, close, and outside-click dismissal work.
- [ ] Quick Controls dismisses correctly and its Settings route restores the
  intended surface and focus when Settings closes.
- [ ] Closing Settings keeps desktop mode running.
- [ ] Preview reserves no workspace area; desktop mode reserves only its 44-pixel bar.
- [ ] Verify screen targeting, popup placement, monitor removal, and relevant
  scaling/geometry on multiple monitors using a suitable test setup.
- [ ] Inspect both palettes on the GPU-backed renderer, including icons, clipping,
  focus cues, and transparent panel corners.
- [ ] Retain logs, rendered evidence, PID/namespace observations, and exact commands.

## Verification

Use the offscreen harness as a baseline, then run native checks only after approval:

```sh
make ui-check
SENNTISTEN_WAYLAND_TEST_APPROVED=1 \
  nix develop --no-write-lock-file --command python3 -B tests/wayland_smoke.py -v
```

The environment flag records permission; setting it is not itself approval.
Extend or supplement the current single-monitor smoke test before claiming
multi-monitor/scaling acceptance. Diagnose pointer constraints separately from
shell failures. Do not silently focus another application or override a game grab.

## Boundaries

Create only isolated test surfaces and clean up only their processes. Restore any
test pointer movement. Do not restart the user's shell, change session startup,
alter compositor configuration, or launch personal applications as test fixtures.
