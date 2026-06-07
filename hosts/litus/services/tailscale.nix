{config, ...}: {
  services.tailscale = {
    enable = true;
    openFirewall = true;
    extraDaemonFlags = ["--encrypt-state=false"];
    authKeyFile = config.age.secrets."tailscale/authkey".path;
    authKeyParameters = {
      baseURL = "https://${config.homelab.services.headscale.domain}";
    };
  };
  age.secrets."tailscale/authkey".file = ../secrets/tailscale/authkey.age;
}
