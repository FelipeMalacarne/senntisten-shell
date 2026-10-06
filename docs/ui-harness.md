# Native UI Harness

The fastest safe loop for agents is **render, inspect, interact, assert, rerender**.
Use the pinned Nix environment. No display, browser recreation of the UI, new
dependency, or desktop activation is needed.

## Commands

```sh
make ui-check
make ui-check UI_ARGS='--suite launcher --suite settings'
make ui-inspect UI_ARGS='--scene launcher --actions tests/ui-actions/launcher.json'
make ui-inspect UI_ARGS='--scene controls --actions tests/ui-actions/controls.json'
make ui-inspect UI_ARGS='--scene controls --actions tests/ui-actions/connectivity.json'
make ui-inspect UI_ARGS='--scene controls --width 340 --height 320 --actions tests/ui-actions/controls-short.json'
make ui-inspect UI_ARGS='--scene settings --actions tests/ui-actions/settings.json'
make ui-inspect UI_ARGS='--scene bar --actions tests/ui-actions/bar.json'
```

Inside `nix develop`, the equivalent commands are `python3 tests/ui_check.py` and
`python3 tests/ui_harness.py`. Both support `--help` and `--output PATH`. Omitted
output creates a unique directory in `artifacts/ui/`; an existing explicit path
is refused, never cleared or reused. Artifacts are Git-ignored.

`ui-check` runs the existing real-control regressions, covering both palettes,
responsive geometry, keyboard/mouse interactions, unavailable audio, launcher
execution, Settings persistence, save failures, and newer schemas. It rejects
failed suites and missing/invalid expected screenshots. It is not pixel-baseline
comparison: agents still need to inspect the rendered images for visual quality.

`ui-inspect` renders production `BarContent`, `LauncherContent`, `AudioPanel`, or
the actual dedicated Settings `App`, not a browser mock. Bar, output devices, and
microphone use clearly identified fixtures. Connectivity and media see deliberately
unavailable isolated D-Bus endpoints; provider-specific suites exercise controlled
models and recorders. The launcher discovers isolated `.desktop` files whose
native `execute()` calls only write recorder markers. Bar buttons/close/settings
signals are counted, not routed into desktop layer surfaces. Use the existing
desktop integration suite for controller routing.

## Inspect The Evidence

Each run prints its `index.html` report path. Open PNGs directly with your image
tool; the report is only a local screenshot gallery, not an interactive shell.

| Artifact | Purpose |
| --- | --- |
| `index.html` | Native screenshot gallery with links to evidence and logs |
| `manifest.json` | Success/failure, provenance, image dimensions and hashes |
| `quickshell.log` or suite logs | QML diagnostics and real test results |
| `000-initial.png`, `001-type.png`, etc. | Render before interaction and after each replay action |
| Matching checkpoint `.json` | Action/error, theme, save status, visibility, geometry, controls and focus |
| `appearance.json` | Final isolated appearance file, when a regular file exists |
| `launches.json` | Isolated native desktop-entry execution records |

Checkpoint controls expose `objectName`, `accessibleName`, `enabled`, `visible`,
`activeFocus`, window-relative `geometry`, ancestor-clipped `visibleGeometry`, and
`inViewport`. Text, selection, checked/value, hover/press and scroll properties are
included where available. Discover targets from the JSON rather than guessing
coordinates. Repeated decoration names can be ambiguous; prefer the unique
control name or exact accessible name. `$view` targets the scene root.

Use a fresh rerun after editing source. The harness copies the current shell into
a disposable config root, so a running test is not a hot-reloading development
instance. Revision/dirty status are provenance, not proof that a later worktree
still matches a previously captured image.

## Action Replays

Pass `--actions` a JSON array. Every step generates a screenshot and JSON snapshot
unless the action hides its window, in which case JSON records `visible: false`
and no image. Failures stop replay, retain the failing checkpoint when rendering
is possible, and return nonzero. Expectations poll briefly rather than assuming
asynchronous UI/state updates are immediate.

```json
[
  {"op": "type", "target": "launcherSearch", "text": "journal"},
  {"op": "expect", "target": "launcherCount", "property": "text", "value": "1 match"},
  {"op": "key", "key": "Tab"},
  {"op": "key", "key": "Return"}
]
```

| Operation | Fields and behavior |
| --- | --- |
| `click` | `target`; optional `button`: `Left`, `Right`, `Middle`; `x`, `y` fractions default to center |
| `hover` | `target`; optional `x`, `y` fractions |
| `drag` | `target`; `fromX`, `fromY`, `toX`, `toY` fractions, defaults `(0.2,0.5)` to `(0.8,0.5)` |
| `wheel` | `target`; `dx`, `dy` integer wheel deltas, e.g. `dy: -120` |
| `type` | `target`, `text`; clicks the field and sends Qt key events; replaces text unless `replace: false` |
| `key` | Qt key suffix, e.g. `Tab`, `Backtab`, `Space`, `Return`, `Escape`, `Down`; optional `modifiers` array of `Control`, `Shift`, `Alt`, `Meta` |
| `focus` | `target`; explicitly forces component focus, may trigger its reveal-on-focus logic |
| `expect` | `target`, `property`, `value`; asserts a property equals the supplied JSON value |
| `resize` | `width`, `height`; resizes the real offscreen window |
| `reset` | Reshows the scene and invokes its normal initial-focus/search reset where available |
| `wait` | Optional `ms`, defaults to 200; bounded at 3000 |

Pointer events are mapped through the real window and rejected when the target
is disabled, hidden, or the requested point is clipped. They do not call button
handlers directly or automatically scroll a hidden control into view. `focus`
is a diagnostic affordance, not evidence that Tab navigation can reach a control.
For keyboard acceptance, start from normal initial focus and send Tab/Backtab.
For pointer acceptance, scroll/drag until the target is visible, then click it.

## Visual Matrix

Render each changed surface in both palettes and at a narrow viewport:

```sh
make ui-inspect UI_ARGS='--scene launcher --width 360 --height 360 --theme gruvbox'
make ui-inspect UI_ARGS='--scene settings --width 320 --height 360 --theme catppuccin-mocha'
make ui-inspect UI_ARGS='--scene settings --state newer --width 320 --height 360'
make ui-inspect UI_ARGS='--scene settings --state corrupt --width 320 --height 360'
make ui-inspect UI_ARGS='--scene settings --state save-failure --actions tests/ui-actions/settings.json'
make ui-inspect UI_ARGS='--scene controls --unavailable --theme gruvbox'
make ui-inspect UI_ARGS='--scene launcher --empty-catalog --width 360 --height 360'
```

`--reduced-motion` seeds the isolated preference. `--state` supports `normal`
(default saved palette), `missing` (first launch), `corrupt`, `newer`, and
`save-failure` (appearance path becomes a directory after successful load). In `save-failure`, a deliberate
palette change should visibly report a save error; the generic Settings replay
still checks the selected preview, not successful persistence.

`--unavailable` disables output/microphone/compositor fixtures in bar/controls scenes;
`--empty-catalog` removes the launcher fixture entries before startup.

Check layout/clipping, readable feedback, alignment, icons, contrast, focus and
selection distinction, hover, empty results, scrollbar behavior, and errors. The
clock/date remain real and time-dependent; hashes identify images, not stable
visual goldens.

## Verification Gate

1. Add a failing behavioral regression to the relevant `tests/*-ui.qml` or Python
   integration suite before changing production behavior. Show RED, then GREEN.
2. Use inspection replays to reproduce pointer/keyboard behavior with assertions.
   Promote important discovered regressions into the normal suites; do not leave
   acceptance solely in an ad hoc replay.
3. Run `make ui-check`, inspect actual PNGs for changed surfaces, and run applicable
   `make test`, `make fmt-check`, `make lint`, and `make check` gates.
4. Report exact commands, pass/fail outcomes, artifact paths, images actually viewed,
   and any unverified native behavior. Never say "visually verified" if only tests
   or source patterns were inspected.

Nix's Git-backed `.` flake excludes untracked files. While adding new tests or
harness files, use `nix flake check path:. --no-write-lock-file --print-build-logs`
to include them without staging or committing anything.

## Safety And Limits

Every replay has disposable HOME/XDG state/config/data/cache/runtime and source,
unavailable D-Bus/PipeWire endpoints, offscreen Qt, and software rendering. Inherited
display/compositor identities are removed. No production IPC driver, arbitrary
JavaScript evaluator, global input injection, or session startup is added.

This proves component rendering and Qt event handling, not layer-shell mapping,
compositor-granted keyboard focus, native popup dismissal, reserved workspace
area, live tray menus/audio, GPU output, multi-monitor hotplug, or provider startup.
Browser automation of `docs/design/` or this report is not native acceptance.
Live preview/native Wayland verification needs explicit approval or an explicitly
supplied disposable compositor. Isolated state alone does not isolate a display;
never invoke display-connected tests automatically or restart an existing shell.
