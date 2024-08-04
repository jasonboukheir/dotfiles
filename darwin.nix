{ pkgs, inputs, ... }:
{
  imports = [
    ./darwin/homebrew.nix
    ./darwin/system.nix
  ];

  environment.systemPackages = [
    pkgs.kitty
    pkgs.neovim
    pkgs.nixd
    pkgs.nixfmt
  ];

  services.nix-daemon.enable = true;

  nix.settings.experimental-features = "nix-command flakes";

  programs.zsh.enable = true;

  nixpkgs.hostPlatform = "aarch64-darwin";

  users.users.jasonbk = {
    home = "/Users/jasonbk";
    shell = pkgs.zsh;
  };

  security.pam.enableSudoTouchIdAuth = true;
}