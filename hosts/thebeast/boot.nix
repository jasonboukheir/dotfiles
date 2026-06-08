{
  pkgs,
  inputs,
  ...
}: {
  nixpkgs.overlays = [
    inputs.nix-cachyos-kernel.overlays.pinned
  ];
  nix.settings = {
    substituters = ["https://attic.xuyh0120.win/lantian"];
    trusted-public-keys = ["lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="];
  };

  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;
  boot.plymouth.enable = true;
  boot.kernelParams = ["quiet" "splash"];

  # asus_armoury loads on this board but its power-limit DMI table
  # covers ASUS laptops only (FA*, GA*, GU*, ...); on a B650E-I it just
  # logs "No matching power limits found" and exposes no useful
  # firmware-attributes. Fan/RGB on this board go through nct6775 and
  # asusctl/openrgb, not asus_armoury, so blacklisting loses nothing.
  # TODO: drop once the driver DMI-gates itself —
  # https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/drivers/platform/x86/asus-armoury.c
  boot.blacklistedKernelModules = ["asus_armoury"];

  # Initrd via systemd lets plymouth start before stage 2 instead of
  # flashing the console first; also gets us the parallel device
  # initialisation that shaves ~1s off initrd time on this host.
  boot.initrd.systemd.enable = true;

  system.etc.overlay.enable = true;
  systemd.tmpfiles.rules = ["d /var/ssh 0755 root root -"];
  services.openssh.hostKeys = [
    {
      type = "ed25519";
      path = "/var/ssh/ssh_host_ed25519_key";
    }
    {
      type = "rsa";
      bits = 4096;
      path = "/var/ssh/ssh_host_rsa_key";
    }
  ];

  swapDevices = [
    {
      device = "/var/swapfile";
      size = 32768;
    }
  ];
  boot.kernel.sysctl."vm.swappiness" = 10;
}
