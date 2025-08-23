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
          name = "jasonbk";
        };
        # Using system nixpkgs version
        useVersionLockedPkgs = true;
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
