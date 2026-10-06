# Implementation Backlog

Local Markdown issues for the next Senntisten increments. Status and acceptance
checks distinguish planned work from verified implementation; neither grants
approval to activate desktop providers.
Keep each issue's status and acceptance checklist updated as work progresses.

## Recommended Order

| ID | Issue | Priority | Status | Dependencies |
| --- | --- | --- | --- | --- |
| 001 | [Close the native verification gap](001-native-verification.md) | P0 | Planned | Explicit approval for the test display |
| 002 | [Implement stable shell commands](002-shell-commands.md) | P1 | Implemented | Existing desktop IPC; 001 gates activation |
| 003 | [Export the opt-in Nix module](003-nix-module.md) | P1 | Implemented | 002; external activation separate |
| 004 | [Implement connectivity controls](004-connectivity.md) | P2 | Partial | Integrated; secured-network/native pairing acceptance remains open |
| 005 | [Implement appearance preferences](005-appearance-preferences.md) | P2 | Planned | Existing Theme service; explicit wallpaper ownership |
| 006 | [Expand audio and add media controls](006-audio-media.md) | P2 | Implemented | Isolated verification complete; live devices require approval |
| 007 | [Add session actions and trusted lock delegation](007-session-lock.md) | P2 | Planned | 002, 003, and explicit provider/policy selection |

P0 is the acceptance gate for deploying the current shell. P1 makes the existing
surfaces reliably invocable and integratable. P2 extends the functional scope.
Implementation can proceed independently where dependencies permit, but provider
activation remains a separate, explicit decision.

Issues 002 and 003 are implemented with isolated behavioral and package evidence.
Issue 001 remains the acceptance gate before provider activation. The parallel
004/006 batch is integrated and passes the repository gates. Issue 004 retains
explicit credential/pairing-agent limits; issue 005 remains planned. Further work
can be developed independently where file ownership permits; 007 additionally
requires explicit session-policy and trusted-provider decisions.

The dispatcher defines all five action names without pretending session or lock
work before 007: unconfigured actions fail clearly, and their Nix hooks stay `null`.

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
