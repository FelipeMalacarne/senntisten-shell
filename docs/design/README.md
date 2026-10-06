# Desktop Design Studies

Two design studies for Senntisten's personal Hyprland desktop. Orbit revision 03
is approved for the production bar, launcher, Quick Controls, and Settings slice.
It polishes alignment while retaining the edge bar, distro icon, softer panels,
and separate Quick Controls and Settings introduced in the preceding revision.
Citadel remains available as a reference using the same fixtures and surfaces.

## Review

From the repository root:

```sh
nix develop --no-write-lock-file --command python3 -m http.server 8765 --bind 127.0.0.1 --directory docs/design
```

Open `http://127.0.0.1:8765`. Stop the review server with Ctrl+C. The page uses
local CSS, JavaScript, system fonts, and inline vector artwork. No installation,
external requests, desktop providers, state writes, or session activation.

- **Citadel:** edge-integrated chrome, numbered workspaces, restrained geometry,
  precise labels, and an instrument-like control panel.
- **Orbit, revision 03:** a continuous edge-integrated bar without outer margins,
  rounding, or shadow; sculptural wallpaper, softer panels, compact workspace
  indicators, and a proposed app shelf. The shelf is not implemented functionality.

Both support Catppuccin Mocha and Gruvbox. Palette changes are independent of
concept selection. The semantic colors mirror `shell/lib/ThemeCatalog.js`; these
CSS definitions are review fixtures, not a second production theme source.

Use **Surface** to inspect the desktop, launcher, Quick Controls, both panels, or
the dedicated Settings window. The bar's settings button and the Settings entry
in Quick Controls open that window. Closing it restores the invoking surface and
focus. Palette changes are interactive previews; other Settings sections,
wallpaper, typography, and density controls are explicitly planned placeholders.

Use **Example state** to inspect unavailable audio in Quick Controls and a save
failure in Settings. Search, arrow keys, Enter, Escape, workspace buttons, and the
volume slider simulate interaction only. Wi-Fi, Bluetooth, brightness, media,
and the app shelf are labeled planned and intentionally non-interactive. No mock
preference is persisted.

On narrow browser viewports the panels stack so the study remains readable. This
is review-board responsiveness, not a decision to stack native desktop overlays.
Launcher descriptions truncate visually at narrow sizes rather than changing row
heights; their full text remains available to assistive technology.

## Confirmed Product Requirements

Quick Controls and Settings are separate surfaces. The production control panel
contains frequent system actions and a Settings entry, not general appearance
preferences. Appearance and deeper configuration belong in a dedicated Settings
window. The studies now reflect this separation: palette cards are in Settings,
not Quick Controls. The external review palette selector remains a design tool.

User feedback prefers Orbit's visual character but rejects the floating top bar.
The edge-bar revision preserves the softer panels rather than adopting Citadel's
complete visual language. Remaining typography, density, panel composition, and
app-shelf decisions are open. The subsequent implementation approval covers the
first coherent QML slice, not planned services or live-session activation.

The desktop entry-point mark represents the distribution rather than Senntisten
branding. These NixOS fixtures use the snowflake in both palettes. This is not
runtime distro detection. Production now uses an explicit Nix-owned `nixos`
default, with a neutral icon for other distribution IDs.

The future Nix integration requires at least `launcher`, `dashboard`, `settings`,
`session`, and `lock` command hooks. See the
[planned command contract](../architecture.md#planned-nix-command-contract) for
their purposes, nullable option semantics, instance targeting, and ownership
boundaries. These hooks are requirements, not newly implemented commands.

## Verification

`checks.browser.js` is an executable Playwright browser scenario, expressed as
`async (page) => { ... }`. With the review server running, navigate to the URL and
run the file using OpenCode's `playwright_browser_run_code_unsafe` tool with
`filename: "docs/design/checks.browser.js"`. It requires no project dependency
installation and is separate from the Nix/QML checks.

The scenario covers concept switching, both palettes, focus retention on review
selectors, accessible panel-toggle state, application search, empty results,
keyboard selection, explicitly simulated activation, scoped Escape, service and
save failures, simulated audio/workspaces, reduced motion, and viewport widths
from 320 to 1440 pixels. It also verifies the edge-integrated Orbit bar at every
width, separate Settings routing and focus restoration, palette selection in
Settings, and absence of appearance controls in Quick Controls. Intermediate
widths check unavailable-audio bar collisions; workspace hit areas are measured
independently of their visual dots. It checks the rendered local NixOS vector and
restores Escape focus to the dismissed surface's own entry point. Asset requests
bypass the browser cache so tests do not accidentally exercise an earlier study.
Browser console/network inspection and visual screenshot review supplement it.

Alignment checks compare rendered rectangles and text ranges, with a one-pixel
rounding tolerance: side-by-side panel tops, launcher gutters and icon/text
columns, consistent result heights, status badges, clock/date centering, Settings
action columns, and window title/footer gutters. Stacked panels are not required
to share a top edge.

These are **browser concepts, not native QML acceptance evidence**. The existing
real-Quickshell tests remain the baseline for the application. Layer-shell focus,
GPU behavior, monitor handling, and live-provider integration must be verified
when the approved concept is translated to production QML.

## Local Artwork

The inline NixOS snowflake is adapted from the
[Simple Icons NixOS SVG](https://github.com/simple-icons/simple-icons/blob/develop/icons/nixos.svg),
distributed under [CC0-1.0](https://github.com/simple-icons/simple-icons/blob/develop/LICENSE.md).
Its geometry is retained and its fill uses the active semantic accent. The SVG
is stored in `index.html`; these source links are attribution, not runtime assets.

## Implementation Scope

Choose a direction from complete compositions, including both palettes and
failure states. Feedback should identify what to keep or change about the bar,
launcher, panels, density, typography, and wallpaper relationship.

The approved QML slice implements shared visual tokens, bar, launcher,
Quick Controls with existing audio, and a separate Settings window for appearance.
It retains tested services and state safety, with behavioral RED/GREEN tests and
real offscreen QML rendering. The browser remains a mock design reference, not a
claim that its wallpaper, shelf, or planned controls became production features.
Planned services and session integration remain later, separately verified
increments. No notification/lock replacement,
global shortcuts, external Nix configuration edits, or activation are authorized
by choosing a design.
