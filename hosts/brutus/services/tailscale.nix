{config, ...}: {
  services.tailscale = {
    enable = true;
    openFirewall = true;
    extraUpFlags = [
      "--login-server=https://${config.homelab.services.headscale.domain}"
      "--reset"
    ];
    extraDaemonFlags = ["--encrypt-state=false"];
    authKeyFile = config.age.secrets."tailscale/authkey".path;
  };
  age.secrets."tailscale/authkey".file = ../secrets/tailscale/authkey.age;
}
