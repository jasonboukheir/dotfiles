{inputs, ...}: {
  boot.enableContainers = true;
  containers.bitcoin = {
    autoStart = true;
    privateNetwork = false;
    bindMounts = {
      "/var/lib/bitcoin" = { hostPath = "/mnt/bitcoin-data"; isReadOnly = false; };
    };

    config = { config, ... }: {
      imports = [
        inputs.nix-bitcoin.nixosModules.default
        (inputs.nix-bitcoin + "/modules/presets/secure-node.nix")
      ];
      nix-bitcoin = {
        generateSecrets = true;
        operator = {
          enable = true;
          name = "main";
        };
        # Using system nixpkgs version
        # useVersionLockedPkgs = true;
      };
      users.users.main = {
        isNormalUser = true;
        # FIXME: This is unsafe. Use `hashedpassword` or `passwordFile` instead in a real
        # deployment: https://search.nixos.org/options?show=users.users.%3Cname%3E.hashedPassword
        password = "a";
      };

      services.bitcoind = {
        enable = true;
        package = config.nix-bitcoin.pkgs.bitcoind-knots;
      };
      services.clightning.enable = true;

      system.stateVersion = "25.05";  # Match your NixOS version
    };
  };
}
