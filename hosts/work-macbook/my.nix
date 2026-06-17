# Dogfoods the my.* wrapped-package surface (per-user scope) on work-macbook.
# This host is home-manager-free (#55), so the old per-user HM program paths are
# simply gone; the only legacy path still explicitly disabled is the system git
# module (see programs.git.enable below). The fish system integration (nix env
# on PATH, /etc/shells) is wired automatically by modules/my/nix-darwin.nix when
# my.fish is enabled; only the login-shell choice lives here.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Resolved 1Password ssh-signing values the old _1password home-manager module
  # injected into programs.git/jujutsu; my.* has no such auto-injection.
  signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBGEXFObvyFbGAgq3Lob/+2SPBXfFBmguTmJDLcJlysJ";
  opSshSign = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";

  # Chef owns /etc/ssh/ssh_config and does not Include ssh_config.d, so the
  # github IdentityAgent block in system/ssh.nix never loads. Scope the
  # 1Password agent to git via core.sshCommand instead — corp ssh keeps the
  # Chef-managed agent. The path contains a space ("Group Containers"), so it
  # must stay quoted through three parsers: git's gitIni reader, the `sh -c`
  # git wraps core.sshCommand in, and ssh's own `-o` config tokenizer. The
  # single quotes survive the shell so ssh sees literal double quotes around the
  # value (and ssh tilde-expands IdentityAgent).
  opSshCommand = "ssh -o 'IdentityAgent=\"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"'";

  metaNvimPath = "/Users/jasonbk/fbsource/fbcode/editor_support/nvim";

  # FB android toolchain (fb4a); replaces the old setup_fb4a.sh fish shellInit.
  androidSdk = "/opt/android_sdk";
  androidNdk = "/opt/android_ndk";
  fbAndroidInit = ''
    set -gx ANDROID_SDK ${androidSdk}
    set -gx ANDROID_NDK_REPOSITORY ${androidNdk}
    set -gx ANDROID_HOME $ANDROID_SDK
    set -gx ANDROID_SDK_ROOT $ANDROID_SDK
    fish_add_path --append --global \
      $ANDROID_SDK/emulator $ANDROID_SDK/tools $ANDROID_SDK/tools/bin \
      $ANDROID_SDK/platform-tools
  '';

  fishWrapper = config.users.users.jasonbk.my.fish.finalPackage;
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
        core.sshCommand = opSshCommand;
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

    rg.enable = true;
    fd.enable = true;
    rga.enable = true;

    # Installs the direnv wrapper; the fish hook below is guarded on
    # `command -q direnv`, so without this the hook silently no-ops.
    direnv.enable = true;

    # ghostty-bin (the upstream .app) wrapped for PATH launches; Dock launches
    # pick the same baked config up via the Application Support symlink seeded
    # by modules/darwin/programs/ghostty.nix.
    ghostty.enable = true;

    # claude is preinstalled on the work machine; my.* installs nothing and the
    # preinstalled binary owns its own ~/.claude (the seed-and-accept carve-out).
    claude-code = {
      enable = true;
      package = null;
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
        ${fbAndroidInit}
      '';
    };
  };

  # nvf stays at the system scope (a system-wide neovim, as it is today): the
  # per-user my.* cascade recursiveMkDefaults nvf.settings, which corrupts the
  # deferredModule's imports list. See note in modules/my/system-scope.nix.
  my.nvf = {
    enable = true;
    meta = {
      enable = true;
      pluginPath = metaNvimPath;
    };
  };

  # Make the my.fish wrapper jasonbk's login shell (modules/my/nix-darwin.nix
  # handles the programs.fish system integration + /etc/shells registration).
  users.users.jasonbk.shell = lib.mkForce fishWrapper;

  # Old system program path (modules/darwin/programs/git.nix), superseded by
  # my.git above.
  programs.git.enable = false;
}
