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

  # Plymouth hides the kernel log scroll between the bootloader handoff
  # and the greeter coming up. quiet+splash are required to actually
  # suppress the journal text the kernel would otherwise paint over it.
  boot.plymouth.enable = true;
  boot.kernelParams = ["quiet" "splash"];

  # systemd-boot defaults to a 5s menu timeout. Keep it short enough
  # that boot doesn't visibly stall, long enough that holding space
  # still gets us into the menu when we want to pick an older
  # generation as a recovery path.
  boot.loader.timeout = 2;

  # Initrd via systemd lets plymouth start before stage 2 instead of
  # flashing the console first; also gets us the parallel device
  # initialisation that shaves ~1s off initrd time on this host.
  boot.initrd.systemd.enable = true;

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    git
    neovim
  ];
}
