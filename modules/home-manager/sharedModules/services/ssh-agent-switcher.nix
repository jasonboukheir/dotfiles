{
  config,
  lib,
  pkgs-unstable,
  ...
}: {
  options.services.ssh-agent-switcher = {
    enable = lib.mkEnableOption "ssh-agent-switcher (stable SSH_AUTH_SOCK across reconnects and concurrent clients)";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs-unstable.ssh-agent-switcher;
      defaultText = lib.literalExpression "pkgs-unstable.ssh-agent-switcher";
      description = "ssh-agent-switcher package to use.";
    };
    socketPath = lib.mkOption {
      type = lib.types.str;
      default = "/tmp/ssh-agent.${config.home.username}";
      description = "Path to the stable socket the daemon listens on. Exported as SSH_AUTH_SOCK.";
    };
  };

  config = lib.mkIf config.services.ssh-agent-switcher.enable {
    home.packages = [config.services.ssh-agent-switcher.package];

    systemd.user.services.ssh-agent-switcher = {
      Unit = {
        Description = "SSH agent switcher (proxies SSH_AUTH_SOCK to the freshest live forwarded agent socket)";
      };
      Service = {
        ExecStart = "${lib.getExe config.services.ssh-agent-switcher.package} --socket-path=${config.services.ssh-agent-switcher.socketPath}";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = ["default.target"];
    };

    home.sessionVariables.SSH_AUTH_SOCK = config.services.ssh-agent-switcher.socketPath;
  };
}
