{
  inputs = {
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs = {
    nixpkgs-unstable,
    agenix,
    ...
  }: let
    forAllSystems = nixpkgs-unstable.lib.genAttrs ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
  in {
    devShells = forAllSystems (system: let
      pkgs = import nixpkgs-unstable {inherit system;};
    in {
      default = pkgs.mkShell {
        buildInputs = [
          pkgs.nixd
          pkgs.alejandra
          agenix.packages.${system}.default
        ];
      };
    });
  };
}
