{
  partitions.home = {
    extraInputsFlake = ./.;
    module = {inputs, ...}: let
      linuxPkgs = import inputs.nixos {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      linuxPkgsUnstable = import inputs.nixpkgs-unstable {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      commonModules = [
        ../../../modules/my/home-manager.nix
        {
          # neovimConfiguration is the specialArg my.nvf builds neovim from;
          # pin the nvf input whose nixpkgs matches these hosts' channel.
          _module.args.neovimConfiguration = inputs.nvf-nixos.lib.neovimConfiguration;
          my.nvf.enable = true;
        }
        inputs.stylix-nixos.homeModules.stylix
      ];
    in {
      flake.homeConfigurations."jasonbk@work-devserver" = inputs.home-manager-nixos.lib.homeManagerConfiguration {
        pkgs = linuxPkgs.extend (import ../../../modules/nixpkgs/overlays/zmx.nix);
        extraSpecialArgs = {
          inherit inputs;
          pkgs-unstable = linuxPkgsUnstable;
        };
        modules =
          [
            ../../../hosts/work-devserver
          ]
          ++ commonModules;
      };

      flake.homeConfigurations."jasonbk@jasonbk-fedora-MZ0319NF" = inputs.home-manager-nixos.lib.homeManagerConfiguration {
        pkgs = linuxPkgs.extend inputs.helium-flake.overlays.default;
        extraSpecialArgs = {
          inherit inputs;
          pkgs-unstable = linuxPkgsUnstable;
          nixgl = inputs.nixgl.packages.x86_64-linux;
        };
        modules =
          [
            ../../../hosts/jasonbk-fedora-MZ0319NF
          ]
          ++ commonModules;
      };
    };
  };

  partitionedAttrs.homeConfigurations = "home";
}
