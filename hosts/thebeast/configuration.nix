# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  lib,
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

  # `plymouth quit` tears the splash down the moment graphical.target is
  # reached, which on this host leaves a black framebuffer for the ~20s
  # while gamescope-session boots Steam Big Picture. --retain-splash
  # keeps the splash image painted on the framebuffer until gamescope
  # claims the DRM master and draws its first frame.
  systemd.services.plymouth-quit.serviceConfig.ExecStart = [
    ""
    "-${pkgs.plymouth}/bin/plymouth quit --retain-splash"
  ];

  # asus_armoury loads on this board but its power-limit DMI table
  # covers ASUS laptops only (FA*, GA*, GU*, ...); on a B650E-I it just
  # logs "No matching power limits found" and exposes no useful
  # firmware-attributes. Fan/RGB on this board go through nct6775 and
  # asusctl/openrgb, not asus_armoury, so blacklisting loses nothing.
  # TODO: drop once the driver DMI-gates itself —
  # https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/drivers/platform/x86/asus-armoury.c
  boot.blacklistedKernelModules = ["asus_armoury"];

  # systemd-boot defaults to a 5s menu timeout. Keep it short enough
  # that boot doesn't visibly stall, long enough that holding space
  # still gets us into the menu when we want to pick an older
  # generation as a recovery path.
  boot.loader.timeout = 2;

  # Initrd via systemd lets plymouth start before stage 2 instead of
  # flashing the console first; also gets us the parallel device
  # initialisation that shaves ~1s off initrd time on this host.
  boot.initrd.systemd.enable = true;

  # 30GiB of RAM with no swap gives the kernel no elasticity — brave
  # leaks pushed it to global_oom on 2026-05-21, taking down half the
  # user session. A disk swapfile is preferred over zram on this host
  # because zram steals RAM and CPU from games; at swappiness=10 the
  # kernel only spills under real pressure, so a game's working set
  # stays resident.
  swapDevices = [
    {
      device = "/var/swapfile";
      size = 32768;
    }
  ];
  boot.kernel.sysctl."vm.swappiness" = 10;

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    git
    neovim
  ];
}
