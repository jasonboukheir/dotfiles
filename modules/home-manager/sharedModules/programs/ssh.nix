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

  zmxSessionBlock = host: {
    hostname = host;
    forwardAgent = true;
    extraOptions =
      sshMultiplexing
      // {
        RemoteCommand = "zmx attach %n";
        RequestTTY = "yes";
      };
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
      matchBlocks = {
        "brutus" = {
          forwardAgent = true;
          extraOptions = sshMultiplexing;
        };
        "brutus.*" = zmxSessionBlock "brutus";
        "litus" = {
          forwardAgent = true;
          extraOptions = sshMultiplexing;
        };
        "litus.*" = zmxSessionBlock "litus";
        "pibitcoin" = {
          forwardAgent = true;
        };
        "${config._1passwordSshHostGlob}" = lib.mkIf (config.programs._1password.enable && config.programs._1password.agentPath != null) {
          identityAgent = config.programs._1password.agentPath;
        };
      };
    };
  };
}
