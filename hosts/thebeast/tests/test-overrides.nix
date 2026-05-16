{lib, ...}: {
  imports = [../state-version.nix];
  nixpkgs.hostPlatform = "x86_64-linux";

  # The real host puts /games on a dedicated ext4 partition declared in
  # hardware-configuration.nix, which the test path deliberately skips.
  # users.nix still creates /games/home/gamer via tmpfiles, so back the
  # mountpoint with tmpfs so activation doesn't fail.
  fileSystems."/games" = lib.mkForce {
    device = "tmpfs";
    fsType = "tmpfs";
    options = ["mode=0755"];
  };

  # The user-level home-manager config under hosts/thebeast/home-manager
  # dereferences osConfig.age.secrets, whose .age files are not pulled
  # into the test path. The specialisation flip is purely system-level,
  # so disabling per-user activation keeps the test focused and fast.
  home-manager.users = lib.mkForce {};

  # testers.nixosTest injects `nixpkgs.pkgs` externally and then refuses
  # any further `nixpkgs.config.*` definitions. modules/nixpkgs sets
  # allowUnfreePredicate, so we clear it here — the test's pkgs is
  # already created with `config.allowUnfree = true`.
  nixpkgs.config = lib.mkForce {};
}
