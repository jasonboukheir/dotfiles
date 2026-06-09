{
  lib,
  pkgs,
}: let
  tomlFormat = pkgs.formats.toml {};
in {
  name = "direnv";
  defaultPackage = "direnv";

  options = {
    enableNixDirenv = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Source nix-direnv's direnvrc into this wrapper's baked direnvrc, giving
        the faster cached `use nix` / `use flake`. Replaces the OLD native
        programs.direnv.nix-direnv.enable.
      '';
    };

    stdlib = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = ''
        export_function() { … }
      '';
      description = ''
        Extra direnvrc content baked into this wrapper, appended after the
        nix-direnv source line. Equivalent to ~/.config/direnv/direnvrc.
      '';
    };

    settings = lib.mkOption {
      type = tomlFormat.type;
      default = {};
      example = {
        global.warn_timeout = "1m";
        whitelist.prefix = ["/home/me/projects"];
      };
      description = ''
        direnv.toml content baked into this wrapper's config dir (pointed at via
        $DIRENV_CONFIG).
      '';
    };
  };

  build = {
    cfg,
    pkgs,
    lib,
    ...
  }: let
    direnvrc =
      lib.optionalString cfg.enableNixDirenv
      "source ${pkgs.nix-direnv}/share/nix-direnv/direnvrc\n"
      + cfg.stdlib;

    configDir = pkgs.linkFarm "my-direnv-config" [
      {
        name = "direnvrc";
        path = pkgs.writeText "direnvrc" direnvrc;
      }
      {
        name = "direnv.toml";
        path = tomlFormat.generate "direnv.toml" cfg.settings;
      }
    ];
  in
    pkgs.mkWrapped {
      pkg = cfg.package;
      name = "direnv";
      env.DIRENV_CONFIG = "${configDir}";
    };
}
