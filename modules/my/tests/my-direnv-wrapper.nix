# Per-user plumbing: my.direnv.{stdlib,settings} -> DIRENV_CONFIG dir -> wrapped direnv.
{
  pkgs,
  inputs ? null,
}: let
  sentinel = "my-direnv-wrapper-9c2e";
  pkgsWrapped = pkgs.extend (import ../../nixpkgs/overlays/mkWrapped.nix);
in
  pkgs.testers.nixosTest {
    name = "my-direnv-wrapper";

    nodes.machine = {
      nixpkgs.pkgs = pkgsWrapped;
      imports = [../nixos.nix];

      users.users.tester = {
        isNormalUser = true;
        my.direnv.enable = true;
        my.direnv.stdlib = "# ${sentinel}\n";
      };
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      direnv = machine.succeed(
          "su -l tester -c 'readlink -f $(command -v direnv)'"
      ).strip()

      with subtest("the wrapped direnv is in the user's environment and runs"):
          machine.succeed("su -l tester -c 'direnv version'")

      with subtest("the wrapper pins DIRENV_CONFIG to a baked config dir"):
          machine.succeed(f"grep -aq -- '--set DIRENV_CONFIG ' {direnv}")

      config_dir = machine.succeed(
          f"grep -aoE '/nix/store/[a-z0-9]{{32}}-my-direnv-config' {direnv} | head -n1"
      ).strip()
      assert config_dir, "no baked DIRENV_CONFIG dir found in the wrapper"

      with subtest("the baked direnvrc carries the user's stdlib sentinel"):
          machine.succeed(f"grep -aq '${sentinel}' {config_dir}/direnvrc")

      with subtest("nix-direnv is sourced by default"):
          machine.succeed(
              f"grep -aq 'share/nix-direnv/direnvrc' {config_dir}/direnvrc"
          )

      with subtest("direnv.toml is present in the baked config dir"):
          machine.succeed(f"test -e {config_dir}/direnv.toml")
    '';
  }
