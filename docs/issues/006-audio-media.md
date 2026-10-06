# 006: Expand Audio And Add Media Controls

Status: Planned
Priority: P2
Dependencies: Existing PipeWire adapter; confirmed pinned MPRIS API

## Goal

Extend the working volume/mute controls with device selection and real media
actions, using Orbit's Quick Controls composition rather than fixture tracks.

## Acceptance Criteria

- [ ] Expose available output devices and deliberately select the default output.
- [ ] Add microphone volume/mute with clear separation from output controls.
- [ ] Track relevant native nodes and reflect external default-device, volume,
  mute, and availability changes without stale-node writes.
- [ ] Preserve bounded volume writes and the rule that volume changes do not
  implicitly unmute a device.
- [ ] Show real MPRIS player/track information and supported playback actions.
- [ ] Define player selection when multiple players exist and handle disappearance.
- [ ] Gate unsupported playback actions and show useful empty/unavailable/error states.
- [ ] Keep artwork local/provider-supplied; do not introduce runtime artwork downloads.
- [ ] Preserve palette consistency, reduced motion, accessible names/values, and
  keyboard/pointer reachability in short panels.

## Verification

Use controlled audio/player fixtures and recorder actions for device removal,
external updates, mute state, limits, unsupported methods, and multiple players.
Add real QML behavior tests and inspect both palettes. Changes to personal audio
devices or active playback require explicit approval for live verification.

## Boundaries

Do not change system audio configuration or take over an existing media service.
Never show a fabricated track as if it were live data.
