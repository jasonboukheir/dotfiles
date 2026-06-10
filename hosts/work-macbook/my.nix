# Dogfoods the my.* wrapped-package surface (per-user scope) on work-macbook.
# Each tool below replaces an old home-manager/system module path, which is
# disabled in the same place so jasonbk ends up with exactly one of each. The
# fish system integration (nix env on PATH, /etc/shells) is wired automatically
# by modules/my/nix-darwin.nix when my.fish is enabled; only the login-shell
# choice lives here.
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

    rg.enable = true;

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

  # rga isn't covered by my.rg (ripgrep only); keep it on jasonbk's profile.
  users.users.jasonbk.packages = [pkgs.ripgrep-all];

  # Make the my.fish wrapper jasonbk's login shell (modules/my/nix-darwin.nix
  # handles the programs.fish system integration + /etc/shells registration).
  users.users.jasonbk.shell = lib.mkForce fishWrapper;

  # Old per-user (home-manager) program paths, superseded by my.* above.
  home-manager.users.jasonbk.programs = {
    git.enable = lib.mkForce false;
    jujutsu.enable = lib.mkForce false;
    starship.enable = lib.mkForce false;
    fish.enable = lib.mkForce false;
  };

  # Old system program paths, superseded by my.* above.
  programs.git.enable = false;
  programs.nvf.enable = false;
  programs.ripgrep.enable = false;
}
