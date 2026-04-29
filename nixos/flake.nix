{
  description = "NixOS-only inputs partition.";

  inputs = {
    nixos.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixos-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixos";
    };

    home-manager-nixos-unstable = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixos-unstable";
    };

    stylix-nixos-unstable = {
      url = "github:nix-community/stylix/master";
      inputs.nixpkgs.follows = "nixos-unstable";
    };

    nvf-nixos-unstable = {
      url = "github:notashelf/nvf/main";
      inputs.nixpkgs.follows = "nixos-unstable";
    };

    jovian = {
      url = "github:Jovian-Experiments/Jovian-NixOS/development";
      inputs.nixpkgs.follows = "nixos-unstable";
    };

    # TODO: do NOT add inputs.nixpkgs.follows here. Upstream README warns that
    # overriding nixpkgs causes mismatch between cachy patches and kernel version.
    # https://github.com/xddxdd/nix-cachyos-kernel#how-to-use-kernels
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

    # TODO: nixarr's transitive flake graph (vpnconfinement, website-builder) is
    # historically brittle under follows overrides. Leave on its own pin until a
    # nixarr release documents follows compatibility.
    # https://github.com/rasmus-kirk/nixarr
    nixarr.url = "github:rasmus-kirk/nixarr";

    ezmtls = {
      url = "git+https://codeberg.org/jasonboukheir/ezmtls.git?ref=main";
      inputs.nixpkgs.follows = "nixos";
    };

    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixos";
    };
  };

  outputs = _: {};
}
