{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.gaming;

  # Plasma's shortcut used to call steamosctl switch-to-game-mode, which
  # tears down the desktop session and starts gamescope — the wrong
  # behaviour when the user just wants to relaunch Steam into Big
  # Picture without leaving plasma. The new flow: shut down any running
  # Steam cleanly, wait for it to actually exit (the single-instance
  # lock survives the IPC quit briefly), force-kill if it hangs, then
  # exec `steam -gamepadui` which is the modern Steam Deck-style Big
  # Picture UI inside the current wayland session.
  switchToBigPicture = pkgs.writeShellApplication {
    name = "switch-to-big-picture";
    runtimeInputs = [pkgs.coreutils pkgs.procps];
    text = ''
      if pgrep -x steam >/dev/null 2>&1; then
        steam -shutdown 2>/dev/null || true
        for _ in 1 2 3 4 5 6 7 8 9 10; do
          pgrep -x steam >/dev/null 2>&1 || break
          sleep 1
        done
        if pgrep -x steam >/dev/null 2>&1; then
          pkill -TERM -x steam || true
          sleep 1
          pkill -KILL -x steam || true
        fi
      fi
      exec steam -gamepadui
    '';
  };

  bigPictureDesktop = pkgs.makeDesktopItem {
    name = "switch-to-big-picture";
    desktopName = "Switch to Big Picture";
    comment = "Close Steam and re-launch it directly into Big Picture (SteamOS UI)";
    exec = "${switchToBigPicture}/bin/switch-to-big-picture";
    icon = "steam";
    categories = ["Game"];
    terminal = false;
  };

  gamerDesktopDir = "/home/${cfg.user}/Desktop";
in {
  jovian.steam = {
    enable = true;
    autoStart = true;
    user = cfg.user;
    desktopSession = cfg.defaultDesktopSession;
  };
  jovian.steamos.useSteamOSConfig = false;
  jovian.devices.steamdeck.enable = false;
  jovian.hardware.has.amd.gpu = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };
  programs.gamemode.enable = true;

  services.desktopManager.plasma6.enable = true;

  # Jovian's autoStart wiring sets `autoLogin.relogin = true` via plain
  # assignment so SDDM relogins gamer on logout, never showing a greeter.
  # mkForce false: on logout (Switch User → Logout from inside gamer's
  # plasma, or `loginctl terminate-session` from gamescope) we want
  # SDDM's greeter back so jasonbk can pick the Hyprland session.
  # Tradeoff: a Switch-to-Desktop round-trip costs one password prompt.
  services.displayManager.sddm.autoLogin.relogin = lib.mkForce false;

  environment.systemPackages =
    [switchToBigPicture bigPictureDesktop]
    ++ (with pkgs; [
      cmake
      gamescope
      mangohud
      protonup-qt
      wayvr
    ]);

  # gamer's plasma session surfaces the Big Picture launcher on the
  # desktop. tmpfiles' L+ overwrites any existing symlink so a closure
  # bump (new store path for switchToBigPicture) doesn't leave the entry
  # pointing at the previous generation.
  systemd.tmpfiles.settings."10-thebeast-gamer-desktop-shortcuts" = {
    ${gamerDesktopDir}.d = {
      mode = "0755";
      user = cfg.user;
      group = cfg.user;
    };
    "${gamerDesktopDir}/switch-to-big-picture.desktop"."L+" = {
      argument = "${bigPictureDesktop}/share/applications/switch-to-big-picture.desktop";
    };
  };

  # ROM systems drive RetroArch core selection and SRM parser generation
  # in home-manager/gamer/default.nix. Adding a new system here gives it
  # a romDir, an SRM parser, and (for retroarch entries) a libretro core
  # without further plumbing.
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

  # jasonbk's omarchy/Hyprland session. Lives here because it's part of
  # the desktop-session surface SDDM hands off to.
  omarchy.enable = true;
  omarchy.monitor = {
    mode = "5120x1440@120";
    vrr = 1;
  };
  omarchy.hdr = {
    enable = true;
    colorManagement = "hdr";
    sdrMinLuminance = 0.005;
    sdrMaxLuminance = 203;
  };
  omarchy.pim = "gnome";
  omarchy.waybar.hasBattery = false;
}
