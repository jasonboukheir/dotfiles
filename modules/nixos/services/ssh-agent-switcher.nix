# System-layer replacement for the old home-manager ssh-agent-switcher module
# (issue #46): a per-user *system* service plus a PAM-level SSH_AUTH_SOCK export,
# so the stable socket outlives any single login session and every shell/zmx
# session — new or long-parked — sees the freshest forwarded agent.
#
# A system service (not systemd.user) keeps the daemon machine-lifetime: it
# starts at boot, survives logout and `nixos-rebuild switch`, and needs no
# user-manager lingering. User services are pulled by default.target, which is
# activated once when the user manager first starts — a new login never
# re-evaluates its wants, so a daemon that died (e.g. across a switch) stays
# dead. The system service sidesteps that lifecycle entirely. It still runs as
# the target user (User=%i) so it can read that user's forwarded agent sockets
# (~/.ssh/agent, /tmp) and own the listening socket with the right permissions.
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
  # (modules/my/fish-system.nix) sources setEnvironment alone, so on hosts whose
  # login shell is that wrapper the daemon would never start. A supervised
  # service + sessionVariables export (both reach every session type) replaces
  # it under the same option namespace.
  disabledModules = ["services/security/ssh-agent-switcher.nix"];

  options.services.ssh-agent-switcher = {
    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["jasonbk"];
      description = ''
        Users to run an ssh-agent-switcher instance for. Each gets a
        machine-lifetime system service (an instance of the
        `ssh-agent-switcher@` template) running as that user, listening on a
        stable per-user socket that is exported as `SSH_AUTH_SOCK`. The empty
        list disables the module.
      '';
    };

    package = lib.mkPackageOption pkgs "ssh-agent-switcher" {};

    socketPath = lib.mkOption {
      type = lib.types.str;
      default = "/tmp/ssh-agent.%i";
      description = ''
        Stable socket each per-user daemon listens on, using systemd unit
        specifiers (%i is the instance name = the user). Exported as
        `SSH_AUTH_SOCK` with %i rendered as `$USER`, which both PAM and the
        shell setEnvironment expand per user. Kept under /tmp (not
        /run/user/%U) deliberately, so it does not depend on the user's logind
        runtime dir.
      '';
    };
  };

  config = lib.mkIf (cfg.users != []) {
    environment.systemPackages = [cfg.package];

    systemd.services."ssh-agent-switcher@" = {
      description = "SSH agent switcher for %i (proxies SSH_AUTH_SOCK to the freshest live forwarded agent socket)";
      serviceConfig = {
        User = "%i";
        ExecStartPre = "${lib.getExe' pkgs.coreutils "rm"} -f ${cfg.socketPath}";
        ExecStart = "${lib.getExe cfg.package} --socket-path=${cfg.socketPath}";
        # always (not on-failure): the proxy must self-heal even on a clean
        # exit, so a stray SIGTERM never leaves the host without an agent socket.
        Restart = "always";
        RestartSec = 5;
      };
    };

    # Instantiate (and boot-start) one daemon per configured user. A template
    # unit cannot carry its own wantedBy, so the instances are wanted by the
    # boot target instead.
    systemd.targets.multi-user.wants =
      map (u: "ssh-agent-switcher@${u}.service") cfg.users;

    environment.sessionVariables.SSH_AUTH_SOCK =
      lib.replaceStrings ["%i"] ["$USER"] cfg.socketPath;
  };
}
