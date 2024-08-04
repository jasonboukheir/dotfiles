{ ... }:
{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
    };
    casks = [
      "1password"
      "1password-cli"
      "godot"
      "rectangle"
    ];
    masApps = {
      "1Password for Safari" = 1569813296;
    };
  };
}
