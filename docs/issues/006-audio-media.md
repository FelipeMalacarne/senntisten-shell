# 006: Expand Audio And Add Media Controls

Status: Implemented and integrated; isolated verification complete; live-device acceptance requires approval
Priority: P2
Dependencies: Existing PipeWire adapter; confirmed pinned MPRIS API

## Goal

Extend the working volume/mute controls with device selection and real media
actions, using Orbit's Quick Controls composition rather than fixture tracks.

## Acceptance Criteria

- [x] Expose available output devices and deliberately select the default output.
- [x] Add microphone volume/mute with clear separation from output controls.
- [x] Track relevant native nodes and reflect external default-device, volume,
  mute, and availability changes without stale-node writes.
- [x] Preserve bounded volume writes and the rule that volume changes do not
  implicitly unmute a device.
- [x] Provide native MPRIS player/track information and supported playback actions.
- [x] Define player selection when multiple players exist and handle disappearance.
- [x] Gate unsupported playback actions and show useful empty/unavailable/error states.
- [x] Keep artwork local/provider-supplied; do not introduce runtime artwork downloads.
- [x] Preserve palette consistency, reduced motion, accessible names/values, and
  keyboard/pointer reachability in short panels.

The checked items describe the integrated implementation and isolated evidence,
not live-device verification. `BarServices.media` supplies `MediaService` to the
shared `AudioPanel`, alongside output selection and separate microphone controls.
Both palettes, reduced motion, accessible controls, pointer actions and real Tab
reachability are verified in the composed short panel and standalone components.
Deeper device preferences remain planned in Settings; no system audio configuration
or session/provider activation was changed. No additional Nix dependency was needed.

## Component Contract

- `BarServices` preserves flat `audioAvailable`, `volume`, `volumePercent`, `muted`,
  `outputName`, `audioStatus`, `setVolume(value)` and `toggleMute()`.
- `outputs` contains native, ready, non-stream audio output references. All audio
  device candidates are tracked before filtering readiness, avoiding a tracking
  deadlock. `sink` and `source` follow the effective native defaults.
- `selectOutput(node)` validates current catalog membership, direction and readiness,
  then writes `preferredDefaultAudioSink`; it does not fabricate an effective-default
  update or automatically change volume/mute. A provider with no catalog cannot
   select a device. Missing catalogs disable output/microphone availability and all
   device writes; fixtures implement the same catalog contract as native providers.
- Microphone fields are `microphoneAvailable`, `microphoneVolume`,
  `microphoneVolumePercent`, `microphoneMuted`, `microphoneName`, `microphoneStatus`,
  with `setMicrophoneVolume(value)` and `toggleMicrophoneMute()`.
- Volume writes reject non-finite/non-numeric values, clamp to 0..1 and never unmute.
  Each write rechecks the provider's current model/default, not cached UI availability.
- `AudioDevices` and `MicrophoneControls` require `property var services`.
  `MediaControls` requires `property var service`. These are compact layout children;
  the composition supplies scrolling through `ShellScrollView`.
- `MediaService.mpris` defaults to native `Mpris` and accepts an injected provider
  with the same `players.values` boundary. It exposes `players`, `player`, `available`,
  `playerName`, `title`, `artist`, `album`, `artwork`, `playing`, `canTogglePlaying`,
  `canNext`, `canPrevious`, `status` and `error`.
- Players sort lexically by unique `dbusName`. Automatic selection prefers a playing
  player, then the first sorted player. `selectPlayer(player)` pins a user choice
  until it disappears; disappearance clears that preference and recomputes selection.
- `togglePlaying()`, `next()` and `previous()` revalidate membership, selection and
  native capabilities at dispatch. An optional player argument permits stale-target
  rejection. Their boolean return means dispatched, not playback acknowledged.
- Artwork accepts only `file:///` URLs without a remote host, `image://` providers,
  and `qrc:/` resources. HTTP(S), relative, data and remote-host file URLs are rejected
  before reaching `Image`. Missing local artwork shows `Artwork unavailable`.

## Confirmed Native API

Inspected the installed qmltypes from the pinned `nix develop` environment:
Quickshell 0.3.0 (`tag-v0.3.0`, Nixpkgs), Qt tooling 6.11.2. The Quickshell import root is
`/nix/store/j1xwwpwicfgbpwri1fqqk4p1n9fi2i7d-quickshell-0.3.0/lib/qt-6/qml`.

- `Quickshell/Services/Pipewire/quickshell-service-pipewire.qmltypes` confirms
  `Pipewire.nodes`, `ready`, read-only `defaultAudioSink`/`defaultAudioSource`, writable
  `preferredDefaultAudioSink`, `PwNode.isSink`/`isStream`/`audio`/`ready`, writable
  `PwNodeAudio.volume`/`muted`, and `PwObjectTracker.objects`.
- `Quickshell/Services/Mpris/quickshell-service-mpris.qmltypes` confirms
  `Mpris.players`, player `dbusName`, `identity`, `trackTitle`, `trackArtist`, `trackAlbum`,
  `trackArtUrl`, `isPlaying`, `canControl`, `canTogglePlaying`, `canPlay`, `canPause`,
  `canGoNext`, `canGoPrevious`, and `togglePlaying()`/`next()`/`previous()`.
- This MPRIS API has no provider-ready property or asynchronous action-error signal.
  Empty players cannot reliably distinguish an idle bus from an unavailable bus.
  Status says so; synchronous dispatch exceptions are visible/retryable, but native
  asynchronous failures remain native diagnostics, not invented success/error state.

## Verification

Use controlled audio/player fixtures and recorder actions for device removal,
external updates, mute state, limits, unsupported methods, and multiple players.
Add real QML behavior tests and inspect both palettes. Changes to personal audio
devices or active playback require explicit approval for live verification.

### RED/GREEN Evidence (2026-10-06)

Exact standalone command, used for both RED and GREEN:

```sh
nix develop --no-write-lock-file --command python3 tests/audio_media_integration.py
```

- Initial RED: nine failures, with missing device selection/microphone behavior and
  absent media components. Report:
  `artifacts/ui/20261006T125021.242101Z-5a6ee230/index.html`.
- Additional RED: no-catalog selection wrongly returned true. Report:
  `artifacts/ui/20261006T130445.592164Z-07daea5b/index.html`.
- GREEN: all 12 named behavioral cases executed, zero failures/skips; 11 validated
  PNGs plus recorder/focus/geometry checkpoints. Standalone report:
  `artifacts/ui/20261006T130717.272847Z-3348a6ea/index.html`.
- Latest GREEN, repeated by `make ui-check` after the final component edits:
  `artifacts/ui/20261006T130937.425123Z-a2a75688/index.html`. All 11 PNGs in that
  directory were opened with the image tool: `audio-media-{catppuccin-mocha,gruvbox}-`
  `{wide,narrow,short-focus,unavailable,error}.png` and `audio-media-local-artwork.png`.
- Checkpoints assert zero stale output/default writes, zero stale microphone writes,
  zero unsupported/stale playback dispatches, effective-default updates, and actual
  Tab focus revealing microphone and media controls. Qt pointer events exercise output
  selection, microphone mute, player selection and supported/disabled playback buttons.
  External slider updates retain their binding; local artwork renders and a remote
  URL never reaches the image source.
- Native unavailable-endpoint startup is executed, with unavailable session and system
  D-Bus socket paths, unavailable `PIPEWIRE_REMOTE`, disposable HOME/XDG paths,
  offscreen/software Qt, and no DISPLAY/Wayland/Hyprland identities. Expected PipeWire
  connection and MPRIS bus diagnostics remain visible. No live audio/playback is used.

Owned QML formatting and lint commands (both pass; final lint has no warnings):

```sh
nix develop --no-write-lock-file --command qmlformat -i shell/desktop/BarServices.qml shell/desktop/MediaService.qml shell/desktop/AudioDevices.qml shell/desktop/MicrophoneControls.qml shell/desktop/MediaControls.qml tests/audio-media-ui.qml
nix develop --no-write-lock-file --command bash -c 'set -e; tmp=$(mktemp); trap "rm -f $tmp" EXIT; for file in shell/desktop/BarServices.qml shell/desktop/MediaService.qml shell/desktop/AudioDevices.qml shell/desktop/MicrophoneControls.qml shell/desktop/MediaControls.qml tests/audio-media-ui.qml; do qmlformat "$file" > "$tmp"; diff -u "$file" "$tmp"; done'
nix develop --no-write-lock-file --command bash -c 'qs=$(readlink -f "$(command -v quickshell)"); qt=$(readlink -f "$(command -v qmllint)"); qmllint -I "$(dirname "$(dirname "$qs")")/lib/qt-6/qml" -I "$(dirname "$(dirname "$qt")")/lib/qt-6/qml" shell/desktop/BarServices.qml shell/desktop/MediaService.qml shell/desktop/AudioDevices.qml shell/desktop/MicrophoneControls.qml shell/desktop/MediaControls.qml'
git diff --check
```

Historical broader checks at the lane handoff, superseded by final integration:

- `nix develop --no-write-lock-file --command python3 tests/bar_integration.py`:
  audio/bar assertions initially passed, but the diagnostic gate rejected missing
  shared `services.media`/`network`/`bluetooth` composition.
- `nix develop --no-write-lock-file --command python3 tests/quick_controls_integration.py`:
  initially passed all ten cases; later concurrent shared edits changed this result.
- `make ui-check`: audio/media and connectivity provider suites pass; launcher,
  settings and playground pass. Shared bar and Quick Controls suites fail during
  concurrent integration (including missing composed services and a short-panel
  connectivity case). Report: `artifacts/ui/20261006T130922.656280Z-31dba38d/index.html`.
- `make fmt-check`: Nix formatting passes, but QML checking finds an unrelated
  `tests/connectivity-ui.qml` formatting difference. The owned-file check above passes.
- Full `make test`/flake checks were pending at handoff; final results are below.
  No claim is made about compositor focus, GPU output, real device routing,
  real MPRIS acknowledgements or session startup. No commits or activation changes.

### Final Integration (2026-10-06)

- The integration owner bound `network`, `bluetooth`, and `media` in `BarServices`,
  composed the feature controls in `AudioPanel`, and added populated shared fixtures.
  Quick Controls now has 11 named Qt cases. These prove output selection, independent
  microphone writes/external updates, preserved mute, accessible collapsed failures,
  Tab/Backtab-revealed connectivity actions, and short-panel Settings routing.
- A final failing recorder case exposed unsafe output/microphone writes when the
  audio catalog was missing. RED command:
  `nix develop --no-write-lock-file --command python3 tests/audio_media_integration.py`.
  Report: `artifacts/ui/20261006T132117.370116Z-92a3255e/index.html`.
  Removing the fixture-only fallback produced GREEN with the same command:
  `artifacts/ui/20261006T132216.345689Z-25e975e9/index.html`, all 13 audio/media cases.
- `make test` passes 51 unit tests, 72 Python integration tests and the module check.
  `make ui-check` passes all five suites, including the three feature/control suites.
  `make fmt-check` and `make lint` pass. The Git-independent
  `nix flake check path:. --no-write-lock-file --print-build-logs` also passes package,
  package-smoke, unit, integration, module and lint checks on x86_64-linux. New files
  are included without staging. aarch64-linux and live devices were not checked.
- Final UI report: `artifacts/ui/20261006T132436.477703Z-f48ee91c/index.html`.
  Opened its `orbit-controls-catppuccin-mocha.png` and
  `orbit-controls-bluetooth-gruvbox.png` with the image tool. Final audio/media report:
  `artifacts/ui/20261006T132445.383727Z-6d5471ec/index.html`; opened
  `audio-media-gruvbox-narrow.png` and `audio-media-local-artwork.png` there.
  Earlier actual PNG inspections also covered both palettes, errors, unavailable
  providers, narrow geometry and short keyboard-focus states.

Final composed short-panel commands (both pass):

```sh
make ui-inspect UI_ARGS='--scene controls --width 340 --height 320 --theme catppuccin-mocha --actions tests/ui-actions/controls-short.json'
make ui-inspect UI_ARGS='--scene controls --width 340 --height 320 --theme gruvbox --reduced-motion --actions tests/ui-actions/controls-short.json'
```

Reports: `artifacts/ui/20261006T133039.127145Z-8584c26f/index.html` and
`artifacts/ui/20261006T133039.245465Z-0548a63c/index.html`, respectively. Opened
`017-expect.png` in the former and `023-expect.png` in the latter with the image
tool, showing microphone and Settings focus in the 280px panel. The replay
asserts actual Tab reachability and pointer selection, microphone volume changes
without implicit unmute, and Settings/close focus. Offscreen/software evidence does
not establish real output routing, playback acknowledgements, compositor focus,
GPU rendering, multi-monitor behavior or session startup. No live actions were used.

## Boundaries

Do not change system audio configuration or take over an existing media service.
Never show a fabricated track as if it were live data.
