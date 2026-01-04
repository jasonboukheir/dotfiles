{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.omarchy.gnome-calendar;
in {
  options = {
    omarchy.gnome-calendar.enable = lib.mkEnableOption "Gnome calendar + todo suite";
  };
  config = {
    omarchy.gnome-calendar.enable = lib.mkDefault config.omarchy.enable;
    environment.systemPackages = with pkgs;
      lib.optionals cfg.enable [
        gnome-calendar
        endeavour
      ];
    programs.dconf.enable = lib.mkDefault cfg.enable;
    services.gnome = lib.mkIf cfg.enable {
      evolution-data-server.enable = true;
      gnome-online-accounts.enable = true;
      gnome-keyring.enable = true;
    };
  };
}
