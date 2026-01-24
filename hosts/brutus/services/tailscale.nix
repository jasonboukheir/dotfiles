{config, ...}: {
  services.tailscale = {
    enable = true;
    openFirewall = true;
    authKeyFile = config.age.secrets."tailscale/authkey".path;
    authKeyParameters = {
      baseURL = "https://${config.sunnycareboo.services.headscale.domain}";
    };
  };
  age.secrets."tailscale/authkey".file = ../secrets/tailscale/authkey.age;
}
