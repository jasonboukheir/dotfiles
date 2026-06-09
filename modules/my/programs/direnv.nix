# Program definition for a per-user WRAPPED direnv (my.direnv). Replaces the OLD
# native programs.direnv system module (programs.direnv + nix-direnv): instead of
# a system-wide direnvrc and shell hooks, this bakes a private config dir (pointed
# at via $DIRENV_CONFIG) carrying direnvrc (sourcing nix-direnv) and direnv.toml,
# so a single user gets a configured direnv on PATH without any system module.
#
# direnv resolves its config dir from $DIRENV_CONFIG (overriding the default
# $XDG_CONFIG_HOME/direnv); that dir holds `direnvrc` and `direnv.toml`. The
# `direnv hook <shell>` line is NOT baked here — it lives in the shell wrappers
# (my.fish etc.). direnv must be installed in the same environment as the shell.
# See ./CONTRACT.md and docs/plans/2026-06-09-my-namespace-wrappers-design-final.md
# ("fish & direnv").
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
