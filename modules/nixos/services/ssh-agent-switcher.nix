# System-layer replacement for the old home-manager ssh-agent-switcher module
# (issue #46): a per-user systemd user service plus a PAM-level SSH_AUTH_SOCK
# export, so every login session (shell or sshd) sees the stable socket instead
# of the per-connection one sshd hands out.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.ssh-agent-switcher;
in {
  # Upstream's module starts the daemon from environment.loginShellInit, which
  # only bash/zsh login shells source — the my.fish wrapper's preinit
  # (modules/my/fish-system.nix) sources setEnvironment alone, so on hosts
  # whose login shell is that wrapper the daemon would never start. A
  # supervised systemd user service + sessionVariables export (both reach
  # every session type) replaces it under the same option names.
  disabledModules = ["services/security/ssh-agent-switcher.nix"];

  options.services.ssh-agent-switcher = {
    enable = lib.mkEnableOption "ssh-agent-switcher (stable SSH_AUTH_SOCK across reconnects and concurrent clients)";

    package = lib.mkPackageOption pkgs "ssh-agent-switcher" {};

    socketPath = lib.mkOption {
      type = lib.types.str;
      default = "/tmp/ssh-agent.%u";
      description = ''
        Stable socket the per-user daemon listens on, using systemd unit
        specifiers (%u is the user name). Exported as SSH_AUTH_SOCK with %u
        rendered as $USER, which both PAM and the shell setEnvironment
        expand per user.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [cfg.package];

    systemd.user.services.ssh-agent-switcher = {
      description = "SSH agent switcher (proxies SSH_AUTH_SOCK to the freshest live forwarded agent socket)";
      wantedBy = ["default.target"];
      serviceConfig = {
        ExecStartPre = "${lib.getExe' pkgs.coreutils "rm"} -f ${cfg.socketPath}";
        ExecStart = "${lib.getExe cfg.package} --socket-path=${cfg.socketPath}";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    environment.sessionVariables.SSH_AUTH_SOCK =
      lib.replaceStrings ["%u"] ["$USER"] cfg.socketPath;
  };
}
