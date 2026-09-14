# Senntisten Shell

A personal, Nix-first desktop shell built with Quickshell. Named after the
Zarosian city, with a compact interface and richer tools on demand.

## First MVP: theme playground

This release is a **standalone normal window**, not a replacement desktop session.
It provides:

- A compact bar with a live clock and an expandable Appearance panel.
- Shared text, button, switch, surface, theme-option, and status components.
- Catppuccin Mocha and Gruvbox, switched live across every component.
- A persistent reduced-motion preference.
- A versioned local appearance file, atomic saves, visible failures, and retry-safe writes.
- Responsive scrolling with save/error feedback kept visible.
- Live QML reload while developing, without a NixOS rebuild.

It does **not** yet implement a launcher, workspace management, system tray,
notifications, locking, audio/network controls, or application-wide theme adapters.
It does not modify Noctalia, Caelestia, Hyprland configuration, or session startup.

## Run

```sh
cd /home/felipe/repos/senntisten-shell
nix run .
```

To edit the QML and see changes live:

```sh
nix develop
./bin/senntisten-shell
```

The development shell pins Quickshell and its Qt tooling together. No package
installation into your user profile or system activation is required.
The wrapper starts in the foreground and refuses a duplicate instance of the
same configuration. Close the window or press **Ctrl+Q** to exit.

For development state separate from normal use:

```sh
SENNTISTEN_STATE_DIR="$PWD/.cache/dev-state" ./bin/senntisten-shell
```

The default packaged app and a source checkout have different Quickshell
configuration identities. Prefer isolated state when running them together.

## Controls

| Input | Action |
|---|---|
| Appearance button / **Ctrl+,** | Show or hide the appearance panel |
| Palette card | Select and save that palette |
| Cycle palette / **Ctrl+T** | Select the next palette |
| Reduce motion | Disable color/position transitions and save the preference |
| **Tab / Shift+Tab** | Navigate controls |
| **Space** | Activate the focused button or switch |
| **Escape** | Close the appearance panel |
| **Ctrl+Q** | Quit the playground |

These shortcuts belong to the application window; they are not global desktop bindings.

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
change saves it. Invalid state falls back visibly without replacing the file until
you choose a valid setting. A newer schema is read-only to prevent silent downgrades.
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
python3 tests/integration.py
shellcheck bin/senntisten-shell
nixfmt --check flake.nix nix/package.nix
```

The Node tests exercise the real QML JavaScript catalog and the launcher's process
boundary. The Python integration runner starts **real Quickshell instances** with
isolated temporary source, cache, runtime, and state directories. It checks startup,
restarts, corrupt/newer state, save failures/retries, and source hot reload.
A QML QtTest harness additionally sends mouse and keyboard events to the actual
controls, checks narrow-window scrolling, exercises rapid changes, and samples
rendered pixels. The harness emits explicit pass/fail/skip counts because Quickshell
is not `qmltestrunner`; the Python runner rejects missing results or omitted cases.

These offscreen checks do not establish multi-monitor/session integration or
compatibility with every GPU/driver. Those belong to later shell milestones.

To capture actual rendered playground images during the control checks:

```sh
mkdir -p artifacts/screenshots
SENNTISTEN_CAPTURE_DIR="$PWD/artifacts/screenshots" \
  python3 tests/integration.py ShellIntegration.test_real_qml_controls
```

Artifacts are ignored by Git. With a real display this application can also be
launched normally for visual review; none of the tests require replacing your shell.

## Local diagnostics

For a development instance launched from this checkout, inside `nix develop`:

```sh
quickshell ipc --path ./shell call senntisten status
quickshell ipc --path ./shell call senntisten theme gruvbox
```

`status` reads the window's actual theme, background, readiness, and save state.
These are local Quickshell IPC calls, not a network service.

## Structure and next steps

See [Architecture](docs/architecture.md) for the boundaries and implementation notes.
The next increment is a real bar/launcher backed by shared actions, followed by an
opt-in Home Manager module and provider integration in `nix-config`.
Those are deliberately absent from this first MVP.
