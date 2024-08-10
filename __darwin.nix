{ pkgs, pkgs-zed-fix, ... }:
{
  imports = [
    ./darwin/homebrew.nix
    ./darwin/system.nix
  ];

  environment.systemPackages = [
    pkgs.kitty
    pkgs.neovim
    pkgs.nixd
    pkgs.nixfmt-rfc-style
    pkgs-zed-fix.zed-editor
  ];

  services.nix-daemon.enable = true;

  nix.settings.experimental-features = "nix-command flakes";

  programs.zsh.enable = true;

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  users.users.jasonbk = {
    home = "/Users/jasonbk";
    shell = pkgs.zsh;
  };

  security.pam.enableSudoTouchIdAuth = true;
}
