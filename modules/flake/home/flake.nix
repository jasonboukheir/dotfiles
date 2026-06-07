{
  description = "Home-manager Linux inputs partition (fedora, work-devserver).";

  inputs = {
    # Primary channel: stable 26.05. nixpkgs-unstable is the cherry-pick
    # channel for the handful of fast-moving CLIs (e.g. claude-code) exposed
    # via the pkgs-unstable escape hatch.
    nixos.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager-nixos = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixos";
    };

    stylix-nixos = {
      url = "github:nix-community/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixos";
    };

    nvf-nixos = {
      url = "github:notashelf/nvf/main";
      inputs.nixpkgs.follows = "nixos";
    };

    nixgl = {
      url = "github:nix-community/nixGL";
    };

    helium-flake = {
      url = "github:oxcl/nix-flake-helium-browser";
    };
  };

  outputs = _: {};
}
