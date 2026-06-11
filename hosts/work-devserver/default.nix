{
  pkgs,
  lib,
  ...
}: let
  proxyUrl = "http://[::1]:18082";
  noProxy = ".fbcdn.net,.facebook.com,.thefacebook.com,.tfbnw.net,.fb.com,.fburl.com,.facebook.net,.sb.fbsbx.com,localhost";
  sshKeyPath = "~/.ssh/id_ed25519";
in {
  imports = [
    ../../modules/home-manager/sharedModules/programs
    ../../modules/home-manager/jasonbk/programs
    ../../modules/stylix
  ];

  stylix.enable = true;
  dconf.enable = false;

  # claude is preinstalled on the devserver; my.* installs nothing and the
  # preinstalled binary owns its own ~/.claude settings.
  my.claude-code = {
    enable = true;
    package = null;
  };

  my.nvf.meta.enable = true;

  home = {
    username = "jasonbk";
    homeDirectory = "/home/jasonbk";
    stateVersion = "25.11";
    packages = with pkgs; [
      fd
      ripgrep
      ripgrep-all
    ];
    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      http_proxy = proxyUrl;
      https_proxy = proxyUrl;
      no_proxy = noProxy;
    };
  };

  programs = {
    ssh = {
      enable = true;
      # The deleted shared ssh module (issue #46) used to set this; keep the
      # rendered ~/.ssh/config to just the blocks below (the corp proxy only
      # reaches github/ghe, so the shared home-host blocks are not inlined).
      enableDefaultConfig = false;
      matchBlocks."github.com" = {
        proxyCommand = "ncat --proxy localhost:18082 --proxy-type http %h %p";
        identityFile = sshKeyPath;
        extraOptions.AddKeysToAgent = "yes";
      };
      matchBlocks."ghe.oculus-rep.com" = {
        proxyCommand = "ncat --proxy localhost:18082 --proxy-type http %h %p";
        identityFile = sshKeyPath;
        extraOptions.AddKeysToAgent = "yes";
      };
    };

    git.settings.user.signingKey = "${sshKeyPath}.pub";

    zmx.enable = true;

    bash = {
      enable = true;
      enableCompletion = false;
      historyFileSize = -1;
      historySize = 1000000;
      shellOptions = ["histappend"];
      bashrcExtra = ''
        source /etc/bashrc
        source /usr/facebook/ops/rc/master.bashrc
      '';
      initExtra = ''
        if [[ -z "''${BASH_EXECED_FISH:-}" && $- == *i* ]] && command -v fish >/dev/null; then
          export BASH_EXECED_FISH=1
          exec fish
        fi
      '';
    };

    zsh = {
      enable = true;
      enableCompletion = false;
      history = {
        size = 1000000;
        save = 1000000;
        append = true;
      };
      initContent = lib.mkMerge [
        (lib.mkBefore ''
          source /usr/facebook/ops/rc/master.zshrc
        '')
        (lib.mkAfter ''
          setopt COMPLETE_IN_WORD
        '')
      ];
    };
  };
}
