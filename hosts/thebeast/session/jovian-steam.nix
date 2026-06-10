{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.gaming;
  # The canonical DM unit differs per DM: plasma-login-manager ships a
  # real `plasmalogin.service` and only aliases `display-manager.service`
  # (systemd.services overrides keyed by an alias get clobbered by the
  # alias-generation pass), while NixOS's sddm path skips the upstream
  # unit entirely and execs sddm from `display-manager.service` itself.
  dmUnit =
    if config.thebeast.displayManager == "plasma-login-manager"
    then "plasmalogin"
    else "display-manager";
in {
  options.gaming.enable =
    lib.mkEnableOption "Jovian + Steam + plasma desktop session for the gamer user";

  config = lib.mkIf cfg.enable {
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

    environment.systemPackages = with pkgs; [
      cmake
      gamescope
      mangohud
      protonup-qt
      wayvr
    ];

    # SDDM only re-runs autologin after a session exit when Relogin=true
    # (Display.cpp displayServerStarted: `daemonApp->first || m_relogin`);
    # jovian sets it true via plain assignment for SteamOS parity.
    # gaming.exitToGreeter (default on) deliberately forces it off — see
    # the option description for the intended exit-Steam-to-dev-session
    # flow and tests/steamos-autologin.nix for both behaviours.
    services.displayManager.sddm.autoLogin.relogin =
      lib.mkIf cfg.exitToGreeter (lib.mkForce false);

    # Steam's network stack (login, content servers, Remote Play, friends
    # service) initialises during user-session startup. The display
    # manager unit has no default ordering against network-online.target,
    # so on a "fast-booting" cycle NetworkManager's iwd backend can still
    # be associating when gamer autologins into gamescope, Steam comes up
    # without connectivity, and the network stack silently fails to
    # initialise for the rest of the session — observed intermittently
    # depending on AP association timing. Wanting+ordering the display
    # manager after network-online.target costs a couple of seconds of
    # boot when wifi is slow but eliminates the race entirely. The
    # `wait-online` service is `mkDefault true` when NM is enabled, so
    # nothing else needs to be flipped on.
    systemd.services.${dmUnit} = {
      wants = ["network-online.target"];
      after = ["network-online.target"];
    };
  };
}
