{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.gaming;

  # Plasma's stock Breeze SDDM theme ships theme.conf with
  # `needsFullUserModel=false`, which makes the greeter's userModel report
  # `containsAllUsers=false`. Main.qml then hides the user grid entirely
  # (Main.qml:190) and Login.qml falls back to a plain username text box
  # (Login.qml:15) — so jasonbk has no clickable tile and "Switch User"
  # appears to do nothing. Override the one key.
  breezeAllUsers = pkgs.runCommand "sddm-theme-breeze-allusers" {} ''
    mkdir -p $out/share/sddm/themes
    cp -r ${pkgs.kdePackages.plasma-desktop}/share/sddm/themes/breeze \
      $out/share/sddm/themes/breeze-allusers
    chmod -R u+w $out/share/sddm/themes/breeze-allusers
    ${pkgs.gnused}/bin/sed -i \
      's/^needsFullUserModel=.*/needsFullUserModel=true/' \
      $out/share/sddm/themes/breeze-allusers/theme.conf
  '';
in
  lib.mkIf config.gaming.enable {
    gaming.user = "gamer";

    jovian.steam.enable = true;
    jovian.steam.autoStart = true;
    jovian.steam.user = cfg.user;
    jovian.steam.desktopSession = "plasma";
    jovian.steamos.useSteamOSConfig = false;
    jovian.devices.steamdeck.enable = false;
    jovian.hardware.has.amd.gpu = true;

    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };

    services.desktopManager.plasma6.enable = true;

    services.displayManager.sddm.theme = "breeze-allusers";
    environment.systemPackages = [breezeAllUsers];

    services.displayManager.sddm.settings = {
      # EmptyPassword lets the SDDM greeter submit "" to PAM, which the
      # sddm→login stack accepts via `nullok` on pam_unix. Needed so "Switch
      # User" from Plasma can re-select the passwordless gamer account.
      General.EmptyPassword = true;
      # autoLogin's session lands on tty1 by default — same VT systemd
      # reserves via autovt@tty1, and the "Switch User" greeter then races
      # for it. Push both onto tty7+ so the new greeter gets its own VT.
      General.MinimumVT = 7;
      # nixpkgs sddm.nix only injects these when `theme == "breeze"`; our
      # rename loses them, so the greeter falls back to a chunky default
      # cursor without these.
      Theme.CursorTheme = "breeze_cursors";
      Theme.CursorSize = 24;
    };

    # /dev/uinput access for Steam Input's virtual mouse/keyboard mapping
    # (the path the 8BitDo controller takes when Steam runs in Plasma).
    hardware.uinput.enable = true;
  }
