# Senntisten Shell

A personal, Nix-first desktop shell built with Quickshell. Named after the
Zarosian city, with a compact interface and richer tools on demand.

## Usable MVP

Senntisten now provides a real Hyprland shell baseline:

- A per-monitor layer-shell bar with live Hyprland workspaces, focused-window
  title, system tray, clock, and PipeWire output volume/mute controls.
- A full-screen overlay launcher backed by actual desktop entries, with bounded
  deterministic search, application icons, keyboard navigation, mouse activation,
  empty states, and native `DesktopEntry.execute()` launching.
- Orbit's edge-integrated bar, local NixOS entry-point icon, soft launcher panels,
  and compact workspace dots with full keyboard and pointer targets.
- Quick Controls with real output volume/mute and a separate Settings entry.
- A dedicated Settings window with Catppuccin Mocha and Gruvbox, live switching
  across all surfaces, plus persisted reduced motion and visible save failures.
- A separate component playground for developing themes without starting the bar.

It is intentionally not at Noctalia feature parity yet. Notifications, locking,
network/Bluetooth panels, brightness, global compositor keybindings, wallpaper
adapters, and Home Manager startup are later increments. Senntisten does not stop
Noctalia/Caelestia or alter Hyprland/session configuration by itself.

## Design studies

[Citadel and Orbit](docs/design/README.md) retain the interactive local browser
studies. Orbit revision 03 is the approved direction for the production bar,
launcher, Quick Controls, and Settings. The studies' wallpaper, app shelf, and
other planned services remain mock-only. Design approval does not activate or
replace your current shell.

## Run

During development, start with preview mode. It places the bar at the bottom
without reserving workspace area, so the configured shell can remain active:

```sh
cd /home/felipe/repos/senntisten-shell
nix run . -- --preview
```

Available modes:

| Mode | Behavior |
|---|---|
| `--preview` | Real bar and launcher at the bottom, with zero reserved space |
| `--desktop` (default) | Real top bar reserving 44 px; intended for replacement use |
| `--playground` | Standalone theme/component development window |

`--desktop` does not disable another bar; use preview until the Home Manager
provider is implemented and explicitly selected.

To edit the QML and see changes live:

```sh
nix develop
./bin/senntisten-shell --preview
```

The development shell pins Quickshell and its Qt tooling together. No package
installation into your user profile or system activation is required.
The wrapper starts in the foreground and refuses a duplicate instance of the
same configuration. Stop it with **Ctrl+C** in that terminal or the local `quit`
IPC action. `--help` explains modes without starting Quickshell or writing state.

For development state separate from normal use:

```sh
SENNTISTEN_STATE_DIR="$PWD/.cache/dev-state" ./bin/senntisten-shell --preview
```

The default packaged app and a source checkout have different Quickshell
configuration identities. Prefer isolated state when running them together.

## Controls

### Bar

| Input | Action |
|---|---|
| Distribution icon | Open the application launcher on that monitor |
| Workspace button | Activate the corresponding native Hyprland workspace |
| Tray left click | Activate the item, or open menu-only items |
| Tray right click / Shift+F10 | Open the native tray menu |
| Tray middle click / wheel | Send secondary activation / scroll to the item |
| Volume | Toggle Quick Controls, with output volume, mute, and ±5% controls |
| Settings icon | Show or hide the dedicated Settings window |

### Launcher

Start typing to filter by application name, generic name, and keywords. **Up/Down**
changes the selected result, **Enter** launches it, **Tab/Shift+Tab** moves focus,
and **Escape**, the Esc button, or clicking outside closes the overlay. Only desktop
entries are launched; unmatched search text is never interpreted as a command.

The MVP deliberately has no global keybinding. The bar's Apps button is always
available; a provider-specific Hyprland binding belongs in the later Nix integration.

### Quick Controls and Settings

Quick Controls contains real audio controls, not appearance preferences. Network
and Bluetooth tiles are disabled and explicitly marked Planned; they do not show
invented connection data. Its Settings entry opens the dedicated window. Closing
Settings returns to Quick Controls and restores focus to that entry when it was
the invoking surface. Closing Settings never exits desktop mode.

Settings offers live palette cards and reduced motion. Wallpaper, typography,
density, and deeper desktop/launcher preferences are visibly planned rather than
functional controls. The narrow window layout scrolls without hiding save errors.

### Appearance and playground

Palette cards save the selected theme. The reduced-motion switch disables component
transitions. Inside the playground, **Ctrl+,** toggles the panel, **Ctrl+T** cycles
themes, and **Ctrl+Q** exits. Keyboard focus scrolls hidden settings into view.

## Appearance state

Default location:

```text
$XDG_STATE_HOME/senntisten-shell/appearance.json
# fallback: ~/.local/state/senntisten-shell/appearance.json
```

Example schema:

```json
{
  "schemaVersion": 1,
  "theme": "catppuccin-mocha",
  "reducedMotion": false
}
```

Starting the application does not write a default appearance file. A deliberate
change saves it. Invalid, empty, or truncated state falls back visibly without
replacing the file until you choose a valid setting. A newer schema is read-only to
prevent silent downgrades.
Failed writes preserve the previous file and remain visible in the footer; select
a palette again after fixing the cause to retry. State is loaded at startup/reload;
external edits are not watched while the window is running.

The launch wrapper creates new state directories privately without changing the
permissions of existing directories. Do not point it at an unrelated data directory.

### Development overrides

| Variable | Purpose |
|---|---|
| `SENNTISTEN_STATE_DIR` | Absolute directory for isolated writable appearance state |
| `SENNTISTEN_SOURCE_DIR` | Directory containing `shell.qml`; useful for a development checkout |
| `SENNTISTEN_QUICKSHELL` | Quickshell executable override for compatibility testing |
| `SENNTISTEN_DISTRO_ID` | Explicit distribution branding; `nixos` by default, neutral icon for other IDs |

The Nix package owns the `distroId` default and provides local DejaVu fonts for
Orbit's sans, serif, and mono typography. It does not infer a distribution from
mock data or fetch icons/fonts at runtime. An existing `FONTCONFIG_FILE` override
is respected.

The wrapper uses Qt Quick Controls' Basic style so platform styles cannot silently
replace the custom component styling. It does not force a rendering backend for
normal launches.

## Checks

The canonical project check builds the package and runs the declared checks in Nix:

```sh
nix flake check --print-build-logs
nix build
```

Individual checks inside `nix develop`:

```sh
node --test tests/*.test.mjs
python3 -m unittest discover -s tests -p '*integration.py' -v
shellcheck bin/senntisten-shell
nixfmt --check flake.nix nix/package.nix
```

The Node tests exercise both QML JavaScript libraries, process-boundary launching,
mode selection, and layer-surface source contracts. Python integration tests start
**real Quickshell instances** with isolated source, desktop-entry, cache, runtime,
and state paths. The launcher suite discovers temporary `.desktop` files and proves
that native `DesktopEntry.execute()` invokes only their recorder programs.

QML QtTest harnesses send mouse and keyboard events to the actual launcher, bar,
audio, Settings, theme, and scrolling controls and sample rendered pixels. Orbit
checks cover live palettes, consistent result rows and gutters, workspace hit
targets, separate Settings routing, planned-service states, and narrow layouts.
The built-package
smoke check starts the packaged playground and verifies duplicate-instance behavior.
Harnesses emit explicit pass/fail/skip counts because Quickshell is not
`qmltestrunner`; the Python runners reject missing results or omitted cases.

Offscreen checks do not establish every compositor/GPU interaction. A native
Wayland preview must be reported separately from the automated suite; it is not
evidence that Home Manager startup or multi-monitor hotplug has been deployed.

To capture actual rendered playground and launcher images during control checks:

```sh
mkdir -p artifacts/screenshots
SENNTISTEN_CAPTURE_DIR="$PWD/artifacts/screenshots" \
  python3 tests/integration.py ShellIntegration.test_real_qml_controls
SENNTISTEN_CAPTURE_DIR="$PWD/artifacts/screenshots" \
  python3 tests/launcher_integration.py LauncherIntegration.test_real_launcher_controls
```

Artifacts are ignored by Git. With a real display this application can also be
launched normally for visual review; none of the tests require replacing your shell.

## Local diagnostics

For a desktop instance launched from this checkout, inside `nix develop`:

```sh
quickshell ipc --path ./shell call senntisten status
quickshell ipc --path ./shell call senntisten launcher
quickshell ipc --path ./shell call senntisten dashboard
quickshell ipc --path ./shell call senntisten settings
quickshell ipc --path ./shell call senntisten theme gruvbox
quickshell ipc --path ./shell call senntisten quit
```

`launcher`, `dashboard`, and `settings` toggle their respective surfaces on the
focused monitor and return whether a target was available. `dashboard` is Quick
Controls, not Settings. `status` reads desktop mode, screen count, target screen,
overlay/window visibility (including `dashboardOpen`), theme, and save state.
These are raw local Quickshell IPC calls, not a stable packaged command dispatcher
or a network service. Use `--pid` instead of `--path` to target a specific instance.

## Structure and next steps

See [Architecture](docs/architecture.md) for boundaries and implementation notes.
The next increment is an opt-in Home Manager module and `senntisten` provider in
`nix-config`, including the launcher keybinding. Notification/lock ownership remains
a later decision rather than being bundled into activation.
