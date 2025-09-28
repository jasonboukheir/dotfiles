{...}: {
  system = {
    stateVersion = "25.05";
  };
  nix.settings.experimental-features = ["nix-command" "flakes"];
  networking = {
    firewall.enable = true;
    hostName = "pibitcoin";
  };
  services = {
    openssh = {
      enable = true;
      ports = [22];
      settings = {
        UseDns = true;
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };
  };
  users = {
    users.jasonbk = {
      isNormalUser = true;
      description = "Jason Bou Kheir";
      extraGroups = ["wheel"];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEfZvYFG59uHZI+qyuVEyeL6A7GWanxbRbQkQG7q9SWy"
      ];
    };
  };
  programs = {
    git.enable = true;
    extra-container.enable = true;
  };
  fileSystems = {
    "/var/lib/bitcoind" = {
      device = "/dev/disk/by-uuid/c26b49bd-a64b-4ad5-b762-b613730d7931";
      fsType = "ext4";
      options = ["noatime"];
    };
  };
}
