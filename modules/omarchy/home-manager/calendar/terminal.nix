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

  # Create a Python environment with fixed click-repl
  pythonWithWorkingClickRepl = pkgs.python3.override {
    packageOverrides = self: super: {
      # Downgrade click to < 8.2.0 for click-repl compatibility
      click = super.click.overridePythonAttrs (old: rec {
        version = "8.1.8";
        src = pkgs.fetchPypi {
          pname = "click";
          inherit version;
          hash = "sha256-7VPJ2JkNg8Kifermjk7jN0c/YzDAQKMdQiXJV00WCWo=";
        };
      });
    };
  };

  # Build todoman package with our fixed Python and repl dependencies
  todomanWithFixedPython = pkgs.todoman.override {
    python3 = pythonWithWorkingClickRepl;
  };

  # Now override the Python package inside to add repl dependencies
  todomanWithRepl = todomanWithFixedPython.overridePythonAttrs (oldAttrs: {
    propagatedBuildInputs =
      (oldAttrs.propagatedBuildInputs or [])
      ++ (oldAttrs.optional-dependencies.repl or []);
  });
in {
  config = lib.mkIf enabled (lib.mkMerge [
    (lib.mkIf hasCalendars {
      programs.khal.enable = true;
      programs.todoman.enable = true;
      programs.todoman.package = todomanWithRepl;
      programs.pimsync.enable = true;
      services.pimsync.enable = true;
    })
    (lib.mkIf hasContacts {
      programs.khard.enable = true;
      programs.pimsync.enable = true;
      services.pimsync.enable = true;
    })
  ]);
}
