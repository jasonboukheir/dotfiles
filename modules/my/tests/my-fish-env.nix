# #69 system wiring: my.fish writes /etc/fish/nixos-env-preinit.fish itself (no
# native programs.fish), so a fish login shell gets the nix environment on PATH.
# Also exercises the multi-user path (system scope + a per-user wrapper in one
# machine) to prove the users.users scan in ../fish-system.nix does not recurse.
{
  pkgs,
  inputs ? null,
}: let
  pkgsWrapped = pkgs.extend (import ../../nixpkgs/overlays/mkWrapped.nix);
in
  pkgs.testers.nixosTest {
    name = "my-fish-env";

    nodes.machine = {
      nixpkgs.pkgs = pkgsWrapped;
      imports = [../nixos.nix];

      my.fish.enable = true;

      users.users.tester = {
        isNormalUser = true;
        my.fish.enable = true;
      };
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      with subtest("the preinit file the baked __fish_build_paths.fish sources exists"):
          machine.succeed("test -f /etc/fish/nixos-env-preinit.fish")

      with subtest("the enabled wrapper(s) are registered as login shells"):
          machine.succeed("grep -q '/bin/fish' /etc/shells")

      with subtest("a login fish seeds the nix PATH from a stripped environment"):
          # env -i clears PATH/NIX_PROFILES entirely; only the preinit (fenv
          # source of setEnvironment) can put the system profile back on PATH.
          # This is the darwin failure mode (bare PATH), masked by PAM for a
          # normal login. Assert on PATH itself so the test does not depend on
          # any particular tool being installed in the VM.
          got = machine.succeed(
              "env -i /run/current-system/sw/bin/fish -l -c 'echo $PATH'"
          ).strip()
          assert "/run/current-system/sw/bin" in got, \
              f"login fish did not get the nix environment on PATH: {got!r}"
    '';
  }
