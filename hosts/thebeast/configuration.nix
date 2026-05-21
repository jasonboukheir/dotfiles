# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  pkgs,
  inputs,
  ...
}: {
  imports = [./state-version.nix];

  # CachyOS kernel overlay and binary cache
  nixpkgs.overlays = [inputs.nix-cachyos-kernel.overlays.pinned];
  nix.settings = {
    substituters = ["https://attic.xuyh0120.win/lantian"];
    trusted-public-keys = ["lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="];
  };

  # CachyOS kernel with BORE scheduler
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    git
    neovim
  ];
}
