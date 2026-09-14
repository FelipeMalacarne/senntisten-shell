# Senntisten Shell

Personal, Nix-first Quickshell desktop shell for Felipe. The first MVP is a
standalone **normal window** containing a compact bar and theme playground.
It must coexist with Noctalia/Caelestia without claiming layer-shell space,
notifications, locking, global shortcuts, or session startup.

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

## MVP acceptance

1. Standalone window opens with compact bar and expandable appearance panel.
2. Catppuccin Mocha and Gruvbox switch all shared components without restart.
3. Selected appearance survives restart, with safe failure/unknown-state handling.
4. QML edits hot-reload without a Nix rebuild.
5. Keyboard navigation and narrow-window behavior are usable.
6. Nix development/build commands and automated checks work.
7. Existing desktop provider and its state remain unchanged.
