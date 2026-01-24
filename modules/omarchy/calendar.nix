{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.omarchy;
in {
  options.omarchy = {
    pim = lib.mkOption {
      type = lib.types.enum ["gnome" "kde" "evolution"];
      default = "gnome";
      description = "The calendar (ical) suite to use";
    };
  };
  config = lib.mkIf cfg.enable (lib.mkMerge [
    (lib.mkIf (cfg.pim == "gnome") {
      environment.systemPackages = with pkgs;
        lib.optionals cfg.enable [
          gnome-calendar
          gnome-contacts
          errands
        ];
      programs.dconf.enable = lib.mkDefault cfg.enable;
      services.gnome = lib.mkIf cfg.enable {
        evolution-data-server.enable = true;
        gnome-online-accounts.enable = true;
        gnome-keyring.enable = true;
      };
      omarchy.defaultApps = {
        calendar = lib.mkDefault "gnome-calendar";
        contacts = lib.mkDefault "gnome-contacts";
        reminders = lib.mkDefault "errands";
      };
    })
    (lib.mkIf (cfg.pim == "kde") {
      programs.kde-pim = {
        enable = true;
        merkuro = true;
      };
      omarchy.defaultApps = {
        calendar = lib.mkDefault "merkuro-calendar";
        contacts = lib.mkDefault "merkuro-contact";
        reminders = lib.mkDefault "merkuro-calendar";
      };
    })
    (lib.mkIf (cfg.pim == "evolution") {
      programs.evolution = {
        enable = true;
      };
      services.gnome.evolution-data-server = {
        enable = true;
      };
    })
  ]);
}
