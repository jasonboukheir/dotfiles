{config, ...}: {
  boot.initrd.network = {
    enable = true;
    ssh = {
      enable = true;
      port = 2222;
      authorizedKeys = config.users.users.jasonbk.openssh.authorizedKeys.keys;
      hostKeys = [
        "/etc/secrets/initrd/ssh_host_ed25519_key"
      ];
    };
  };

  # Ensure networking is up in initrd so SSH can accept connections
  boot.initrd.availableKernelModules = ["r8169"]; # Realtek NIC, common on AMD boards
}
