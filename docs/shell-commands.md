# Shell Commands

The packaged `senntisten-shell` command and `./bin/senntisten-shell` in a checkout
share this action interface:

```text
senntisten-shell ACTION [--pid PID]
```

| Action | Behavior |
| --- | --- |
| `launcher` | Toggle the application launcher on the preferred monitor. |
| `dashboard` | Toggle Quick Controls, not Settings. |
| `settings` | Toggle the dedicated Settings window. |
| `session` | Unconfigured until a deliberate session menu is implemented. |
| `lock` | Unconfigured until a trusted lock provider is explicitly selected. |

The first three actions use the same controller as the bar. Repeating an action
closes the matching open surface on that monitor. Opening launcher or Settings
closes Quick Controls. Settings retains its normal return-to-Quick-Controls
behavior when opened from that panel.

## Instance Selection

Without `--pid`, dispatch selects only the running instance for the wrapper's
current source/package configuration. Missing or ambiguous instances are errors,
not requests to start a shell or select the oldest/newest process.

Source checkouts and different packaged builds have different configuration
identities. Use an explicit positive process ID to address a known preview,
checkout, or previous package instance:

```sh
senntisten-shell launcher --pid 12345
senntisten-shell dashboard --pid 12345
senntisten-shell settings --pid 12345
```

Replace the example PID with the intended running instance's PID. Explicit
selection still requires a Senntisten desktop instance; it does not turn a
playground or unrelated Quickshell application into one.

## Failure Behavior

Successful dispatch exits zero only when the requested action is accepted.
Missing instances, wrong modes, unavailable screens, malformed arguments,
transport errors, and rejected or invalid replies report errors and exit nonzero.
`session` and `lock` are explicitly unavailable, not successful no-ops.

Dispatch never starts a second shell, creates appearance directories, writes
appearance state, registers bindings, or changes providers. Normal launch modes
(`--desktop`, `--preview`, and `--playground`) remain separate from actions.
An action must be the first argument; arguments following a launch mode are still
forwarded literally to Quickshell, not interpreted as dispatcher actions.
`--help` describes both interfaces without starting the shell.

## Evidence Boundary

Recorder tests establish argument/error behavior; isolated real-QML IPC tests
establish controller routing and intended-instance selection. Packaged checks
exercise the installed entry point. None establishes compositor focus, popup hit
testing, monitor hotplug, or GPU rendering. Those remain the separate
[native acceptance gate](issues/001-native-verification.md).
