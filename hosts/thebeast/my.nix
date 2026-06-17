# Dogfoods the my.* wrapped-package surface on thebeast. Per-user tools live on
# jasonbk's profile; fish and nvf build at the system scope (fish becomes the
# system fish wrapper, nvf a system-wide neovim). Each tool below replaces an
# old per-user-wrapper / home-manager / native-system module, disabled in the
# same place so each tool resolves to exactly one package.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # ssh signing wiring stays flattened here by design (issue #46): my.* defs
  # are pure, so per-host 1Password values bake straight into the wrappers.
  # op-ssh-sign ships with the 1Password GUI (linux-only path); the agent and
  # client config live at the system layer (system/ssh.nix).
  signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBGEXFObvyFbGAgq3Lob/+2SPBXfFBmguTmJDLcJlysJ";
  opSshSign = lib.getExe' pkgs._1password-gui "op-ssh-sign";
in {
  # editor pins the system nvf-built neovim by store path rather than relying on
  # `nvim` off PATH; the my.{git,gh,jujutsu} wiring reads it (and the shared
  # identity from modules/jasonbk-identity.nix) for each tool's user/editor fields.
  users.users.jasonbk.editor = config.my.nvf.finalPackage;

  users.users.jasonbk.my = {
    git = {
      enable = true;
      ignores = [".DS_Store"];
      settings = {
        user.signingKey = signingKey;
        init.defaultBranch = "main";
        gpg.format = "ssh";
        commit.gpgsign = true;
        "gpg \"ssh\"".program = opSshSign;
      };
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
        signing = {
          behavior = "own";
          backend = "ssh";
          key = signingKey;
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
    # by my.fish.interactiveShellInit below (the native programs.direnv that used
    # to emit it is disabled here).
    direnv.enable = true;

    rg.enable = true;
    fd.enable = true;
    rga.enable = true;

    weechat = {
      enable = true;
      irc.enable = true;
    };

    # Linux ghostty is exec-launched, so the baked --config-file wrapper reaches
    # it (unlike a darwin GUI .app); my.ghostty's stylix target re-bakes the
    # base16 palette HM-stylix used to emit.
    ghostty.enable = true;

    # package defaults to master's claude-code (the claude-code-master overlay);
    # theme comes from system stylix polarity. ~/.claude + CLAUDE.md stay
    # writable runtime state (the seed-and-accept carve-out, out of my.*).
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
}
