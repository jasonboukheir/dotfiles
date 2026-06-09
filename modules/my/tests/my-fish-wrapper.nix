# Per-user plumbing: my.fish.interactiveShellInit -> baked conf.d -> wrapped fish.
{
  pkgs,
  inputs ? null,
}: let
  sentinel = "my-fish-wrapper-9c4e";
  pkgsWrapped = pkgs.extend (import ../../nixpkgs/overlays/mkWrapped.nix);
in
  pkgs.testers.nixosTest {
    name = "my-fish-wrapper";

    nodes.machine = {
      nixpkgs.pkgs = pkgsWrapped;
      imports = [../nixos.nix];

      users.users.tester = {
        isNormalUser = true;
        my.fish.enable = true;
        my.fish.interactiveShellInit = "set -gx MY_FISH_SENTINEL ${sentinel}";
      };
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      with subtest("the wrapped fish is in the user's environment and runs"):
          machine.succeed("su -l tester -c 'fish --version'")

      with subtest("the wrapper sources the user's baked conf.d (interactiveShellInit)"):
          got = machine.succeed(
              "su -l tester -c 'fish -c \"echo $MY_FISH_SENTINEL\"'"
          ).strip()
          assert got == "${sentinel}", f"wrapper did not source baked conf.d: {got!r}"
    '';
  }
