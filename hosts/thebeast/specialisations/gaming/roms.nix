{
  config,
  ...
}: let
  cfg = config.gaming;
in {
  gaming.romDir = "/games/roms";
  gaming.systems = [
    {
      name = "NES";
      type = "retroarch";
      core = "nestopia";
      coreSo = "nestopia_libretro.so";
      dir = "nes";
      ext = ["nes" "zip"];
    }
    {
      name = "SNES";
      type = "retroarch";
      core = "snes9x";
      coreSo = "snes9x_libretro.so";
      dir = "snes";
      ext = ["sfc" "smc" "zip"];
    }
    {
      name = "Genesis";
      type = "retroarch";
      core = "genesis-plus-gx";
      coreSo = "genesis_plus_gx_libretro.so";
      dir = "genesis";
      ext = ["md" "gen" "zip"];
    }
    {
      name = "GB / GBC";
      type = "retroarch";
      core = "gambatte";
      coreSo = "gambatte_libretro.so";
      dir = "gb";
      ext = ["gb" "gbc" "zip"];
    }
    {
      name = "GBA";
      type = "retroarch";
      core = "mgba";
      coreSo = "mgba_libretro.so";
      dir = "gba";
      ext = ["gba" "zip"];
    }
    {
      name = "PS1";
      type = "retroarch";
      core = "beetle-psx-hw";
      coreSo = "mednafen_psx_hw_libretro.so";
      dir = "ps1";
      ext = ["chd" "cue" "iso" "bin"];
    }
    {
      name = "N64";
      type = "retroarch";
      core = "mupen64plus";
      coreSo = "mupen64plus_next_libretro.so";
      dir = "n64";
      ext = ["z64" "n64" "v64" "zip"];
    }
    {
      name = "DS";
      type = "retroarch";
      core = "melonds";
      coreSo = "melonds_libretro.so";
      dir = "ds";
      ext = ["nds" "zip"];
    }
    {
      name = "GameCube";
      type = "standalone";
      pkg = "dolphin-emu";
      bin = "dolphin-emu";
      dir = "gamecube";
      ext = ["iso" "gcm" "ciso" "gcz" "rvz"];
    }
    {
      name = "Wii";
      type = "standalone";
      pkg = "dolphin-emu";
      bin = "dolphin-emu";
      dir = "wii";
      ext = ["iso" "wbfs" "gcz" "rvz"];
    }
    {
      name = "PS2";
      type = "standalone";
      pkg = "pcsx2";
      bin = "pcsx2-qt";
      dir = "ps2";
      ext = ["iso" "chd" "cso" "gz"];
    }
  ];

  systemd.tmpfiles.rules =
    ["d ${cfg.romDir} 0775 ${cfg.user} users -"]
    ++ map (s: "d ${cfg.romDir}/${s.dir} 0775 ${cfg.user} users -") cfg.systems;
}
