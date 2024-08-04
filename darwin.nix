{ pkgs, inputs, ... }:
{
  imports = [
    ./darwin/homebrew.nix
    ./darwin/system.nix
  ];

  environment.systemPackages = [
    pkgs.iina
    pkgs.kitty
    pkgs.neovim
    pkgs.nushell
  ];
  environment.shells = [
    pkgs.nushell
  ];

  services.nix-daemon.enable = true;

  nix.settings.experimental-features = "nix-command flakes";

  programs.zsh.enable = true;

  nixpkgs.hostPlatform = "aarch64-darwin";

  users.users.jasonbk = {
    home = "/Users/jasonbk";
    shell = pkgs.nushell;
  };

  security.pam.enableSudoTouchIdAuth = true;
}