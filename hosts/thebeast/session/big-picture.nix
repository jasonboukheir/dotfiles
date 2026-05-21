{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.gaming;
  gamerDesktopDir = "/home/${cfg.user}/Desktop";

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
in {
  options.gaming.bigPicture.enable =
    lib.mkEnableOption "Switch-to-Big-Picture launcher on gamer's plasma desktop";

  config = lib.mkIf cfg.bigPicture.enable {
    environment.systemPackages = [switchToBigPicture bigPictureDesktop];

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
  };
}
