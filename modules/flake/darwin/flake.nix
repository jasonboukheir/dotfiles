{
  description = "Darwin-only inputs partition.";

  inputs = {
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";

    # Cherry-pick channel shared by every system partition: the darwin fish
    # overlay (modules/nixpkgs/overlays/fish.nix) and the home-manager
    # pkgs-unstable escape hatch both resolve against it.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    # Don't override nixpkgs: upstream pins an older nixpkgs whose SBCL (2.4.10)
    # is known to build its Lisp deps. Newer SBCL (26.05's 2.6.4) changed the
    # macro-char array internals and crashes the pinned named-readtables with
    # "Bug in readtable iterators or concurrent access?" while building
    # fare-quasiquote. TODO: drop pin once cl-nix-lite bumps named-readtables
    # past melisgl/named-readtables@6eea566 (github:hraban/cl-nix-lite/issues).
    mac-app-util.url = "github:hraban/mac-app-util";

    home-manager-darwin = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    stylix-darwin = {
      url = "github:nix-community/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    nvf-darwin = {
      url = "github:notashelf/nvf/main";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

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
