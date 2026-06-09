# Asserts the per-user plumbing: users.users.<n>.my.starship.{enable,settings} ->
# baked STARSHIP_CONFIG -> wrapped starship. Sentinel-based, so it never asserts
# a real default. Part of the my.* foundation.
{
  pkgs,
  inputs ? null,
}: let
  sentinel = "my-wrapper-prompt-6d4a";
  pkgsWrapped = pkgs.extend (import ../../nixpkgs/overlays/mkWrapped.nix);
in
  pkgs.testers.nixosTest {
    name = "my-starship-wrapper";

    nodes.machine = {
      nixpkgs.pkgs = pkgsWrapped;
      imports = [../nixos.nix];

      users.users.tester = {
        isNormalUser = true;
        my.starship.enable = true;
        my.starship.settings.aws.symbol = sentinel;
      };
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      starship = machine.succeed("su -l tester -c 'readlink -f $(command -v starship)'").strip()

      with subtest("the wrapped starship is in the user's environment and runs"):
          machine.succeed("su -l tester -c 'starship --version'")

      with subtest("the wrapper pins the user's baked config via STARSHIP_CONFIG"):
          machine.succeed(f"grep -aq 'STARSHIP_CONFIG' {starship}")
          config = machine.succeed(
              f"grep -aoE '/nix/store/[a-z0-9]{{32}}-starship.toml' {starship} | head -n1"
          ).strip()
          assert config, "no baked starship.toml path found in the wrapper"
          machine.succeed(f"grep -aq '${sentinel}' {config}")

      with subtest("the wrapped starship emits a shell init the wrappers can source"):
          machine.succeed("su -l tester -c 'starship init fish'")
    '';
  }
