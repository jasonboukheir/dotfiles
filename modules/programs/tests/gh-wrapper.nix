{
  pkgs,
  inputs ? null,
}: let
  sentinel = "wrapper-editor-4b1d";
  pkgsWrapped = pkgs.extend (import ../../nixpkgs/overlays/mkWrapped.nix);
in
  pkgs.testers.nixosTest {
    name = "gh-wrapper";

    nodes.machine = {
      nixpkgs.pkgs = pkgsWrapped;
      imports = [../gh.nix];

      users.users.tester = {
        isNormalUser = true;
        programs.gh = {
          enable = true;
          settings.editor = sentinel;
        };
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
