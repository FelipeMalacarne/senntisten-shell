# Architecture

## Product boundary

Senntisten is a personal shell, not a cross-distribution desktop environment.
The long-term direction is compact desktop chrome, powerful panels and launcher,
live appearance switching, and personal applications that share the same UI kit.

The usable MVP owns a real per-monitor bar and application-launcher overlay. It
does not own notification-server or session-lock protocols, register global
shortcuts, alter compositor configuration, or start itself as a service. Preview
mode renders a bottom bar with no exclusive zone while another shell remains active.

## Source layout

```text
shell/shell.qml              composition root
shell/Desktop.qml            screens, bar/launcher/settings ownership, local IPC
shell/App.qml                appearance window and reload-popup policy
shell/Playground.qml         component canvas and appearance controls
shell/PlaygroundRoot.qml     isolated normal-window development entrypoint
shell/desktop/Bar.qml        per-screen layer surface and Quick Controls popup
shell/desktop/AudioPanel.qml Quick Controls with live audio and a Settings entry
shell/desktop/BarContent.qml live workspaces, tray, audio, clock, and actions
shell/desktop/BarServices.qml native Hyprland, SystemTray, and PipeWire adapter
shell/desktop/Launcher.qml   focused overlay layer surface
shell/desktop/LauncherContent.qml desktop-entry search and activation UI
shell/components/            shared presentation components
shell/services/Theme.qml     theme state, asynchronous persistence, transactions
shell/lib/ThemeCatalog.js    pure presets and versioned state codec
shell/lib/ApplicationSearch.js pure deterministic desktop-entry ranking
bin/senntisten-shell         safe source/package launch wrapper
nix/package.nix             package with pinned runtime paths
flake.nix                   package, dev environment, and checks
```

### Appearance

The catalog defines semantic color roles rather than component-specific colors.
Components consume `Theme.colors`; alternate palette cards intentionally render
their candidate swatches. Appearance state stores the palette identifier and the
reduced-motion setting, not a copy of all tokens.

Colors and fonts in this MVP affect only Senntisten. Future terminal/GTK/Qt/editor
adapters must advertise whether they apply live, reload a target, or require restart.
Nix remains responsible for installed software, defaults, and dependencies; it must
not own the writable file that the UI updates.

### Desktop composition

`Desktop.qml` creates one `Bar` per `Quickshell.screens` entry and one launcher
overlay targeted to the focused Hyprland monitor. Bar buttons and local IPC call
the same controller functions. Appearance remains a normal window owned by the
desktop root; closing it never exits the bar or launcher.

The bar reads native Quickshell providers rather than polling command output:
Hyprland objects provide monitor-scoped workspaces and the focused title,
SystemTray provides items and platform menus, PipeWire provides the default sink,
and `SystemClock` provides time. The desktop root uses `UseQApplication` because
tray platform menus require it. Preview mode moves the bar to the bottom and sets
its exclusive zone to zero; desktop mode reserves its 44-pixel top edge.

Launcher search returns references to native desktop-entry objects. It never
constructs an arbitrary command from query text; activation calls the selected
entry's `execute()` method. Results are capped and ranked by normalized application
name, generic name, and keywords.

### Orbit surfaces

Orbit revision 03 is approved for the first production slice. Shared geometry and
typography live in `Theme.metrics` and `Theme.typography`; semantic colors remain
in the existing catalog. The bar is continuous at the screen edge, with native
workspace objects behind soft dot/pill indicators. Launcher rows retain native
desktop entries, with consistent search/result gutters and fixed row heights.

Quick Controls and Settings are distinct production surfaces. Quick Controls
provides live default-output audio controls. Network and Bluetooth are disabled
Planned tiles, with no fabricated status. Brightness, media, and Do Not Disturb
remain later work. Its Settings entry opens a dedicated window; general
appearance preferences do not belong in the control panel.

Settings provides room for appearance, wallpaper, typography, interface density,
bar layout, launcher preferences, accessibility, and deeper feature configuration.
Palette selection and reduced motion are implemented using the existing safe
appearance service. The other sections/preferences are disabled Planned controls.
Save errors and unsupported-state warnings stay visible outside scrolling content.
Closing Settings restores the invoking Quick Controls entry when applicable,
without terminating the desktop. Launcher and Settings use separate monitor
targets so opening one does not move an already open surface to another monitor.

The desktop entry-point icon represents the distribution, not Senntisten's S
mark. `distroId` in the Nix package defaults explicitly to `nixos` and can be
overridden with `SENNTISTEN_DISTRO_ID`. The local CC0 NixOS snowflake uses semantic
accent tinting; other IDs use a neutral icon rather than falsely claiming NixOS.
The package provides local DejaVu typography. There is no runtime icon/font
download or unverified distro detection.

Raw desktop IPC exposes `launcher`, `dashboard`, and `settings` toggles. They
return false if no target is available. `dashboard` routes to the correct bar's
Quick Controls; opening a launcher or Settings closes Quick Controls. This is
not yet the stable packaged five-hook dispatcher described below.

### Planned Nix command contract

The eventual provider integration must support at least the user's
`my.desktop.shellCommands` hooks. Each option has type
`lib.types.nullOr lib.types.str` and defaults to `null`:

| Hook | Required purpose |
| --- | --- |
| `launcher` | Invoke the application launcher. |
| `dashboard` | Invoke Quick Controls and desktop status, separate from Settings. |
| `settings` | Open the dedicated Settings window. |
| `session` | Open a session/power menu, not immediately perform a destructive action. |
| `lock` | Request a real secure lock through the explicitly selected lock provider. |

`null` means unavailable or unconfigured, not a successful no-op. Additional hooks
may be added, but do not replace these five. The exact command syntax and
show/toggle behavior remain to be defined and documented before implementation.

Commands must have a stable packaged interface, target the intended running
instance through IPC, and report missing instances or unsupported actions with
an actionable error and nonzero exit status. Opening a surface must not start a
second shell. Nix/compositor integration consumes these commands for bindings;
the shell must not register global shortcuts implicitly.

The lock hook may delegate to an existing trusted provider. It does not require
Senntisten to own session locking, and a cosmetic overlay cannot satisfy it.
Session actions must respect the established lock-before-suspend policy.

This contract is planned work. Defining it here does not implement the hooks,
enable autostart, edit the separate Nix configuration, or approve replacing any
active provider. Command dispatch, failure behavior, instance targeting, session
safety, and any lock delegation need isolated behavioral tests before activation.

### Persistence

The file is read once at startup or QML reload. No background polling or network is
involved. First launch uses in-memory defaults. Parsing has explicit outcomes:
`default`, `saved`, `recovered`, and `blocked`; I/O additionally uses `loading`,
`saving`, and `error` states.

Writes use atomic Quickshell FileView operations. A transaction gets a fresh writer:
Quickshell 0.2.1 caches attempted bytes even after a failed save, which makes an
identical retry on the same writer a silent no-op. Operations are serialized and
rapid changes coalesce to the latest request. The footer reports success only once
the serialized current selection matches a successful write.

A newer schema disables saving rather than destructively converting it. Invalid
older/current data is retained until an explicit valid selection. Runtime external
file edits and coordinated multi-process preferences are outside this MVP's scope.

### Reloading

The Appearance window inhibits Quickshell's built-in reload popup on successful
and failed reloads. Compiler errors remain in the launching terminal, and
Quickshell retains the last valid graph. Layer wrappers are never instantiated by
offscreen tests; their content is hosted in real normal windows while native
Wayland preview validation covers actual bar/launcher surfaces separately.

### Naming and styling

Use names such as `ShellLabel` rather than `Label` to avoid collisions with imported
Qt Quick Controls types. Unqualified native labels can inherit a black foreground
even when the custom palette is dark. Actual control-color and rendered-pixel checks
cover this boundary; valid palette hex values alone are insufficient.

The appearance layout stacks and scrolls at narrow sizes. Focus changes reveal
controls reached with Tab/Shift+Tab, while save/error feedback stays outside the
scrolling region. Launcher results scroll independently and only draw a scrollbar
when content overflows.

## Validation boundaries

- Unit tests load the same `.pragma library` JavaScript used by QML in a Node VM.
- Launcher tests substitute only the external process boundary; they do not claim
  that mock output proves the GUI works. Diagnostic fixtures capture only allowed
  non-secret environment fields.
- Integration tests launch real Quickshell against disposable source/state and
  desktop-entry paths. Native desktop-entry execution is verified with isolated
  recorder applications, not user programs.
- The QtTest harness is copied inside the shell directory so Quickshell's config-root
  scanner can resolve the real App and service types. Do not import them from outside
  the selected config root.
- Native QtTest mouse/key events exercise the rendered component handlers. Images
  and explicit pass/fail counts are checked, not inferred from an exit status alone.
- Nix checks run the package, all discovered integration suites, a packaged-launch
  and duplicate-instance smoke test, unit tests, and shell/Nix linting.
- No check activates a system configuration or touches the active desktop provider.

Native Wayland validation is separate and read back by PID and layer namespace.
Preview success does not prove multi-monitor hotplug, Home Manager startup, or
full-session replacement.

## Subsequent increments

1. Export a typed Home Manager module, without enabling autostart by default.
2. Register an explicit `senntisten` provider and launcher keybinding in the
   separate Nix configuration.
3. Add notification, network/Bluetooth, brightness, and lock capabilities as
   individually tested ownership decisions rather than mandatory startup features.
4. Extend Theme Studio and add capture, project, and machine tools as independently
   usable windows with the same components and theme service.

Every increment needs its own acceptance checks and an explicit activation boundary.
