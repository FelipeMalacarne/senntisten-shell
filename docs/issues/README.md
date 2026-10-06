# Implementation Backlog

Local Markdown issues for the next Senntisten increments. These are planned work,
not claims of implemented functionality or approval to activate desktop providers.
Keep each issue's status and acceptance checklist updated as work progresses.

## Recommended Order

| ID | Issue | Priority | Status | Dependencies |
| --- | --- | --- | --- | --- |
| 001 | [Close the native verification gap](001-native-verification.md) | P0 | Planned | Explicit approval for the test display |
| 002 | [Implement stable shell commands](002-shell-commands.md) | P1 | Planned | Existing desktop IPC; 001 gates activation |
| 003 | [Export the opt-in Nix module](003-nix-module.md) | P1 | Planned | 002 |
| 004 | [Implement connectivity controls](004-connectivity.md) | P2 | Planned | Confirm pinned provider APIs and capabilities |
| 005 | [Implement appearance preferences](005-appearance-preferences.md) | P2 | Planned | Existing Theme service; explicit wallpaper ownership |
| 006 | [Expand audio and add media controls](006-audio-media.md) | P2 | Planned | Existing PipeWire adapter; pinned MPRIS API |
| 007 | [Add session actions and trusted lock delegation](007-session-lock.md) | P2 | Planned | 002, 003, and explicit provider/policy selection |

P0 is the acceptance gate for deploying the current shell. P1 makes the existing
surfaces reliably invocable and integratable. P2 extends the functional scope.
Implementation can proceed independently where dependencies permit, but provider
activation remains a separate, explicit decision.

The recommended next coherent increment is 001, then 002 and 003. Issue 002 must
define all five command hooks without pretending session or lock work before 007:
unconfigured actions fail clearly, and their Nix hook values remain `null`.

## Shared Definition Of Done

- Add failing behavioral coverage before implementation and record RED/GREEN.
- Preserve Orbit's shared tokens, visual hierarchy, keyboard access, reduced
  motion, and separation between Quick Controls and Settings.
- Exercise real production QML through the [UI harness](../ui-harness.md), inspect
  actual PNGs in both palettes, and assert pointer/keyboard outcomes.
- Cover narrow layouts and relevant empty, unavailable, loading, and failure states.
- Preserve safe appearance persistence and unsupported-newer-schema handling.
- Run applicable unit, integration, formatting, lint, build, and Nix checks.
- Record exact commands, artifact paths, viewed images, and remaining limitations.
- Use temporary state/config/runtime paths. Live display, device, network, session,
  or provider actions require the corresponding explicit approval.
- Do not stop Noctalia/Caelestia, change startup or global bindings, edit the
  external Nix configuration, commit, or push merely because an issue exists.

## References

- [Architecture and command contract](../architecture.md)
- [Approved Orbit scope](../design/README.md#implementation-scope)
- [Project boundaries](../../AGENTS.md)
