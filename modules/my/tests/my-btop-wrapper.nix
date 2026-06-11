# Per-user monitor plumbing: my.btop.settings + stylix theme -> baked
# --config/--themes-dir, verified end-to-end by running btop on a pty and
# watching the themed truecolor escapes come out.
{
  pkgs,
  inputs ? null,
}: let
  cpuNameSentinel = "my-btop-7e31";
  pkgsWrapped = pkgs.extend (import ../../nixpkgs/overlays/mkWrapped.nix);

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

  # base05 (main_fg) as the SGR truecolor foreground btop must emit once the
  # stylix theme is applied; the Default theme's main_fg is #cc.
  mainFgEscape = "38;2;16;17;18";
in
  pkgs.testers.nixosTest {
    name = "my-btop-wrapper";

    nodes.machine = {
      nixpkgs.pkgs = pkgsWrapped;
      imports = [
        ../nixos.nix
        ../../stylix/users/options.nix
      ];

      environment.systemPackages = [pkgs.tmux];

      users.users.tester = {
        isNormalUser = true;
        stylix = {
          enable = true;
          inherit colors;
          opacity.terminal = 0.97;
        };
        my.stylix.enable = true;
        my.btop = {
          enable = true;
          settings = {
            truecolor = true;
            vim_keys = true;
            update_ms = 2000;
            custom_cpu_name = cpuNameSentinel;
          };
        };
      };
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      btop = machine.succeed("su -l tester -c 'readlink -f $(command -v btop)'").strip()

      with subtest("the wrapper bakes --config and --themes-dir"):
          machine.succeed(f"grep -aq -- '--config' {btop}")
          machine.succeed(f"grep -aq -- '--themes-dir' {btop}")

      conf = machine.succeed(
          f"grep -aoE '/nix/store/[a-z0-9]{{32}}-btop.conf' {btop} | head -n1"
      ).strip()
      themes = machine.succeed(
          f"grep -aoE '/nix/store/[a-z0-9]{{32}}-btop-themes' {btop} | head -n1"
      ).strip()
      assert conf and themes, "no baked btop config/themes paths found in the wrapper"

      with subtest("settings render in btop's key = value format"):
          machine.succeed(f"grep -axq 'vim_keys = True' {conf}")
          machine.succeed(f"grep -axq 'update_ms = 2000' {conf}")
          machine.succeed(f"grep -axq 'custom_cpu_name = \"${cpuNameSentinel}\"' {conf}")

      with subtest("stylix injects color_theme and theme_background"):
          machine.succeed(f"grep -axq 'color_theme = \"stylix\"' {conf}")
          machine.succeed(f"grep -axq 'theme_background = False' {conf}")
          machine.succeed(f"grep -q 'theme\\[main_bg\\]=\"#${colors.base00}\"' {themes}/stylix.theme")

      with subtest("btop runs and paints with the baked stylix theme"):
          machine.succeed("su -l tester -c 'tmux new-session -d -x 120 -y 30 btop'")
          machine.wait_until_succeeds(
              "su -l tester -c 'tmux capture-pane -p -e' | grep -q '${mainFgEscape}'",
              timeout=60,
          )

      with subtest("the baked config parsed without errors"):
          machine.succeed("su -l tester -c 'tmux kill-server' || true")
          btop_log = machine.succeed("cat ~tester/.config/btop/btop.log || true")
          assert "ERROR:" not in btop_log, f"btop logged errors: {btop_log!r}"
    '';
  }
