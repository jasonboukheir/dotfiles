{
  config,
  lib,
  ...
}: let
  cfg = config.services.step-ca;
  oidcCfg = config.services.pocket-id.ensureClients.step-ca;
in {
  services.step-ca = {
    enable = true;
    address = "127.0.0.1";
    port = 8444;
    openFirewall = true;
    intermediatePasswordFile = config.age.secrets."step-ca/intermediatePassword".path;
    settings = lib.mkMerge [
      (builtins.fromJSON (builtins.readFile ./ca.json))
      {
        authority.provisioners = [
          {
            type = "OIDC";
            name = "Pocket ID";
            clientID = oidcCfg.settings.id;
            clientSecret = "";
            configurationEndpoint = "https://${config.sunnycareboo.services.id.domain}/.well-known/openid-configuration";
            admins = ["jasonbk@sunnycareboo.com"];
            domains = ["sunnycareboo.com"];
            scopes = ["openid" "email"];
          }
        ];
      }
    ];
  };

  age.secrets = lib.mkIf cfg.enable {
    "step-ca/intermediatePassword".file = ../../secrets/step-ca/intermediatePassword.age;
  };

  services.pocket-id = lib.mkIf cfg.enable {
    ensureClients.step-ca = {
      dependentServices = [config.systemd.services.step-ca.name];
      logo = ./step-ca.svg;
      settings = {
        name = "Step CA";
        isPublic = true;
        callbackURLs = [
          "http://127.0.0.1:*"
        ];
      };
    };
  };
}
