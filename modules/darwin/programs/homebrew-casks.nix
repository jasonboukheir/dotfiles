{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homebrewCasks;

  caskSubmodule = {
    name,
    config,
    ...
  }: {
    options = {
      enable = lib.mkEnableOption "installing via Homebrew cask instead of Nix";
      caskName = lib.mkOption {
        type = lib.types.str;
        description = "The Homebrew cask name.";
      };
      appName = lib.mkOption {
        type = lib.types.str;
        description = "The .app bundle name in /Applications.";
      };
      binaries = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Map of bin/<name> to create → binary name inside Contents/MacOS/.";
      };
      appPath = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        default = "/Applications/${config.appName}.app";
        description = "Path to the Homebrew-installed app in /Applications.";
      };
      package = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        default = pkgs.runCommand "${name}-cask-stub" {} (
          lib.optionalString (config.binaries != {}) ''
            mkdir -p "$out/bin"
          ''
          + lib.concatStringsSep "\n" (lib.mapAttrsToList (binName: macOSName: ''
            cat > "$out/bin/${binName}" <<'STUB'
            #!/bin/sh
            exec "/Applications/${config.appName}.app/Contents/MacOS/${macOSName}" "$@"
            STUB
            chmod +x "$out/bin/${binName}"
          '')
          config.binaries)
        );
        description = "Stub package providing bin/ shims to the Homebrew-installed app.";
      };
    };
  };
in {
  options.homebrewCasks = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule caskSubmodule);
    default = {};
    description = "Apps to install via Homebrew casks with stub Nix packages.";
  };

  config = {
    homebrewCasks.brave = {
      caskName = lib.mkDefault "brave-browser";
      appName = lib.mkDefault "Brave Browser";
      binaries = lib.mkDefault {brave = "Brave Browser";};
    };
    homebrewCasks.zed = {
      caskName = lib.mkDefault "zed";
      appName = lib.mkDefault "Zed";
      binaries = lib.mkDefault {zeditor = "zed";};
    };

    homebrew.casks = lib.pipe cfg [
      (lib.filterAttrs (_: v: v.enable))
      (lib.mapAttrsToList (_: v: v.caskName))
    ];
  };
}
