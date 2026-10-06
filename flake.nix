{
  description = "Senntisten Shell — personal Hyprland shell built with Quickshell";

  # Shared with nix-config; keep Quickshell and its Qt tooling on one pin.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/9fbb54b33e91ee4ca368e35a78e0613c720600b3";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forEachSystem = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs { inherit system; }));
      testSource = nixpkgs.lib.fileset.toSource {
        root = ./.;
        fileset = nixpkgs.lib.fileset.unions [
          ./bin
          ./shell
          ./tests
        ];
      };
    in
    {
      homeManagerModules.default = import ./nix/home-manager.nix { inherit self; };

      packages = forEachSystem (pkgs: {
        default = pkgs.callPackage ./nix/package.nix { };
      });

      apps = forEachSystem (pkgs: {
        default = {
          type = "app";
          program = nixpkgs.lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.default;
          meta.description = "Launch the Senntisten desktop shell";
        };
      });

      devShells = forEachSystem (pkgs: {
        default = pkgs.mkShellNoCC {
          packages = with pkgs; [
            quickshell
            nodejs
            python3
            qt6.qtdeclarative
            qt6.qtdeclarative.dev
            bash
            coreutils
            jq
            shellcheck
            nixfmt
          ];
        };
      });

      formatter = forEachSystem (pkgs: pkgs.nixfmt);

      checks = forEachSystem (pkgs: {
        package = self.packages.${pkgs.stdenv.hostPlatform.system}.default;

        home-manager =
          let
            results = import ./nix/tests/home-manager.nix {
              inherit (pkgs) lib;
              inherit pkgs;
              module = self.homeManagerModules.default;
              defaultPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
            };
          in
          if results.failures == [ ] then
            pkgs.runCommand "senntisten-shell-home-manager-tests" { } ''
              cp ${pkgs.writeText "home-manager-test-report.json" (builtins.toJSON results.names)} "$out"
            ''
          else
            throw "Home Manager module tests failed: ${builtins.toJSON results.failures}";

        unit-tests =
          pkgs.runCommand "senntisten-shell-unit-tests"
            {
              nativeBuildInputs = with pkgs; [
                bash
                coreutils
                nodejs
                jq
              ];
            }
            ''
              cp -R ${testSource} source
              chmod -R u+w source
              # The Nix sandbox has no /usr/bin/env; exercise the real executable.
              patchShebangs source/bin
              cd source
              node --test tests/*.test.mjs
              touch "$out"
            '';

        integration =
          pkgs.runCommand "senntisten-shell-integration"
            {
              # Offscreen Qt still needs real, deterministic fonts in the sandbox.
              FONTCONFIG_FILE = pkgs.makeFontsConf {
                fontDirectories = [ pkgs.dejavu_fonts ];
                impureFontDirectories = [ ];
                includes = [ ];
              };
              nativeBuildInputs = with pkgs; [
                bash
                coreutils
                python3
                quickshell
                jq
              ];
            }
            ''
              cp -R ${testSource} source
              chmod -R u+w source
              # The Nix sandbox has no /usr/bin/env; exercise the real executable.
              patchShebangs source/bin
              cd source
              export HOME="$TMPDIR/home"
              mkdir -p "$HOME"
              python3 -m unittest discover -s tests -p '*integration.py' -v
              touch "$out"
            '';

        package-smoke =
          pkgs.runCommand "senntisten-shell-package-smoke"
            {
              SENNTISTEN_PACKAGE = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
              FONTCONFIG_FILE = pkgs.makeFontsConf {
                fontDirectories = [ pkgs.dejavu_fonts ];
                impureFontDirectories = [ ];
                includes = [ ];
              };
              nativeBuildInputs = with pkgs; [
                bash
                coreutils
                python3
                quickshell
                jq
              ];
            }
            ''
              cp -R ${testSource} source
              chmod -R u+w source
              cd source
              export HOME="$TMPDIR/home"
              mkdir -p "$HOME"
              python3 -W error::ResourceWarning tests/package_smoke.py
              touch "$out"
            '';

        lint =
          pkgs.runCommand "senntisten-shell-lint"
            {
              nativeBuildInputs = with pkgs; [
                bash
                coreutils
                shellcheck
                nixfmt
              ];
            }
            ''
              bash -n ${./bin/senntisten-shell}
              shellcheck ${./bin/senntisten-shell}
              nixfmt --check ${./flake.nix} ${./nix/package.nix} ${./nix/home-manager.nix} ${./nix/tests/home-manager.nix}
              touch "$out"
            '';
      });
    };
}
