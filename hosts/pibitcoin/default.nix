{...}: {
  imports = [
    ../../modules
    ./home-manager
    ./programs
    ./users.nix
  ];
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
