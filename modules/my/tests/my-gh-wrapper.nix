# Asserts the per-user plumbing: users.users.<n>.my.gh.{enable,settings} ->
# GH_EDITOR baked into the wrapped gh, with GH_CONFIG_DIR deliberately left
# alone so `gh auth login` keeps owning hosts.yml. Sentinel-based, so it never
# asserts a real default. Part of the my.* foundation.
{
  pkgs,
  inputs ? null,
}: let
  sentinel = "my-gh-wrapper-editor-4b1d";
  pkgsWrapped = pkgs.extend (import ../../nixpkgs/overlays/mkWrapped.nix);
in
  pkgs.testers.nixosTest {
    name = "my-gh-wrapper";

    nodes.machine = {
      nixpkgs.pkgs = pkgsWrapped;
      imports = [../nixos.nix];

      users.users.tester = {
        isNormalUser = true;
        my.gh.enable = true;
        my.gh.settings.editor = sentinel;
      };
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      gh = machine.succeed("su -l tester -c 'readlink -f $(command -v gh)'").strip()

      with subtest("the wrapped gh is in the user's environment and runs"):
          machine.succeed("su -l tester -c 'gh --version'")

      with subtest("the wrapper pins settings.editor as GH_EDITOR"):
          machine.succeed(f"grep -aq 'GH_EDITOR' {gh}")
          machine.succeed(f"grep -aq '${sentinel}' {gh}")

      with subtest("the wrapper leaves GH_CONFIG_DIR alone so gh auth login keeps owning hosts.yml"):
          machine.fail(f"grep -aq 'GH_CONFIG_DIR' {gh}")
    '';
  }
