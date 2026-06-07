{
  description = "jasonbk's mono-flake (NixOS + nix-darwin + home-manager).";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
      imports = [
        inputs.flake-parts.flakeModules.partitions
        ./modules/flake
      ];
    };
}
