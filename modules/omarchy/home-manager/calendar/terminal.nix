{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}: let
  cfg = osConfig.omarchy;
  enabled = cfg.enable && cfg.pim == "terminal";
  hasCalendars = config.accounts.calendar.accounts != {};
  hasContacts = config.accounts.contact.accounts != {};
  hasCalendarPath = config.accounts.calendar.basePath != null;
in {
  config = lib.mkIf enabled (lib.mkMerge [
    (lib.mkIf hasCalendars {
      programs.khal.enable = true;
      programs.todoman.enable = true;
      programs.todoman.glob = lib.mkIf hasCalendarPath "~/${config.accounts.calendar.basePath}";
      programs.pimsync.enable = true;
      services.pimsync.enable = true;
      # programs.todoman.package = with pkgs;
      #   todoman.overridePythonAttrs (oldAttrs: {
      #     propagatedBuildInputs = (oldAttrs.propagatedBuildInputs or []) ++ todoman.optional-dependencies.repl;
      #   });
    })
    (lib.mkIf hasContacts {
      programs.khard.enable = true;
      programs.pimsync.enable = true;
      services.pimsync.enable = true;
    })
  ]);
}
