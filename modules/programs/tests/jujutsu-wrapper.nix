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

      programs.jujutsu.enable = true;
      programs.jujutsu.settings.test-sentinel.value = sentinel;
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      with subtest("the wrapped jj is on PATH and runs"):
          machine.succeed("jj --version")

      with subtest("the wrapper pins JJ_CONFIG to the baked config, not the user's"):
          got = machine.succeed("jj config get test-sentinel.value").strip()
          assert got == "${sentinel}", f"wrapper did not load baked config: {got!r}"

          got = machine.succeed(
              "JJ_CONFIG=/dev/null jj config get test-sentinel.value"
          ).strip()
          assert got == "${sentinel}", f"wrapper did not pin JJ_CONFIG: {got!r}"
    '';
  }
