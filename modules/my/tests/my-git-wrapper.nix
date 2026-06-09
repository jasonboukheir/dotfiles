# Asserts the per-user plumbing: users.users.<n>.my.git.{enable,settings,lfs} ->
# baked GIT_CONFIG_GLOBAL -> wrapped git, with git-lfs on the wrapper PATH and
# its filter baked in. Sentinel-based, so it never asserts a real default. Part
# of the my.* foundation.
{
  pkgs,
  inputs ? null,
}: let
  sentinel = "my-git-wrapper-9c2e";
  pkgsWrapped = pkgs.extend (import ../../nixpkgs/overlays/mkWrapped.nix);
in
  pkgs.testers.nixosTest {
    name = "my-git-wrapper";

    nodes.machine = {
      nixpkgs.pkgs = pkgsWrapped;
      imports = [../nixos.nix];

      users.users.tester = {
        isNormalUser = true;
        my.git.enable = true;
        my.git.lfs.enable = true;
        my.git.settings.wrapper.sentinel = sentinel;
      };
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      with subtest("the wrapped git is in the user's environment and runs"):
          machine.succeed("su -l tester -c 'git --version'")

      with subtest("the wrapper loads the user's baked GIT_CONFIG_GLOBAL"):
          got = machine.succeed(
              "su -l tester -c 'git config --global --get wrapper.sentinel'"
          ).strip()
          assert got == "${sentinel}", f"wrapper did not load baked config: {got!r}"

          got = machine.succeed(
              "su -l tester -c 'GIT_CONFIG_GLOBAL=/dev/null git config --global --get wrapper.sentinel'"
          ).strip()
          assert got == "${sentinel}", f"wrapper did not pin GIT_CONFIG_GLOBAL: {got!r}"

      with subtest("git-lfs rides on the wrapper PATH and its filter is baked in"):
          machine.succeed("su -l tester -c 'git lfs version'")
          required = machine.succeed(
              "su -l tester -c 'git config --global --get filter.lfs.required'"
          ).strip()
          assert required == "true", f"lfs filter not baked: {required!r}"
    '';
  }
