{
  config,
  lib,
  ...
}: let
  sshMultiplexing = {
    ControlMaster = "auto";
    ControlPath = "~/.ssh/control-%C";
    ControlPersist = "10m";
  };

  zmxSessionBlock = host:
    sshMultiplexing
    // {
      HostName = host;
      ForwardAgent = true;
      RemoteCommand = "sh -c 'zmx attach \"\${1#*.}\"' _ %n";
      RequestTTY = "yes";
    };
in {
  options = {
    _1passwordSshHostGlob = lib.mkOption {
      type = lib.types.str;
      default = "*";
      description = ''
        When using 1password as ssh agent, what glob pattern should be used as host match?
      '';
      example = lib.literalExpression "* !*.od*";
    };
  };
  config = lib.mkIf config.programs.ssh.enable {
    programs.ssh = {
      enableDefaultConfig = false;
      settings = {
        "brutus" = sshMultiplexing // {ForwardAgent = true;};
        "brutus.*" = zmxSessionBlock "brutus";
        "litus" = sshMultiplexing // {ForwardAgent = true;};
        "litus.*" = zmxSessionBlock "litus";
        "pibitcoin" = {
          ForwardAgent = true;
        };
        "${config._1passwordSshHostGlob}" = lib.mkIf (config.programs._1password.enable && config.programs._1password.agentPath != null) {
          IdentityAgent = config.programs._1password.agentPath;
        };
      };
    };
  };
}
