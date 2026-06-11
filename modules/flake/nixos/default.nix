{
  partitions.nixos = {
    extraInputsFlake = ./.;
    module = {inputs, ...}: {
      flake.nixosConfigurations = {
        thebeast = inputs.nixos-unstable.lib.nixosSystem {
          # neovimConfiguration is the specialArg my.nvf builds neovim from;
          # pin the nvf input whose nixpkgs matches this host's channel.
          specialArgs = {
            inherit inputs;
            neovimConfiguration = inputs.nvf-nixos-unstable.lib.neovimConfiguration;
          };
          modules = [
            ../../../hosts/thebeast
            inputs.agenix.nixosModules.default
            inputs.determinate.nixosModules.default
            inputs.home-manager-nixos-unstable.nixosModules.home-manager
            inputs.stylix-nixos-unstable.nixosModules.stylix
            inputs.jovian.nixosModules.default
          ];
        };

        brutus = inputs.nixos.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
            neovimConfiguration = inputs.nvf-nixos.lib.neovimConfiguration;
            pkgs-unstable = import inputs.nixpkgs-unstable {
              localSystem = "x86_64-linux";
              config.allowUnfree = true;
            };
            terranix = inputs.terranix;
          };
          modules = [
            ../../../hosts/brutus
            inputs.agenix.nixosModules.default
            inputs.determinate.nixosModules.default
            inputs.home-manager-nixos.nixosModules.home-manager
            inputs.stylix-nixos.nixosModules.stylix
          ];
        };

        litus = inputs.nixos.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
            neovimConfiguration = inputs.nvf-nixos.lib.neovimConfiguration;
          };
          modules = [
            ../../../hosts/litus
            inputs.agenix.nixosModules.default
            inputs.determinate.nixosModules.default
            inputs.home-manager-nixos.nixosModules.home-manager
            inputs.stylix-nixos.nixosModules.stylix
          ];
        };
      };

      perSystem = {system, ...}:
      # nixosTest only runs on Linux; gate so darwin systems still evaluate.
        if system != "x86_64-linux"
        then {}
        else let
          pkgs = import inputs.nixos-unstable {
            inherit system;
            config.allowUnfree = true;
          };
          # brutus pins inputs.nixos (the stable channel), so its tests must
          # run on the same nixpkgs the host evaluates under — otherwise the
          # rendered homeserver.yaml / unit files in the test diverge from
          # what we'd actually ship.
          brutusPkgs = import inputs.nixos {
            inherit system;
            config.allowUnfree = true;
          };
        in {
          checks =
            (import ../../../modules/my/tests {inherit pkgs inputs;})
            // {
              thebeast-session = import ../../../hosts/thebeast/tests/session.nix {
                inherit pkgs inputs;
              };
              thebeast-dm-recovery = import ../../../hosts/thebeast/tests/dm-recovery.nix {
                inherit pkgs inputs;
              };
              thebeast-keyring = import ../../../hosts/thebeast/tests/keyring.nix {
                inherit pkgs inputs;
              };
              thebeast-steamos-autologin = import ../../../hosts/thebeast/tests/steamos-autologin.nix {
                inherit pkgs inputs;
              };
              thebeast-helium-extensions = import ../../../hosts/thebeast/tests/helium-extensions.nix {
                inherit pkgs inputs;
              };
              brutus-matrix = import ../../../hosts/brutus/tests/matrix.nix {
                pkgs = brutusPkgs;
                inherit inputs;
              };
              brutus-matrix-rtc = import ../../../hosts/brutus/tests/matrix-rtc.nix {
                pkgs = brutusPkgs;
                inherit inputs;
              };
              brutus-ntfy = import ../../../hosts/brutus/tests/ntfy.nix {
                pkgs = brutusPkgs;
                inherit inputs;
              };
              # litus pins inputs.nixos too (same channel as brutus), so run
              # its homelab-import guard under brutusPkgs (the stable nixpkgs).
              litus-homelab-import = import ../../../hosts/litus/tests/homelab-import.nix {
                pkgs = brutusPkgs;
              };
            };
        };
    };
  };

  partitionedAttrs.nixosConfigurations = "nixos";
  partitionedAttrs.checks = "nixos";
  partitionedAttrs.packages = "nixos";
  partitionedAttrs.apps = "nixos";
}
