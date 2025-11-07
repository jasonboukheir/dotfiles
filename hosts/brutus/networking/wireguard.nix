{...}: {
  networking.wireguard = {
    enable = true;
    # generatePrivateKeyFile cannot be used with useNetworkd...
    # so we need to use privateKey / privateKeyFile with sops
    # useNetworkd = true;
    interfaces.wg-homeRelay = {
      ips = ["10.100.0.1/24"];
      listenPort = 51820;
      privateKeyFile = "/var/lib/wireguard/wg0.key";
      generatePrivateKeyFile = true;

      peers = [
        {
          name = "jasonbk-iphone";
          publicKey = "NTmAtjChVmjZH5FIOKMKVGj7TNzPchrSW3zO/+buYUQ=";
          allowedIPs = ["10.100.0.2/32"];
        }
        {
          name = "jasonbk-home-macbook";
          publicKey = "KIB87EA/FPfZYsAhiieI9SL7fvrvbmU6lvBcrS44GiU=";
          allowedIPs = ["10.100.0.3/32"];
        }
        {
          name = "izmabk-iphone";
          publicKey = "p8B75IsSMLq9wGhfHFwPAZQjAHXWIdJqV0pfLeADpgk=";
          allowedIPs = ["10.100.0.4/32"];
        }
      ];
    };
  };
}
