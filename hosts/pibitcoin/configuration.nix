{...}: {
  system = {
    stateVersion = "25.05";
  };
  networking = {
    firewall.enable = true;
    networkmanager.enable = true;
    hostName = "pibitcoin";
  };
  services = {
    openssh = {
      enable = true;
      ports = [22];
      sesttings = {
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
      extraGroups = ["networkmanager" "wheel"];
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
    "/boot/firmware" = {
      device = "/dev/disk/by-uuid/2178-694E";
      fsType = "vfat";
      options = ["noatime" "noauto" "x-systemd.automount" "x-systemd.idle-timeout=1min"];
    };
    "/" = {
      device = "/dev/disk/by-uuid/44444444-4444-4444-8888-888888888888";
      fsType = "ext4";
      options = ["noatime"];
    };
    "/var/lib/bitcoind" = {
      device = "/dev/disk/by-uuid/c26b49bd-a64b-4ad5-b762-b613730d7931";
      fsType = "ext4";
      options = ["noatime"];
    };
  };
}
