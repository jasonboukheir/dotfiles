# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').
{...}: {
  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
  ];

  # vllm-xpu-kernels' SYCL-TLA kernel TUs each peak ~5 GiB RSS in icpx
  # (~40 GiB on the heaviest head-dim/policy combos), and the
  # attn-kernels-xe-2 dyn-drv path produces ~600 single-TU drvs that the
  # outer Nix scheduler treats as independent. With max-jobs=auto on a
  # 24-core / 96 GiB box and no swap, several heavy template TUs overlap
  # and the kernel OOM-killer murders icpx mid-compile. Cap to 4
  # concurrent drvs and back it with zram so transient peaks don't
  # cascade into a system-wide OOM.
  nix.settings.max-jobs = 18;
  # ca-derivations: hash drv outputs by their content rather than by input
  # closure. Lets vllm-xpu-nix's per-TU dyn-drv .o files survive nixpkgs /
  # torch-xpu store-path bumps that don't actually change what icpx
  # compiles — same .o bytes hit the same store path, no recompile.
  # dynamic-derivations: not consumed by current code (vllm-xpu-attn-dyndrv
  # uses eval-time IFD for TU enumeration), enabled prophylactically so
  # the dyn-drv path can later move enumeration into the build phase per
  # the comment in nix/vllm-xpu-attn-dyndrv.nix:50.
  nix.settings.experimental-features = [
    "ca-derivations"
    "dynamic-derivations"
  ];
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
