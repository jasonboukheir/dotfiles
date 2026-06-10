# my.* wrapped packages on home-macbook (per-user scope): fish/fd/rg/nvf and
# claude-code; git/jj/starship etc. still come from home-manager here.
# claude-code's package defaults to master's
# (the claude-code-master overlay) so a new model is reachable ahead of
# unstable; theme follows system stylix polarity. ~/.claude and CLAUDE.md stay
# writable runtime state (the seed-and-accept carve-out).
{
  config,
  lib,
  pkgs,
  ...
}: {
  users.users.jasonbk.my = {
    claude-code = {
      enable = true;
      settings = {
        autoMemoryEnabled = false;
        effortLevel = "high";
        permissions.defaultMode = "auto";
      };
    };

    fish = {
      enable = true;
      plugins = [pkgs.fishPlugins.plugin-git];
      interactiveShellInit = ''
        if command -q starship
          starship init fish | source
        end
        if command -q direnv
          direnv hook fish | source
        end
      '';
    };

    rg.enable = true;
    fd.enable = true;
  };

  # nvf stays at the system scope (a system-wide neovim): the per-user my.*
  # cascade recursiveMkDefaults nvf.settings, which corrupts the
  # deferredModule's imports list. See note in modules/my/system-scope.nix.
  my.nvf.enable = true;

  # rga isn't covered by my.rg (ripgrep only); keep it on jasonbk's profile.
  users.users.jasonbk.packages = [pkgs.ripgrep-all];

  # Make the my.fish wrapper jasonbk's login shell (modules/my/nix-darwin.nix
  # handles the programs.fish system integration + /etc/shells registration).
  users.users.jasonbk.shell = lib.mkForce config.users.users.jasonbk.my.fish.finalPackage;

  # Old per-user (home-manager) fish, superseded by my.fish above.
  home-manager.users.jasonbk.programs.fish.enable = lib.mkForce false;
}
