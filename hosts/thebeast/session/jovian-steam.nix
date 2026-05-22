{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.gaming;
  # NixOS's `display-manager.service` is an alias, not the canonical
  # unit — the actual unit is `sddm.service` or `plasmalogin.service`
  # depending on which DM the host opts into in hosts/thebeast/options.nix.
  # systemd.services overrides keyed by alias get clobbered by the
  # alias-generation pass, so we have to target the real name.
  dmUnit =
    if config.thebeast.displayManager == "plasma-login-manager"
    then "plasmalogin"
    else "sddm";
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

    # Jovian's autoStart wiring sets `autoLogin.relogin = true` via plain
    # assignment so SDDM relogins gamer on logout, never showing a greeter.
    # mkForce false: on logout (Switch User → Logout from inside gamer's
    # plasma, or `loginctl terminate-session` from gamescope) we want
    # the greeter back so jasonbk can pick the Hyprland session.
    # Tradeoff: a Switch-to-Desktop round-trip costs one password prompt.
    services.displayManager.sddm.autoLogin.relogin = lib.mkForce false;

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
