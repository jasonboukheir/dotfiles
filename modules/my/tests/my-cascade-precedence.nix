# Cascade + PATH precedence: a per-user override deep-merges over system settings
# and the per-user wrapper shadows the system one in that user's PATH.
{
  pkgs,
  inputs ? null,
}: let
  pkgsWrapped = pkgs.extend (import ../../nixpkgs/overlays/mkWrapped.nix);
in
  pkgs.testers.nixosTest {
    name = "my-cascade-precedence";

    nodes.machine = {
      nixpkgs.pkgs = pkgsWrapped;
      imports = [../nixos.nix];

      my.jujutsu.enable = true;
      my.jujutsu.settings.sys-key.value = "SYS";
      my.jujutsu.settings.shared.value = "SYS";
      my.jujutsu.settings.user.name = "From System";

      users.users.tester = {
        isNormalUser = true;
        # Both knobs land on settings.user.* via settingsDefaults; the cascade
        # (user.name) and an explicit setting (user.email) must each beat them
        # without a priority tie.
        identity = {
          name = "From Identity";
          email = "ident@example.com";
        };
        my.jujutsu.enable = true;
        my.jujutsu.settings.user-key.value = "USER";
        my.jujutsu.settings.shared.value = "USER";
        my.jujutsu.settings.user.email = "explicit@example.com";
      };
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      with subtest("root uses the system wrapper (system settings only)"):
          assert machine.succeed("jj config get shared.value").strip() == "SYS"
          machine.fail("jj config get user-key.value")

      with subtest("the per-user wrapper shadows the system one in PATH"):
          # command -v unresolved: readlink -f lands in /nix/store, which never
          # says "per-user" no matter which profile the entry came from.
          where = machine.succeed("su -l tester -c 'command -v jj'").strip()
          assert where.startswith("/etc/profiles/per-user/tester/"), f"tester did not get the per-user wrapper: {where!r}"
          root_jj = machine.succeed("readlink -f $(command -v jj)").strip()
          tester_jj = machine.succeed("su -l tester -c 'readlink -f $(command -v jj)'").strip()
          assert tester_jj != root_jj, "tester resolved to the system wrapper"

      with subtest("per-user config deep-merges over system (cascade)"):
          assert machine.succeed("su -l tester -c 'jj config get sys-key.value'").strip() == "SYS"
          assert machine.succeed("su -l tester -c 'jj config get user-key.value'").strip() == "USER"
          assert machine.succeed("su -l tester -c 'jj config get shared.value'").strip() == "USER"

      with subtest("cascade and explicit settings outrank identity-derived defaults"):
          got = machine.succeed("su -l tester -c 'jj config get user.name'").strip()
          assert got == "From System", f"cascade did not beat identity default: {got!r}"
          got = machine.succeed("su -l tester -c 'jj config get user.email'").strip()
          assert got == "explicit@example.com", f"explicit setting did not beat identity default: {got!r}"
    '';
  }
