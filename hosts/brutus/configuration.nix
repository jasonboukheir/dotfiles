# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').
{...}: {
  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
  ];

  nix.settings.max-jobs = 12;
  nix.settings.cores = 12;
  nix.settings.experimental-features = [
    "ca-derivations"
    "dynamic-derivations"
  ];
  nix.settings.extra-sandbox-paths = ["/var/cache/ccache"];
  systemd.tmpfiles.rules = [
    "d /var/cache/ccache 0770 root nixbld -"
  ];
  environment.etc."ccache.conf".text = ''
    max_size = 100G
  '';

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
