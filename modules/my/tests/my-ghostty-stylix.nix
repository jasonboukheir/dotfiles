# Asserts the per-user my.* stylix plumbing for ghostty: an arbitrary base16
# palette fed through users.users.<n>.stylix.colors lands on the right ghostty
# keys in the wrapper's baked --config-file, and `ghostty +validate-config`
# accepts the injected theme. The my.* port of programs/tests/ghostty-stylix.nix.
{
  pkgs,
  inputs ? null,
}: let
  pkgsWrapped = pkgs.extend (import ../../nixpkgs/overlays/mkWrapped.nix);

  # Arbitrary, mutually distinct base16 ids so each slot is greppable in the
  # rendered ghostty config. The values are meaningless — the test only proves
  # that whatever palette goes into stylix comes out the far side as ghostty
  # colors.
  colors = {
    base00 = "010203";
    base01 = "040506";
    base02 = "070809";
    base03 = "0a0b0c";
    base04 = "0d0e0f";
    base05 = "101112";
    base06 = "131415";
    base07 = "161718";
    base08 = "191a1b";
    base09 = "1c1d1e";
    base0A = "1f2021";
    base0B = "222324";
    base0C = "252627";
    base0D = "28292a";
    base0E = "2b2c2d";
    base0F = "2e2f30";
  };
in
  pkgs.testers.nixosTest {
    name = "my-ghostty-stylix";

    nodes.machine = {
      nixpkgs.pkgs = pkgsWrapped;
      imports = [
        ../nixos.nix
        # only the per-user stylix OPTIONS surface (colors/polarity/…); NOT
        # ../../stylix/users (whole dir), which pulls in the old hand-written
        # ghostty stylix target that the framework theming replaces.
        ../../stylix/users/options.nix
      ];

      users.users.tester = {
        isNormalUser = true;
        stylix = {
          enable = true;
          inherit colors;
        };
        my.stylix.enable = true;
        my.ghostty.enable = true;
      };
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      ghostty = machine.succeed("su -l tester -c 'readlink -f $(command -v ghostty)'").strip()

      with subtest("the wrapper injects a baked --config-file"):
          machine.succeed(f"grep -aq -- '--config-file=' {ghostty}")

      config = machine.succeed(
          f"grep -aoE '/nix/store/[a-z0-9]{{32}}-ghostty-config' {ghostty} | head -n1"
      ).strip()
      assert config, "no baked ghostty config path found in the wrapper"

      with subtest("stylix base16 ids land in the baked ghostty config"):
          machine.succeed(f"grep -aq 'background = #${colors.base00}' {config}")
          machine.succeed(f"grep -aq 'foreground = #${colors.base05}' {config}")
          machine.succeed(f"grep -aq 'selection-background = #${colors.base02}' {config}")
          # base16 → ansi: slot 1 = base08 (red), slot 4 = base0D (blue).
          machine.succeed(f"grep -aq 'palette = 1=#${colors.base08}' {config}")
          machine.succeed(f"grep -aq 'palette = 4=#${colors.base0D}' {config}")

      with subtest("the wrapped ghostty launches and accepts the injected theme"):
          # The wrapper prepends --config-file=<theme>, so validating with no
          # explicit config exercises the injected palette end-to-end; ghostty
          # exits non-zero on a malformed color/key.
          machine.succeed("su -l tester -c 'ghostty +validate-config'")
    '';
  }
