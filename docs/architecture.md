# Architecture

## Product boundary

Senntisten is a personal shell, not a cross-distribution desktop environment.
The long-term direction is compact desktop chrome, powerful panels and launcher,
live appearance switching, and personal applications that share the same UI kit.

The first deliverable is a normal Quickshell window. No layer-shell surfaces,
notification-server ownership, session locking, services, global shortcuts, or
system changes are part of this release.

## Source layout

```text
shell/shell.qml              composition root
shell/App.qml                normal window, local IPC, reload-popup policy
shell/Playground.qml         compact bar, component canvas, appearance panel
shell/components/            shared presentation components
shell/services/Theme.qml     theme state, asynchronous persistence, transactions
shell/lib/ThemeCatalog.js    pure presets and versioned state codec
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

The normal-window MVP inhibits Quickshell's built-in layer-shell reload popup on
both successful and failed reloads. This keeps development inside its intended
window and avoids the missing PanelWindow backend in offscreen tests. Compiler
errors remain in the launching terminal; Quickshell retains the last valid graph.

### Naming and styling

Use names such as `ShellLabel` rather than `Label` to avoid collisions with imported
Qt Quick Controls types. Unqualified native labels can inherit a black foreground
even when the custom palette is dark. Actual control-color and rendered-pixel checks
cover this boundary; valid palette hex values alone are insufficient.

The layout is a normal responsive application surface. At narrow sizes, the details
stack and scroll. Save/error feedback remains outside the scrolling region.

## Validation boundaries

- Unit tests load the same `.pragma library` JavaScript used by QML in a Node VM.
- Launcher tests substitute only the external process boundary; they do not claim
  that mock output proves the GUI works. Diagnostic fixtures capture only allowed
  non-secret environment fields.
- Integration tests launch real Quickshell against disposable source/state paths.
- The QtTest harness is copied inside the shell directory so Quickshell's config-root
  scanner can resolve the real App and service types. Do not import them from outside
  the selected config root.
- Native QtTest mouse/key events exercise the rendered component handlers. Images
  and explicit pass/fail counts are checked, not inferred from an exit status alone.
- Nix checks run the package, unit tests, integration tests, and shell/Nix linting.
- No check activates a system configuration or touches the active desktop provider.

## Subsequent increments

1. Introduce shared actions and a genuine application launcher.
2. Add an opt-in bar surface and native workspace/status adapters.
3. Export a typed Home Manager module, without enabling autostart by default.
4. Register an explicit `senntisten` provider in the separate Nix configuration.
5. Extend Theme Studio and add capture, project, and machine tools as independently
   usable windows with the same components and theme service.

Every increment needs its own acceptance checks and an explicit activation boundary.
