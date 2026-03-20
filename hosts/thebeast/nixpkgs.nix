{
  config,
  lib,
  ...
}:
  lib.mkIf config.gaming.enable {
    allowUnfreePackageNames = [
      "libretro-beetle-psx-hw"
      "libretro-gambatte"
      "libretro-genesis-plus-gx"
      "libretro-melonds"
      "libretro-mgba"
      "libretro-mupen64plus"
      "libretro-nestopia"
      "libretro-snes9x"
      "steam"
      "steamcmd"
      "steam-tui"
      "steam-original"
      "steam-run"
      "steamdeck-hw-theme"
      "steam-jupiter-unwrapped"
    ];
  }
