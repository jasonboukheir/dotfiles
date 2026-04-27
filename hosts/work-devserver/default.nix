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
    ../../modules/home-manager/sharedModules/programs/nvf/meta.nix
    ../../modules/home-manager/jasonbk/programs
    ../../modules/stylix
  ];

  stylix.enable = true;
  dconf.enable = false;

  home = {
    username = "jasonbk";
    homeDirectory = "/home/jasonbk";
    stateVersion = "25.11";
    packages = with pkgs; [
      fd
      ripgrep
      ripgrep-all
      (writeShellScriptBin "cws" (builtins.readFile ./cws.sh))
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
    nvf.meta.enable = true;

    ssh = {
      enable = true;
      matchBlocks."github.com" = {
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
