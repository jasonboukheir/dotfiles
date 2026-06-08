{
  pkgs,
  inputs ? null,
}: let
  sentinel = "wrapper-loaded-7f3a";
  pkgsWrapped = pkgs.extend (import ../../nixpkgs/overlays/mkWrapped.nix);
in
  pkgs.testers.nixosTest {
    name = "jujutsu-wrapper";

    nodes.machine = {
      nixpkgs.pkgs = pkgsWrapped;
      imports = [../jujutsu.nix];

      users.users.tester = {
        isNormalUser = true;
        programs.jujutsu.enable = true;
        programs.jujutsu.settings.test-sentinel.value = sentinel;
      };
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      with subtest("the wrapped jj is in the user's environment and runs"):
          machine.succeed("su -l tester -c 'jj --version'")

      with subtest("the wrapper loads the user's baked JJ_CONFIG"):
          got = machine.succeed(
              "su -l tester -c 'jj config get test-sentinel.value'"
          ).strip()
          assert got == "${sentinel}", f"wrapper did not load baked config: {got!r}"

          got = machine.succeed(
              "su -l tester -c 'JJ_CONFIG=/dev/null jj config get test-sentinel.value'"
          ).strip()
          assert got == "${sentinel}", f"wrapper did not pin JJ_CONFIG: {got!r}"
    '';
  }
