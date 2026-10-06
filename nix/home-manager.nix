{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.senntisten-shell;
  toggles = [
    "launcher"
    "dashboard"
    "settings"
  ];
  commandNames = toggles ++ [
    "session"
    "lock"
  ];
  command =
    name:
    if cfg.commands.enable then
      "${lib.escapeShellArg (lib.getExe cfg.package)} ${name}"
      + lib.optionalString (cfg.commands.pid != null) " --pid ${toString cfg.commands.pid}"
    else
      null;
in
{
  options.programs.senntisten-shell = {
    enable = lib.mkEnableOption "installation of Senntisten Shell (without desktop activation)";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
        inherit (cfg) distroId;
      };
      defaultText = lib.literalExpression "senntisten-shell.packages.\${pkgs.stdenv.hostPlatform.system}.default.override { inherit (config.programs.senntisten-shell) distroId; }";
      description = ''
        Senntisten Shell package. The default uses this flake's pinned dependencies
        and the configured distroId. A supplied package is used unchanged and need
        not implement override; it must provide the Senntisten dispatcher contract
        through its main executable when commands.enable is set.
      '';
    };

    distroId = lib.mkOption {
      type = lib.types.str;
      default = "nixos";
      description = ''
        Distribution-mark default supplied by the default pinned package as the
        SENNTISTEN_DISTRO_ID environment fallback. This does not modify a supplied
        custom package or write mutable appearance state. Unknown IDs use the
        runtime's generic mark.
      '';
    };

    commands = {
      enable =
        lib.mkEnableOption "exposure of Senntisten's launcher, dashboard, and settings toggle commands"
        // {
          description = ''
            Expose commands for external consumers, independently of package
            installation. This does not start a shell, register bindings or services,
            replace providers, or write appearance state. Commands require an
            already running instance. Session and lock are unavailable and stay null.

            Consumers may bridge the hooks explicitly with
            `my.desktop.shellCommands = config.programs.senntisten-shell.shellCommands;`.
            This module does not define the external my namespace; provider selection,
            autostart, bindings, and desktop activation require separate configuration
            and approval.
          '';
        };

      pid = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = null;
        description = ''
          Optional positive PID of an explicit running instance. With null, the
          dispatcher targets only the current packaged identity and rejects
          ambiguous instances. A PID adds `--pid PID` after the toggle subcommand
          and may select a running instance across package versions, source runs,
          or previews. This does not enable command exposure or start an instance.
        '';
      };
    };

    shellCommands = lib.genAttrs commandNames (
      name:
      lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        readOnly = true;
        # Force the declared value so apply does not bypass read-only/type checks.
        apply = value: builtins.seq value (if builtins.elem name toggles then command name else null);
        description =
          if builtins.elem name toggles then
            ''
              Generated ${name} toggle command for external shell-command consumers.
              Null unless commands.enable is set. Uses the selected package's
              executable and commands.pid; it does not launch a new shell instance.
            ''
          else
            ''
              Unavailable ${name} hook for external shell-command consumers. Always
              null; Senntisten does not take ownership of this capability.
            '';
      }
    );
  };

  config.home.packages = lib.optional cfg.enable cfg.package;
}
