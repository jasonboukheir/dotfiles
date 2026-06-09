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

      users.users.tester = {
        isNormalUser = true;
        my.jujutsu.enable = true;
        my.jujutsu.settings.user-key.value = "USER";
        my.jujutsu.settings.shared.value = "USER";
      };
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      with subtest("root uses the system wrapper (system settings only)"):
          assert machine.succeed("jj config get shared.value").strip() == "SYS"
          machine.fail("jj config get user-key.value")

      with subtest("the per-user wrapper shadows the system one in PATH"):
          where = machine.succeed("su -l tester -c 'readlink -f $(command -v jj)'")
          assert "per-user" in where, f"tester did not get the per-user wrapper: {where!r}"

      with subtest("per-user config deep-merges over system (cascade)"):
          assert machine.succeed("su -l tester -c 'jj config get sys-key.value'").strip() == "SYS"
          assert machine.succeed("su -l tester -c 'jj config get user-key.value'").strip() == "USER"
          assert machine.succeed("su -l tester -c 'jj config get shared.value'").strip() == "USER"
    '';
  }
