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
        my.fish.plugins = [pkgs.fishPlugins.plugin-git];
      };
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      with subtest("the wrapped fish is in the user's environment and runs"):
          machine.succeed("su -l tester -c 'fish --version'")

      with subtest("fish sources the wrapper's interactiveShellInit (via profile vendor_conf.d)"):
          # \$ keeps the login shell (bash) from expanding the variable; only
          # fish has it, via the wrapper's vendor_conf.d.
          got = machine.succeed(
              "su -l tester -c 'fish -c \"echo \\$MY_FISH_SENTINEL\"'"
          ).strip()
          assert got == "${sentinel}", f"wrapper did not source baked conf.d: {got!r}"

      with subtest("a fisher-style plugin's abbreviations initialise (plugin-git gss)"):
          got = machine.succeed(
              "su -l tester -c 'fish -c \"abbr --query gss; and abbr --show gss\"'"
          ).strip()
          assert "git status" in got, f"plugin-git abbr gss not set up: {got!r}"
    '';
  }
