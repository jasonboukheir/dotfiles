{
  inputs,
  config,
  ...
}: {
  nix-homebrew = {
    user = "jasonbk";
    enable = true;
    taps = {
      "homebrew/homebrew-bundle" = inputs.homebrew-bundle;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      "homebrew/homebrew-core" = inputs.homebrew-core;
    };
    mutableTaps = false;
  };
  homebrew = {
    enable = true;
    taps = builtins.attrNames config.nix-homebrew.taps;
    onActivation = {
      cleanup = "zap";
      upgrade = true;
    };
  };
}
