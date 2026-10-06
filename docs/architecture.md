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
shell/desktop/BarServices.qml native providers and connectivity/media composition
shell/desktop/NetworkService.qml network status and deliberate actions
shell/desktop/BluetoothService.qml Bluetooth adapter/device actions
shell/desktop/MediaService.qml native MPRIS selection, metadata, and playback
shell/desktop/Launcher.qml   focused overlay layer surface
shell/desktop/LauncherContent.qml desktop-entry search and activation UI
shell/components/            shared presentation components
shell/services/Theme.qml     theme state, asynchronous persistence, transactions
shell/lib/ThemeCatalog.js    pure presets and versioned state codec
shell/lib/ApplicationSearch.js pure deterministic desktop-entry ranking
bin/senntisten-shell         foreground launch and existing-instance action dispatch
nix/package.nix             package with pinned runtime paths
nix/home-manager.nix        opt-in installation and nullable command hooks
nix/tests/                  repository-local module evaluation fixtures
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

The launcher uses a 470-pixel maximum panel width and Quick Controls a 300-pixel
preferred width, matching Orbit's compact composition. Both shrink to available
space. `ShellIconButton` supplies the shared borderless close action and visible
keyboard focus; `ShellScrollView` reveals keyboard-reached controls without
silently scrolling pointer targets. Quick Controls keeps its close action fixed
while the body scrolls on short screens. The output slider has an explicit thin
track and round thumb instead of stretching its track to the control height.

Quick Controls and Settings are distinct production surfaces. Quick Controls
provides live output volume/mute and device selection, separate microphone
controls, and real MPRIS player selection and supported playback actions. Network
and Bluetooth tiles expand mutually exclusive details without fabricating status.
Service boundaries own pending/error state and deliberate actions; presentation
stays in per-feature controls composed by `AudioPanel`. Brightness and Do Not Disturb
remain later work. Its Settings entry opens a dedicated window; general
appearance preferences do not belong in the control panel.

Connectivity uses the pinned `Quickshell.Networking` NetworkManager backend and
`Quickshell.Bluetooth` BlueZ API, not command polling. Open/saved Wi-Fi and existing
wired profiles are supported; new secured-profile provisioning remains external.
Bluetooth PIN/confirmation prompts rely on an existing system agent. Native
operation flags/state changes drive pending actions, with bounded timeouts where
the pinned API cannot surface a precise D-Bus error. No credentials enter shell
appearance state or diagnostic artifacts. PipeWire tracks relevant native nodes;
media uses `Quickshell.Services.Mpris` and never downloads artwork URLs.

Settings provides room for appearance, wallpaper, typography, interface density,
bar layout, launcher preferences, accessibility, and deeper feature configuration.
Palette selection and reduced motion are implemented using the existing safe
appearance service. The other sections/preferences are disabled Planned controls.
Deeper device preferences remain planned, not hidden network/audio configuration
writes. Save errors and unsupported-state warnings stay visible outside scrolling content.
Closing Settings restores the invoking Quick Controls entry when applicable,
without terminating the desktop. Launcher and Settings use separate monitor
targets so opening one does not move an already open surface to another monitor.
Settings uses the same local vector icon vocabulary, Orbit palette thumbnails,
aligned planned-action columns, and a horizontally scrollable narrow navigation
strip. Its opaque feedback footer remains separate from scrolling content.

The desktop entry-point icon represents the distribution, not Senntisten's S
mark. `distroId` in the Nix package defaults explicitly to `nixos` and can be
overridden with `SENNTISTEN_DISTRO_ID`. The local CC0 NixOS snowflake uses semantic
accent tinting; other IDs use a neutral icon rather than falsely claiming NixOS.
The package provides local DejaVu typography. There is no runtime icon/font
download or unverified distro detection.

Raw desktop IPC exposes `launcher`, `dashboard`, and `settings` toggles. They
return false if no target is available. `dashboard` routes to the correct bar's
Quick Controls; opening a launcher or Settings closes Quick Controls. This is
the controller used by the stable packaged dispatcher described below. Raw IPC
remains available for local diagnostics, but callers integrating bindings should
use the wrapper's validation and failure handling.

### Nix command contract

The packaged action interface is `senntisten-shell ACTION [--pid PID]`.
Launcher, dashboard, and Settings toggle their existing surfaces. Default
selection requires a unique running instance of the current configuration;
explicit PID selection supports previews, source checkouts, and different package
builds without starting another shell. Missing or rejected requests fail nonzero.
See [Shell Commands](shell-commands.md) for semantics and limitations.

The opt-in Home Manager module exposes `programs.senntisten-shell.shellCommands`
for bridging to the user's external `my.desktop.shellCommands` contract. Each hook
has type `lib.types.nullOr lib.types.str` and defaults to `null`:

| Hook | Purpose | Availability |
| --- | --- | --- |
| `launcher` | Toggle the application launcher. | Explicit command exposure |
| `dashboard` | Toggle Quick Controls, separate from Settings. | Explicit command exposure |
| `settings` | Toggle the dedicated Settings window. | Explicit command exposure |
| `session` | Open a session/power menu, not perform a destructive action directly. | Unconfigured |
| `lock` | Request a secure lock through an explicitly selected trusted provider. | Unconfigured |

`null` means unavailable or unconfigured, not a successful no-op. Additional hooks
may be added, but do not replace these five. Package installation and command
exposure are separate opt-ins; neither enables startup or bindings. An external
consumer chooses whether to map these values into its own provider options.

The dispatcher recognizes `session` and `lock`, but reports them as unconfigured.
Their functional implementation is [issue 007](issues/007-session-lock.md). The
shell never registers global shortcuts implicitly.

The lock hook may delegate to an existing trusted provider. It does not require
Senntisten to own session locking, and a cosmetic overlay cannot satisfy it.
Session actions must respect the established lock-before-suspend policy.

Exporting the module does not edit the separate Nix configuration or approve
replacing any active provider. Native acceptance, external integration, and
activation remain separate gates. Session safety and any lock delegation require
isolated behavioral tests and explicit provider selection before live use.

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

After explicit approval for the target display, `tests/wayland_smoke.py` exercises
the actual bar/launcher/popup wrappers with isolated appearance/provider state.
Run with `SENNTISTEN_WAYLAND_TEST_APPROVED=1` inside `nix develop`. Its compositor
pointer test requires Hyprland, one scale-1 monitor at origin 0,0, and the standard virtual
pointer protocol. It briefly creates its own zero-reservation bar, tests launcher,
Settings, and Quick Controls both before and after hover hints, then removes only
its own surfaces and restores the pointer. It never runs in the default checks.

Injected Qt mouse events are not proof of compositor hit testing. Qt Controls
tooltips on a layer bar can create an in-window overlay that swallows actual
pointer clicks even when injected Qt events pass. Bar hover hints therefore use
passive Quickshell popups with an empty input mask and no focus grab.

## Subsequent increments

1. Close native pointer, focus, GPU, and multi-monitor acceptance gaps.
2. After approval, integrate the exported module with an explicit `senntisten`
   provider and launcher keybinding in the separate Nix configuration.
3. Add network/Bluetooth, appearance, media, and session capabilities from the
   [implementation backlog](issues/README.md), without bundling provider ownership.
4. Extend Theme Studio and add capture, project, and machine tools as independently
   usable windows with the same components and theme service.

Every increment needs its own acceptance checks and an explicit activation boundary.
