{
  description = "Darwin-only inputs partition.";

  inputs = {
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-25.11-darwin";

    nix-darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    mac-app-util = {
      url = "github:hraban/mac-app-util";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    home-manager-darwin = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    stylix-darwin = {
      url = "github:nix-community/stylix/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    nvf-darwin = {
      url = "github:notashelf/nvf/v0.8";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    # TODO: switch back to zhaofengli-wip/nix-homebrew once PR #133 (brew 5.1.7) merges.
    # brew 5.1.1 has a Cask DSL regression where depends_on rejects positional args
    # (e.g. `depends_on :macos`), breaking nearly every cask. Fixed in brew 5.1.7.
    # https://github.com/zhaofengli/nix-homebrew/pull/133
    nix-homebrew.url = "github:Azd325/nix-homebrew/8eb1c803b4f9cd8cb4db4b04fe692dfb915d09ba";

    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
  };

  outputs = _: {};
}
