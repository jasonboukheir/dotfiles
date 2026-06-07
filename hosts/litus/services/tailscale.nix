{config, ...}: {
  services.tailscale = {
    enable = true;
    openFirewall = true;
    extraUpFlags = ["--reset"];
    extraDaemonFlags = ["--encrypt-state=false"];
    authKeyFile = config.age.secrets."tailscale/authkey".path;
    authKeyParameters = {
      baseURL = "https://headscale.sunnycareboo.com";
      preauthorized = true;
    };
  };
  age.secrets."tailscale/authkey".file = ../secrets/tailscale/authkey.age;
}
