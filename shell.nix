{
  pkgs,
  agenix,
}:
with pkgs;
  mkShell {
    buildInputs = [
      nixd
      alejandra
      agenix.packages."${pkgs.system}".default
    ];
  }
