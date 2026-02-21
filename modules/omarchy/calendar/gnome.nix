{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.omarchy;
in {
  config = lib.mkIf (cfg.enable && cfg.pim == "gnome") {
    environment.systemPackages = with pkgs; [
      gnome-online-accounts-gtk
      gnome-calendar
      gnome-contacts
      errands
    ];
    programs.dconf.enable = lib.mkDefault true;
    services.gnome = {
      evolution-data-server.enable = true;
      gnome-online-accounts.enable = true;
      gnome-keyring.enable = true;
    };
    security.pam.services.greetd.enableGnomeKeyring =
      lib.mkIf config.services.greetd.enable true;
    omarchy.defaultApps = {
      calendar = lib.mkDefault "gnome-calendar";
      contacts = lib.mkDefault "gnome-contacts";
      reminders = lib.mkDefault "errands";
    };
  };
}
