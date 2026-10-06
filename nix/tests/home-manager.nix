{
  lib,
  pkgs,
  module,
  defaultPackage,
}:
let
  commandNames = [
    "launcher"
    "dashboard"
    "settings"
    "session"
    "lock"
  ];
  emptyCommands = lib.genAttrs commandNames (_: null);
  evaluate =
    settings:
    lib.evalModules {
      specialArgs = { inherit pkgs; };
      modules = [
        module
        {
          options.home.packages = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
          };
        }
        { programs.senntisten-shell = settings; }
      ];
    };
  snapshot =
    settings:
    let
      evaluated = evaluate settings;
      cfg = evaluated.config.programs.senntisten-shell;
    in
    {
      inherit (cfg)
        enable
        distroId
        shellCommands
        commands
        ;
      package = toString cfg.package;
      installed = map toString evaluated.config.home.packages;
    };
  rejects = settings: !(builtins.tryEval (builtins.deepSeq (snapshot settings) true)).success;
  expectedCommands =
    package: pid:
    emptyCommands
    // lib.genAttrs [ "launcher" "dashboard" "settings" ] (
      name:
      "${lib.escapeShellArg (lib.getExe package)} ${name}"
      + lib.optionalString (pid != null) " --pid ${toString pid}"
    );

  # A real package with no override method, as allowed by types.package.
  customPackage =
    (builtins.derivation {
      name = "senntisten-shell-custom-fixture";
      system = pkgs.stdenv.hostPlatform.system;
      builder = lib.getExe pkgs.bash;
      args = [
        "-c"
        ''mkdir -p "$out"''
      ];
    })
    // {
      meta.mainProgram = "custom-senntisten";
    };
  unusualExecutable = customPackage // {
    meta.mainProgram = "custom shell'; printf unsafe #";
  };
  disabled = snapshot { };
  installOnly = snapshot { enable = true; };
  commandsOnly = snapshot { commands.enable = true; };
  installedCommands = snapshot {
    enable = true;
    commands.enable = true;
  };
  explicitPid = snapshot {
    commands = {
      enable = true;
      pid = 4242;
    };
  };
  custom = snapshot {
    enable = true;
    package = customPackage;
    distroId = "arch";
    commands.enable = true;
  };
  distro = snapshot {
    enable = true;
    distroId = "arch";
    commands.enable = true;
  };
  distroPackage = defaultPackage.override { distroId = "arch"; };
  declaredOptions = (evaluate { }).options.programs.senntisten-shell;

  tests = {
    testDisabled = {
      expr = disabled;
      expected = {
        enable = false;
        distroId = "nixos";
        commands = {
          enable = false;
          pid = null;
        };
        package = toString defaultPackage;
        installed = [ ];
        shellCommands = emptyCommands;
      };
    };
    testInstallOnly = {
      expr = {
        inherit (installOnly) installed shellCommands;
      };
      expected = {
        installed = [ (toString defaultPackage) ];
        shellCommands = emptyCommands;
      };
    };
    testCommandsWithoutInstallation = {
      expr = {
        inherit (commandsOnly) installed shellCommands;
      };
      expected = {
        installed = [ ];
        shellCommands = expectedCommands defaultPackage null;
      };
    };
    testCommandsWithInstallation = {
      expr = {
        inherit (installedCommands) installed shellCommands;
      };
      expected = {
        installed = [ (toString defaultPackage) ];
        shellCommands = expectedCommands defaultPackage null;
      };
    };
    testExplicitPid = {
      expr = explicitPid.shellCommands;
      expected = expectedCommands defaultPackage 4242;
    };
    testSmallestPositivePid = {
      expr =
        (snapshot {
          commands = {
            enable = true;
            pid = 1;
          };
        }).shellCommands;
      expected = expectedCommands defaultPackage 1;
    };
    testPidDoesNotEnableCommands = {
      expr = (snapshot { commands.pid = 4242; }).shellCommands;
      expected = emptyCommands;
    };
    testCustomPackageWithoutOverride = {
      expr = {
        hasOverride = customPackage ? override;
        inherit (custom) package installed shellCommands;
      };
      expected = {
        hasOverride = false;
        package = toString customPackage;
        installed = [ (toString customPackage) ];
        shellCommands = expectedCommands customPackage null;
      };
    };
    testCustomExecutableIsShellEscaped = {
      expr =
        (snapshot {
          package = unusualExecutable;
          commands.enable = true;
        }).shellCommands;
      expected = expectedCommands unusualExecutable null;
    };
    testCustomPackageWithExplicitPid = {
      expr =
        (snapshot {
          package = customPackage;
          commands = {
            enable = true;
            pid = 4242;
          };
        }).shellCommands;
      expected = expectedCommands customPackage 4242;
    };
    testDistroDefaultOverridesPinnedPackage = {
      expr = {
        inherit (distro) package installed shellCommands;
        changesDefault = distro.package != disabled.package;
      };
      expected = {
        package = toString distroPackage;
        installed = [ (toString distroPackage) ];
        shellCommands = expectedCommands distroPackage null;
        changesDefault = true;
      };
    };
    testUnconfiguredHooksRemainNull = {
      expr =
        map
          (fixture: {
            inherit (fixture.shellCommands) session lock;
          })
          [
            disabled
            installOnly
            commandsOnly
            explicitPid
            custom
          ];
      expected = lib.replicate 5 {
        session = null;
        lock = null;
      };
    };
    testCommandOptionTypesAndDefaults = {
      expr = lib.genAttrs commandNames (
        name:
        let
          option = declaredOptions.shellCommands.${name};
        in
        {
          inherit (option) default readOnly;
          type = option.type.name;
          acceptsNull = option.type.check null;
          acceptsString = option.type.check "command";
          rejectsInteger = !(option.type.check 1);
        }
      );
      expected = lib.genAttrs commandNames (_: {
        default = null;
        readOnly = true;
        type = (lib.types.nullOr lib.types.str).name;
        acceptsNull = true;
        acceptsString = true;
        rejectsInteger = true;
      });
    };
    testPackageOptionIsTyped = {
      expr = {
        type = declaredOptions.package.type.name;
        acceptsPackage = declaredOptions.package.type.check customPackage;
        rejectsString = !(declaredOptions.package.type.check "/bin/senntisten-shell");
      };
      expected = {
        type = lib.types.package.name;
        acceptsPackage = true;
        rejectsString = true;
      };
    };
    testNoActivationOrMutableStateDefinitions = {
      expr =
        map
          (
            settings:
            let
              cfg = (evaluate settings).config;
            in
            {
              namespaces = builtins.attrNames cfg;
              homeOptions = builtins.attrNames cfg.home;
              programs = builtins.attrNames cfg.programs;
            }
          )
          [
            { }
            {
              enable = true;
              commands.enable = true;
            }
          ];
      expected = lib.replicate 2 {
        namespaces = [
          "home"
          "programs"
        ];
        homeOptions = [ "packages" ];
        programs = [ "senntisten-shell" ];
      };
    };
    testInvalidTypes = {
      expr = map rejects [
        { enable = "yes"; }
        { commands.enable = "yes"; }
        { package = "/bin/senntisten-shell"; }
        { distroId = false; }
        { commands.pid = 0; }
        { commands.pid = -1; }
        { commands.pid = 1.5; }
        { commands.pid = "4242"; }
        { commands.pid = "4242; printf unsafe"; }
        { commands.pid = true; }
        { shellCommands.launcher = 1; }
        { shellCommands.session = "unsupported"; }
        { shellCommands.lock = "unsupported"; }
      ];
      expected = lib.replicate 13 true;
    };
    testUnknownOptionsAreRejected = {
      expr = rejects { unknownOption = true; };
      expected = true;
    };
  };
in
{
  failures = lib.runTests tests;
  names = builtins.attrNames tests;
}
