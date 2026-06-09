# Asserts the per-user plumbing: users.users.<n>.my.nushell.{enable,extraConfig,
# vivid} -> baked config.nu (--config) + generated env.nu (--env-config) ->
# wrapped nu, with vivid LS_COLORS, carapace on PATH, and the baked
# `starship init nu` hook. Sentinel-based, so it never asserts a real default.
# Part of the my.* foundation.
{
  pkgs,
  inputs ? null,
}: let
  sentinel = "my-nushell-wrapper-3e8b";
  pkgsWrapped = pkgs.extend (import ../../nixpkgs/overlays/mkWrapped.nix);
in
  pkgs.testers.nixosTest {
    name = "my-nushell-wrapper";

    nodes.machine = {
      nixpkgs.pkgs = pkgsWrapped;
      imports = [../nixos.nix];

      users.users.tester = {
        isNormalUser = true;
        my.nushell = {
          enable = true;
          extraConfig = ''
            def __sentinel [] { "${sentinel}" }
            def __lscolors_len [] { $env.LS_COLORS | str length }
          '';
          vivid.enable = true;
        };
      };
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      nu = machine.succeed("su -l tester -c 'readlink -f $(command -v nu)'").strip()

      with subtest("the wrapped nu is in the user's environment and runs"):
          machine.succeed("su -l tester -c 'nu --commands \"version\"'")

      with subtest("the wrapper pins the baked config.nu via --config"):
          got = machine.succeed(
              "su -l tester -c 'nu --commands \"__sentinel\"'"
          ).strip()
          assert got == "${sentinel}", f"wrapper did not load baked config.nu: {got!r}"

      with subtest("the baked env.nu sets vivid LS_COLORS and carapace is on PATH"):
          # `$env.LS_COLORS` lives inside the baked config def, never on the
          # `su -c` command line, so the login shell can't eat the `$`.
          colors = machine.succeed(
              "su -l tester -c 'nu --commands \"__lscolors_len\"'"
          ).strip()
          assert int(colors) > 0, f"vivid LS_COLORS not set in env.nu: {colors!r}"
          machine.succeed("su -l tester -c 'nu --commands \"carapace --version\"'")

      with subtest("the env.nu carries the starship init hook"):
          env = machine.succeed(
              f"grep -aoE '/nix/store/[a-z0-9]{{32}}-env.nu' {nu} | head -n1"
          ).strip()
          assert env, "no baked env.nu path found in the wrapper"
          machine.succeed(f"grep -aq 'starship init nu' {env}")
    '';
  }
