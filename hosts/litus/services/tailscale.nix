{config, ...}: {
  services.tailscale = {
    enable = true;
    openFirewall = true;
    extraUpFlags = ["--reset"];
    extraDaemonFlags = ["--encrypt-state=false"];
  };
}
