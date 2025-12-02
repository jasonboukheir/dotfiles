{
  config,
  lib,
  ...
}: let
  cfg = config.services.tailscale;
in {
  services.tailscale = {
    enable = true;
    openFirewall = true;
    authKeyFile = config.age.secrets."tailscale/authkey".path;
    authKeyParameters = {
      baseURL = "https://headscale.sunnycareboo.com";
      preauthorized = true;
    };
  };
  age.secrets."tailscale/authkey".file = ../secrets/tailscale/authkey.age;
}
