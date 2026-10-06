# Home Manager Integration

The flake exports `homeManagerModules.default`. Importing it declares options;
it does not install or activate Senntisten until explicitly configured.

## Installation Only

In an existing consumer flake, include the module in the Home Manager module list:

```nix
homeConfigurations.felipe = inputs.home-manager.lib.homeManagerConfiguration {
  pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
  modules = [
    inputs.senntisten-shell.homeManagerModules.default
    ./home.nix
    { programs.senntisten-shell.enable = true; }
  ];
};
```

The consumer supplies its existing Home Manager input and normal home options.
This repository does not add a Home Manager dependency merely to evaluate the
module, and this example is not an instruction to activate the user's configuration.

Installation exposes the package without enabling autostart, services, bindings,
notifications, locking, or wallpaper ownership. The package defaults to this
flake's pinned Quickshell/Qt closure. The typed `package` option allows an explicitly
selected replacement; the caller is responsible for its compatible runtime.

## Command Hooks

Enable command exposure separately from installation:

```nix
programs.senntisten-shell = {
  enable = true;
  commands.enable = true;
};
```

`programs.senntisten-shell.shellCommands` exposes the five nullable hooks used by
the external provider contract. Installation alone leaves every hook `null`.
Explicit command exposure provides launcher, dashboard, and Settings commands;
session and lock remain `null` until their capabilities are implemented.

An external consumer that already declares the contract can deliberately bridge it:

```nix
my.desktop.shellCommands = config.programs.senntisten-shell.shellCommands;
```

The module does not declare `my.desktop`, select an external provider, or register
bindings itself. Commands invoke the [packaged dispatcher](shell-commands.md), not
hard-coded Quickshell asset paths. Its default identity selection requires the
matching package instance to be running. Explicit PID selection is for a known
instance and must be updated when that process exits; it is not a stable autostart
identifier.

## Options

| Option under `programs.senntisten-shell` | Default | Purpose |
| --- | --- | --- |
| `enable` | `false` | Install the package in `home.packages`. |
| `package` | Pinned flake package | Select the package/executable. |
| `distroId` | `"nixos"` | Customize branding in the default package only. |
| `commands.enable` | `false` | Expose the three supported toggle commands. |
| `commands.pid` | `null` | Select a known positive PID instead of the current package identity. |
| `shellCommands.*` | `null` | Read-only nullable outputs, generated only for supported actions. |

Command exposure can be enabled without profile installation, for consumers that
use the generated absolute store paths. A custom package is used unchanged and
must implement the dispatcher contract; `distroId` does not override it.

## State And Defaults

The declarative distribution-branding default belongs to Nix. Mutable appearance
does not: the module never generates or installs `appearance.json`. Existing
palette/reduced-motion state and unsupported newer schemas keep their normal
safe handling.

## Verification And Activation

Repository-local `lib.evalModules` fixtures exercise options, generated commands,
custom packages, disabled/install-only configurations, and invalid values without
activating Home Manager. Package checks separately exercise the installed CLI.
These fixtures are not a full external Home Manager deployment test.

Run the module fixtures without installing or activating a configuration:

```sh
make test-module
```

[Native acceptance](issues/001-native-verification.md), provider registration,
global bindings, startup, and replacement of any existing shell remain separately
approved steps. Implementing this module does not authorize editing the external
Nix configuration or switching services.
