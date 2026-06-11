{
  lib,
  pkgs,
}: {
  name = "retroarch";
  # The bare package: only it carries the nixpkgs `wrapper` passthru that
  # bakes cores + a declarative retroarch.cfg (pkgs.retroarch et al. are
  # already-wrapped outputs without it).
  defaultPackage = "retroarch-bare";

  options = {
    cores = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["nestopia" "snes9x"];
      description = ''
        libretro core names (attributes of `pkgs.libretro`) baked into the
        wrapper. The cores' `.so` files land in the package's
        `lib/retroarch/cores`, which the wrapped binary points at via `-L`.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf (lib.types.oneOf [lib.types.bool lib.types.int lib.types.float lib.types.str]);
      default = {};
      example = {
        video_driver = "vulkan";
        config_save_on_exit = false;
      };
      description = ''
        retroarch.cfg entries baked into the wrapper via nixpkgs' declarative
        `--appendconfig`, layered over the user's mutable
        `~/.config/retroarch/retroarch.cfg` (which still owns everything else).
        Appended entries are never written back by retroarch.
      '';
    };
  };

  build = {
    cfg,
    pkgs,
    lib,
    ...
  }:
    cfg.package.wrapper {
      cores = map (name: pkgs.libretro.${name}) cfg.cores;
      settings =
        lib.mapAttrs (
          _: value:
            if lib.isBool value
            then lib.boolToString value
            else toString value
        )
        cfg.settings;
    };
}
