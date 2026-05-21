{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.gaming;
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
  };
}
