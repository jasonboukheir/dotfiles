{
  pkgs,
  lib,
  ...
}: let
  proxyUrl = "http://[::1]:18082";
  sshKeyPath = "~/.ssh/id_ed25519";

  nixProxyWrapper = {
    bash = ''
      nix() {
        http_proxy=${proxyUrl} https_proxy=${proxyUrl} command nix "$@"
      }
    '';
    fish = ''
      function nix --wraps nix
        set -lx http_proxy ${proxyUrl}
        set -lx https_proxy ${proxyUrl}
        command nix $argv
      end
    '';
    nushell = ''
      def --wrapped nix [...rest] {
        $env.http_proxy = "${proxyUrl}"
        $env.https_proxy = "${proxyUrl}"
        ^nix ...$rest
      }
    '';
    zsh = ''
      nix() {
        http_proxy=${proxyUrl} https_proxy=${proxyUrl} command nix "$@"
      }
    '';
  };
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
      initExtra = nixProxyWrapper.bash;
    };

    fish.interactiveShellInit = lib.mkAfter nixProxyWrapper.fish;

    nushell.extraConfig = lib.mkAfter nixProxyWrapper.nushell;

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
        (lib.mkAfter (''
          setopt COMPLETE_IN_WORD
        '' + nixProxyWrapper.zsh))
      ];
    };
  };
}
