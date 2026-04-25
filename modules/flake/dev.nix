{
  partitions.dev = {
    extraInputsFlake = ../../dev;
    module = {inputs, ...}: {
      systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
      perSystem = {system, ...}: let
        pkgs = import inputs.nixpkgs-unstable {inherit system;};
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.nixd
            pkgs.alejandra
            inputs.agenix.packages.${system}.default
          ];
        };
      };
    };
  };

  partitionedAttrs.devShells = "dev";
}
