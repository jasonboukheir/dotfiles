{
  config,
  lib,
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
  # No boot splash: plymouth is SDR-only (legacy KMS, no HDR metadata),
  # so any splash forces a visible SDR→HDR DisplayPort retrain at the
  # gamescope handoff. A black VT until Steam's updater screen (styled
  # in session/steam-splash.nix, composited by gamescope in HDR) hides
  # that one retrain entirely — black resyncs to black.
  boot.kernelParams =
    [
      "quiet"
      # Keep the VT pitch black until gamescope's first frame.
      "vt.global_cursor_default=0"
    ]
    # Pin amdgpu (and with it fbcon) to each known display's
    # chain-wide mode — see thebeast.displays for the link-retrain story.
    ++ map (d: "video=${d.connector}:${toString d.width}x${toString d.height}@${toString d.refreshHz}")
    (lib.filter (d: d.connector != null) config.thebeast.displays);

  # asus_armoury loads on this board but its power-limit DMI table
  # covers ASUS laptops only (FA*, GA*, GU*, ...); on a B650E-I it just
  # logs "No matching power limits found" and exposes no useful
  # firmware-attributes. Fan/RGB on this board go through nct6775 and
  # asusctl/openrgb, not asus_armoury, so blacklisting loses nothing.
  # TODO: drop once the driver DMI-gates itself —
  # https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/drivers/platform/x86/asus-armoury.c
  boot.blacklistedKernelModules = ["asus_armoury"];

  # Initrd via systemd for the parallel device initialisation that
  # shaves ~1s off initrd time on this host.
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
