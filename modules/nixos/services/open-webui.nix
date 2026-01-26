{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.open-webui;
  credLib = import ../lib/credentials.nix {inherit lib;};
  creds = credLib.mkCredentialsHelpers {inherit cfg pkgs;};
in {
  options.services.open-webui = {
    credentials = credLib.mkCredentialsOption {
      description = "Credentials for Open-WebUI";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.open-webui = {
      serviceConfig = {
        LoadCredential = creds.loadList;
        ExecStart = lib.mkForce (pkgs.writeShellScript "open-webui-start" ''
          ${creds.exportScript}
          exec ${lib.getExe cfg.package} serve --host "${cfg.host}" --port ${toString cfg.port}
        '');
      };
    };
  };
}
