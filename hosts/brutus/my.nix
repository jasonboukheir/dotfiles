# my.* wrapped packages on brutus. Headless server: no ghostty, and no
# 1Password ssh-signing (op-ssh-sign needs the GUI).
# claude-code's package defaults to master's (the claude-code-master overlay) so
# a new model is reachable ahead of unstable; theme follows system stylix
# polarity. ~/.claude and CLAUDE.md stay writable runtime state (the
# seed-and-accept carve-out).
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Consumed by the my.{git,gh,jujutsu} wiring (modules/my/) to default each
  # tool's user.{name,email} and editor fields. editor pins the system nvf-built
  # neovim by store path rather than relying on `nvim` off PATH.
  users.users.jasonbk = {
    identity = {
      name = "Jason Elie Bou Kheir";
      email = "5115126+jasonboukheir@users.noreply.github.com";
    };
    editor = config.my.nvf.finalPackage;
  };

  users.users.jasonbk.my = {
    git = {
      enable = true;
      ignores = [".DS_Store"];
      settings.init.defaultBranch = "main";
    };

    jujutsu = {
      enable = true;
      settings = {
        ui = {
          pager = "less -FRX";
          default-command = "log";
        };
        git = {
          colocate = true;
          private-commits = "description(glob:'wip:*')";
        };
      };
    };

    starship = {
      enable = true;
      settings = {
        add_newline = false;
        character = {
          success_symbol = "[›](bold green)";
          error_symbol = "[›](bold red)";
        };
      };
    };

    gh.enable = true;

    nushell = {
      enable = true;
      # vivid's `ansi` theme follows the terminal's ANSI palette (themed from
      # base16 by stylix) rather than a pinned scheme.
      vivid.enable = true;
    };

    # nix-direnv is baked into the wrapper's direnvrc; the fish hook is emitted
    # by my.fish.interactiveShellInit below.
    direnv.enable = true;

    rg.enable = true;
    fd.enable = true;
    rga.enable = true;

    claude-code = {
      enable = true;
      settings = {
        autoMemoryEnabled = false;
        effortLevel = "high";
        permissions.defaultMode = "auto";
      };
    };
  };

  # fish + nvf build at the system scope. fish becomes the system fish wrapper
  # (modules/my/nixos.nix wires programs.fish's /etc env-preinit + /etc/shells);
  # nvf stays system-wide because the per-user my.* cascade can't carry nvf's
  # deferredModule settings — see modules/my/system-scope.nix.
  my = {
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

    nvf.enable = true;

    zmx.enable = true;
  };

  # Make the my.fish wrapper jasonbk's login shell, replacing the plain pkgs.fish
  # from modules/nixos/users.nix (which would otherwise also land in
  # environment.systemPackages and collide with the wrapper's bin/fish). The
  # programs.fish system integration + /etc/shells registration is wired by
  # modules/my/nixos.nix.
  users.users.jasonbk.shell = lib.mkForce config.my.fish.finalPackage;

  # Old home-manager program paths, superseded by my.* above.
  home-manager.users.jasonbk.programs = {
    git.enable = lib.mkForce false;
    jujutsu.enable = lib.mkForce false;
    starship.enable = lib.mkForce false;
    gh.enable = lib.mkForce false;
    nushell.enable = lib.mkForce false;
    fish.enable = lib.mkForce false;
    direnv.enable = lib.mkForce false;
  };
}
