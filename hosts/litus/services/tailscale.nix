{config, ...}: {
  services.tailscale = {
    enable = true;
    openFirewall = true;
    extraUpFlags = [
      # TODO: Get this hardcoded url out to use homelab module
      "--login-server=https://headscale.sunnycareboo.com"
      "--reset"
    ];
    # TODO: this is to prevent issues with TPM chips
    extraDaemonFlags = ["--encrypt-state=false"];
    authKeyFile = config.age.secrets."tailscale/authkey".path;
  };
  age.secrets."tailscale/authkey".file = ../secrets/tailscale/authkey.age;
}
