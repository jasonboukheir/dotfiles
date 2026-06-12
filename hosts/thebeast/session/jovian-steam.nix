{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.gaming;
in {
  options.gaming.enable =
    lib.mkEnableOption "Jovian + Steam session for the gamer user";

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

    # Gamescope defaults Steam's HDR toggle off on non-Deck hardware, so
    # when the desktop session drives the display in HDR (omarchy.hdr's
    # cm=hdr), every Steam↔desktop handoff flipped HDR signaling and the
    # monitor black-flashed while it resynced. Match the desktop with
    # always-on HDR10 PQ output — the pair SteamOS ships on the Deck
    # OLED (Galileo).
    jovian.steam.environment = lib.mkIf config.omarchy.hdr.enable {
      STEAM_GAMESCOPE_FORCE_HDR_DEFAULT = "1";
      STEAM_GAMESCOPE_FORCE_OUTPUT_TO_HDR10PQ_DEFAULT = "1";
    };

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
    # so on a "fast-booting" cycle gamer autologins into gamescope before
    # the NIC has connectivity, Steam comes up offline, and its network
    # stack silently fails to initialise for the rest of the session.
    # Wanting+ordering the display manager after network-online.target
    # costs a few seconds of boot but closes the race. This ordering is
    # only as strong as wait-online itself: NM declares startup complete
    # immediately when no profile is waiting on a device, so the wired
    # profile in system/networking.nix carries wait-device-timeout to keep
    # wait-online honest until the NIC has appeared and activated (the igc
    # driver probes ~6s after NM starts on this host). The `wait-online`
    # service is `mkDefault true` when NM is enabled, so nothing else
    # needs to be flipped on. tests/dm-recovery.nix gates the whole chain
    # with a deliberately late-appearing NIC.
    systemd.services.display-manager = {
      wants = ["network-online.target"];
      after = ["network-online.target"];
    };
  };
}
