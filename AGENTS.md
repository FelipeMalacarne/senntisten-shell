# Senntisten Shell

Personal, Nix-first Quickshell desktop shell for Felipe. The usable MVP is a
real Hyprland bar and searchable application launcher, with the tested appearance
window retained as a settings tool. A separate playground mode supports isolated
component development. Desktop mode may create its own layer-shell surfaces;
it must not stop Noctalia/Caelestia, claim notifications or locking, register global
shortcuts, or change session startup without explicit activation approval.

## Boundaries

- Work only in this repository unless explicitly asked to integrate elsewhere.
- Do not change `/home/felipe/repos/nix-config`, activate NixOS/Home Manager,
  restart desktop services, or create remote repositories without approval.
- No commits or pushes unless requested.
- Nix owns the package/dependencies/defaults; mutable appearance state belongs
  in `$XDG_STATE_HOME/senntisten-shell` (fallback `~/.local/state/senntisten-shell`).
  `SENNTISTEN_STATE_DIR` provides an isolated override for development/tests.
- Keep Quickshell and Qt aligned via the pinned nixpkgs. Use `nix develop`;
  never install dependencies into system Python or modify `/nix/store`.

## Implementation

- Entry point: `shell/shell.qml`. Reusable controls live in `shell/components/`,
  state/services in `shell/services/`, pure logic in `shell/lib/`.
- Use shared semantic theme tokens. No palette literals in UI components.
- Keep errors visible. Missing/invalid state must not prevent startup; a
  failed save must not be reported as successful. Do not overwrite state
  from an unsupported newer schema.
- Use local fonts and vector shapes; no runtime network/CDN dependencies.
- UI controls must be keyboard-accessible, have accessible names, and respect
  reduced motion. Clearly identify preview-only controls and data.
- Add failing behavioral tests before implementation and run them through
  RED/GREEN cycles. Verify real QML execution, not only source-file patterns.
- Test against temporary state/config/runtime paths, never the user's live data.

## UI Development And Evidence

- Start with [the UI harness guide](docs/ui-harness.md). `make ui-inspect` renders
  real QML in an isolated offscreen scene; `make ui-check` collects regression
  screenshots and interaction results. Both print a fresh artifact report path.
- For UI changes, add a failing behavioral case, run RED/GREEN, then inspect actual
  PNGs with an image tool. Check both palettes, wide/narrow geometry, keyboard focus,
  pointer behavior, and relevant empty/unavailable/save-error states.
- Use `tests/ui-actions/` replays or a custom JSON action file. Inspect checkpoint
  JSON for control names, accessibility, focus, clipping, and state; use `expect`
  actions to assert outcomes. A screenshot alone does not prove an interaction.
- `focus` explicitly forces focus for component diagnosis. It is not proof of Tab
  reachability. Pointer actions reject disabled/hidden/clipped targets instead of
  calling their handlers. Promote regressions into the normal QtTest suites.
- Reports and browser design studies are not the shell. Browser automation can
  inspect the report, but native interaction evidence comes from QtTest QML.
- Report exact commands, artifact paths, viewed images, and remaining limits.
  Offscreen/software results do not prove compositor focus, layer reservations,
  multi-monitor behavior, tray platform menus, or GPU rendering. Live preview or
  Wayland tests require explicit approval or an explicitly supplied disposable
  compositor; never target the user's desktop implicitly.

## MVP acceptance

1. Desktop mode provides a real per-monitor bar with live workspaces, clock, tray,
   audio controls, and an application-launcher entry point.
2. The launcher searches real desktop entries and supports keyboard/mouse activation.
3. Catppuccin Mocha and Gruvbox update the bar, launcher, and appearance window live.
4. Appearance persists with safe failure/unknown-state handling and hot reload.
5. Closing the appearance tool does not terminate desktop mode.
6. A no-reservation bottom-bar preview can coexist with the configured shell.
7. Nix development/build commands and automated checks work.
8. Provider activation, lock/notification replacement, and startup changes remain
   explicit separate decisions; do not silently stop Noctalia.
