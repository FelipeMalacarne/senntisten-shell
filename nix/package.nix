{
  lib,
  stdenvNoCC,
  writeShellApplication,
  bash,
  coreutils,
  quickshell,
  dejavu_fonts,
  makeFontsConf,
  distroId ? "nixos",
}:
let
  fontConfig = makeFontsConf {
    fontDirectories = [ dejavu_fonts ];
  };
  assets = stdenvNoCC.mkDerivation {
    pname = "senntisten-shell-assets";
    version = "0.1.0";
    src = lib.fileset.toSource {
      root = ../.;
      fileset = lib.fileset.unions [
        ../bin/senntisten-shell
        ../shell
      ];
    };
    dontBuild = true;
    nativeBuildInputs = [
      bash
      coreutils
    ];
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/share/senntisten-shell" "$out/libexec"
      cp -R shell "$out/share/senntisten-shell/shell"
      install -m755 bin/senntisten-shell "$out/libexec/senntisten-shell"
      substituteInPlace "$out/libexec/senntisten-shell" \
        --replace-fail '#!/usr/bin/env bash' '#!${bash}/bin/bash'
      runHook postInstall
    '';
  };
in
writeShellApplication {
  name = "senntisten-shell";
  runtimeInputs = [
    quickshell
    bash
    coreutils
  ];
  text = ''
    export SENNTISTEN_QUICKSHELL="''${SENNTISTEN_QUICKSHELL:-${lib.getExe quickshell}}"
    export SENNTISTEN_SOURCE_DIR="''${SENNTISTEN_SOURCE_DIR:-${assets}/share/senntisten-shell/shell}"
    distro_id=${lib.escapeShellArg distroId}
    export SENNTISTEN_DISTRO_ID="''${SENNTISTEN_DISTRO_ID:-$distro_id}"
    export FONTCONFIG_FILE="''${FONTCONFIG_FILE:-${fontConfig}}"
    exec ${assets}/libexec/senntisten-shell "$@"
  '';
  passthru = { inherit assets quickshell; };
  meta = {
    description = "Personal Hyprland bar, launcher, and appearance tools built with Quickshell";
    mainProgram = "senntisten-shell";
    platforms = lib.platforms.linux;
  };
}
