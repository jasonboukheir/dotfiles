{...}: {
  networking.wireguard = {
    enable = true;
    # generatePrivateKeyFile cannot be used with useNetworkd...
    # so we need to use privateKey / privateKeyFile with sops
    # useNetworkd = true;
    interfaces.wg0 = {
      ips = ["10.100.0.1/24"];
      listenPort = 51820;
      privateKeyFile = "/var/lib/wireguard/wg0.key";
      generatePrivateKeyFile = true;

      peers = [
        # {
        #   name = "jasonbk iphone";
        #   # Feel free to give a meaningful name
        #   # Public key of the peer (not a file path).
        #   publicKey = "{client public key}";
        #   # List of IPs assigned to this peer within the tunnel subnet. Used to configure routing.
        #   allowedIPs = ["10.100.0.2/32"];
        # }
      ];
    };
  };
}
