{
  lib,
  config,
  ...
}: {
  options = {
    networking.wg-quick.homelab.enable = lib.mkEnableOption "options that automatically setup defaults for connecting to homelab";
  };

  config = lib.mkIf config.networking.wg-quick.homelab.enable {
    networking.wg-quick.interfaces.wg0 = {
      # Client's VPN IP/subnet
      address = ["10.0.0.3/32"];

      # Path to private key (ensure it's readable by root/systemd)
      privateKeyFile = "/var/lib/wireguard/wg0.key";

      peers = [
        {
          publicKey = "VxT8i+moMUcUbLtmHcdyb5l/t6G+KI57k+2IoKhoMjU=";
          allowedIPs = ["10.0.0.0/24" "192.168.1.0/24"]; # VPN subnet + home LAN subnet for relay access
          endpoint = "50.47.248.79:51820";
          persistentKeepalive = 25; # Optional for NAT traversal
        }
      ];
    };
  };
}
