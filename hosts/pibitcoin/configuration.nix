{
  config,
  pkgs,
  ...
}: {
  networking = {
    firewall.enable = true;
    networkmanager.enable = true;
    hostName = "pibitcoin";
  };
  nix-bitcoin = {
    generateSecrets = true;
    operator = {
      enable = true;
      name = "jasonbk";
    };
  };
  services = {
    bitcoind = {
      enable = true;
      package = config.nix-bitcoin.pkgs.bitcoind-knots;
    };
    clightning.enable = true;
    mempool.enable = true;
    openssh = {
      enable = true;
      ports = [22];
      sesttings = {
        UseDns = true;
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };
    rtl = {
      enable = true;
      nodes.clightning.enable = true;
    };
  };
  users = {
    users.jasonbk = {
      isNormalUser = true;
      description = "Jason Bou Kheir";
      extraGroups = ["networkmanager" "wheel"];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEfZvYFG59uHZI+qyuVEyeL6A7GWanxbRbQkQG7q9SWy"
      ];
    };
  };
}
