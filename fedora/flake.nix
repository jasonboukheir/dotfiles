{
  description = "Fedora-only inputs partition.";

  inputs = {
    nixgl = {
      url = "github:nix-community/nixGL";
    };

    helium-flake = {
      url = "github:oxcl/nix-flake-helium-browser";
    };
  };

  outputs = _: {};
}
