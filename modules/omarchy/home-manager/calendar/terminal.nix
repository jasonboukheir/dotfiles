{
  config,
  lib,
  osConfig,
  ...
}: let
  cfg = osConfig.omarchy;
  enabled = cfg.enable && cfg.pim == "terminal";
  hasCalendars = config.accounts.calendar.accounts != {};
  hasContacts = config.accounts.contact.accounts != {};
in {
  config = lib.mkIf enabled (lib.mkMerge [
    (lib.mkIf hasCalendars {
      programs.khal.enable = true;
      programs.todoman.enable = true;
      vdirsyncer.enable = true;
    })
    (lib.mkIf hasContacts {
      programs.khard.enable = true;
      vdirsyncer.enable = true;
    })
  ]);
}
