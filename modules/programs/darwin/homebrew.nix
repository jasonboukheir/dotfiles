{ inputs, ... }:
{
    nix-homebrew = {
        enable = true;
        autoMigrate = true;
        taps = {
            "homebrew/homebrew-core" = inputs.homebrew-core;
            "homebrew/homebrew-cask" = inputs.homebrew-cask;
        };
        mutableTaps = false;
    };
    homebrew = {
        enable = true;
        onActivation = {
            autoUpdate = true;
            cleanup = "zap";
            upgrade = true;
        };
    };
}
