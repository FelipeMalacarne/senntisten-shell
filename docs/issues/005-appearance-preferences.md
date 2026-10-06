# 005: Implement Appearance Preferences

Status: Planned
Priority: P2
Dependencies: Existing Theme service; explicit wallpaper ownership decision

## Goal

Make the Planned typography, interface-density, and wallpaper preferences in
Settings functional without introducing inconsistent per-surface styling or
overwriting user-managed state.

## Acceptance Criteria

- [ ] Support installed local font selection with a safe fallback when a selected
  family is unavailable; do not fetch fonts at runtime.
- [ ] Define a small, documented set of density presets and apply their shared
  metrics consistently to the bar, launcher, Quick Controls, and Settings.
- [ ] Preserve usable hit targets, readable text, focus visibility, and narrow layouts.
- [ ] Provide a local wallpaper picker/preview and validate unavailable, removed,
  or unsupported image files visibly.
- [ ] Define whether wallpaper is preview-only, delegated, or rendered by
  Senntisten before implementing any applying action.
- [ ] Existing palette and reduced-motion preferences continue working and persisting.
- [ ] Version any necessary state changes, cover migration from schema 1, retain
  unsupported newer state, and report failed saves honestly.
- [ ] Opening Settings alone does not write defaults or replace an existing file.
- [ ] Keep all appearance preferences in Settings rather than Quick Controls.

## Verification

Add failing tests for font fallback, density geometry, state migration, restart,
failed-save retry, and missing wallpaper files. Render both palettes at each
supported density and representative widths. Assert keyboard/pointer access and
inspect actual PNGs, not only token values or source patterns.

## Boundaries

Nix remains responsible for dependencies and declarative defaults. Apply changes
only to Senntisten unless an external adapter is explicitly approved. Do not
silently replace Noctalia's wallpaper surface or change GTK/Qt/editor themes.
