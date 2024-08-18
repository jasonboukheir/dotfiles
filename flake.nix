{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixpkgs-24.05-darwin";
    nixpkgs-zed-fix.url = "github:nixos/nixpkgs?ref=pull/329653/head";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
  };

  outputs =
    inputs@{
      self,
      nix-darwin,
      nixpkgs,
      nixpkgs-stable,
      nixpkgs-zed-fix,
      home-manager,
      nix-homebrew,
    }:
    let
      system = "aarch64-darwin";
      pkgs-stable = import nixpkgs-stable { inherit system; };
      pkgs-zed-fix = import nixpkgs-zed-fix { inherit system; };
      rev = self.rev or self.dirtyRev or null;
    in
    {
      # Build darwin flake using:
      # $ darwin-rebuild build --flake .#Jasons-MacBook-Pro
      darwinConfigurations."Jasons-MacBook-Pro" = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit rev;
          inherit pkgs-stable;
          inherit pkgs-zed-fix;
        };
        modules = [
          ./darwin.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.jasonbk = import ./home.nix;
          }
          nix-homebrew.darwinModules.nix-homebrew
          {
            nix-homebrew = {
              enable = true;
              user = "jasonbk";
            };
          }
        ];
      };
      nix.nixPath = [ "nixpkgs=${nixpkgs}" ];

      # Expose the package set, including overlays, for convenience.
      darwinPackages = self.darwinConfigurations."Jasons-MacBook-Pro".pkgs;
    };
}
