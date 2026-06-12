{
  lib,
  pkgs,
  ...
}: {
  imports = [../configuration.nix];
  nixpkgs.hostPlatform = "x86_64-linux";

  # The host profile pins eno1, which no qemu NIC matches — its
  # wait-device-timeout would stall NetworkManager-wait-online (and the
  # display-manager ordering behind it) for the full timeout in every
  # test. eth0 is the test driver's user-net NIC; SLIRP answers DHCP
  # immediately, so wait-online gates on a real activation instead.
  thebeast.network.wiredInterface = lib.mkDefault "eth0";

  # The real host puts /games on a dedicated ext4 partition declared in
  # hardware-configuration.nix, which the test path deliberately skips.
  # users.nix still creates /games/home/gamer via tmpfiles, so back the
  # mountpoint with tmpfs so activation doesn't fail.
  fileSystems."/games" = lib.mkForce {
    device = "tmpfs";
    fsType = "tmpfs";
    options = ["mode=0755"];
  };

  # testers.nixosTest injects `nixpkgs.pkgs` externally and then refuses
  # any further `nixpkgs.config.*` definitions. modules/nixpkgs sets
  # allowUnfreePredicate, so we clear it here — the test's pkgs is
  # already created with `config.allowUnfree = true`.
  nixpkgs.config = lib.mkForce {};

  # users.nix dereferences config.age.secrets."users/jasonbk/password".path
  # for hashedPasswordFile. The test pulls in the agenix module so the
  # option exists, but the corresponding .age file isn't in the test
  # path (hosts/thebeast/secrets/secrets.nix is host-only). Declare a
  # stub secret pointing at an in-tree placeholder so activation can
  # resolve the path without actually decrypting anything.
  age.secrets."users/jasonbk/password" = {
    file = pkgs.writeText "jasonbk-password.age" "stub";
    path = "/etc/test-jasonbk-password";
  };
  age.secrets."users/root/password" = {
    file = pkgs.writeText "root-password.age" "stub";
    path = "/etc/test-root-password";
  };
}
