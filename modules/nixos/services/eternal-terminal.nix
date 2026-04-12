{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.services.eternal-terminal.enable {
    networking.firewall.allowedTCPPorts = [config.services.eternal-terminal.port];
  };
}
