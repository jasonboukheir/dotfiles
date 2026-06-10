# The generated Hyprland config (issue #48): my.hyprland renders the omarchy
# hyprland.lua and injects it into the session entry's start-hyprland argv,
# the real Hyprland parser accepts it, stylix colors/cursor land in it, and
# my.hyprpaper carries the wallpaper. Covers both omarchy.uwsm.enable branches:
# the finalize hook + hidden bare session under uwsm, and the recreated
# dbus-update/hyprland-session.target world with the flag off.
{
  pkgs,
  inputs ? null,
}: let
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

  cursorSize = 17;

  # Content is irrelevant — hyprpaper only ever sees the path; the test
  # asserts the theme payload routes it into the baked wallpaper config.
  wallpaper = pkgs.writeText "test-wallpaper.png" "stub";

  node = {lib, ...}: {
    nixpkgs.pkgs = pkgs.extend (import ../../nixpkgs/overlays/mkWrapped.nix);
    imports = [
      inputs.home-manager-nixos-unstable.nixosModules.home-manager
      ../../omarchy
      ../nixos.nix
      # omarchy/packages.nix writes allowUnfreePackageNames, whose real home
      # (modules/nixpkgs/unfreepackages.nix) also sets nixpkgs.config — which
      # nixosTest refuses once nixpkgs.pkgs is injected. Stub the option
      # surface only; the test pkgs is already built with allowUnfree = true.
      {
        options.allowUnfreePackageNames = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
        };
      }
      # Just enough of the system stylix surface for the my.* system theme
      # (system-scope.nix) and the cursor env read (omarchy/hyprland/envs.nix);
      # the real stylix module is much heavier than this test needs.
      {
        options.stylix = lib.mkOption {
          type = lib.types.attrs;
          default = {};
        };
      }
    ];

    stylix = {
      enable = true;
      polarity = "dark";
      image = wallpaper;
      cursor.size = cursorSize;
    };
    lib.stylix.colors = colors;

    omarchy.enable = true;
    omarchy.monitor.mode = "1920x1080@60";
    programs._1password-gui.enable = true;

    users.users.tester = {
      isNormalUser = true;
      password = "tester";
    };
  };
in
  pkgs.testers.nixosTest {
    name = "my-hyprland-config";

    nodes = {
      machine = node;
      fallback = {
        imports = [node];
        omarchy.uwsm.enable = false;
      };
    };

    testScript = {nodes, ...}: ''
      import re

      # The session entry straight from each node's programs.hyprland.package
      # (greeters read it via displayManager sessionPackages; only uwsm also
      # links it into the system profile).
      SESSION_FILES = {
          "machine": "${nodes.machine.programs.hyprland.package}/share/wayland-sessions/hyprland.desktop",
          "fallback": "${nodes.fallback.programs.hyprland.package}/share/wayland-sessions/hyprland.desktop",
      }
      UWSM_TARGET = "${nodes.machine.omarchy.sessionTarget}"
      FALLBACK_TARGET = "${nodes.fallback.omarchy.sessionTarget}"

      machine.wait_for_unit("multi-user.target")
      fallback.wait_for_unit("multi-user.target")


      def lua_path(m):
          exec_line = m.succeed(f"grep '^Exec=' {SESSION_FILES[m.name]}").strip()
          match = re.search(r"start-hyprland -- --config (/nix/store/\S+-hyprland\.lua)$", exec_line)
          assert match, f"session Exec does not carry the config: {exec_line}"
          return match.group(1)


      with subtest("uwsm: bare session entry is hidden but execs start-hyprland with the config"):
          machine.succeed(f"grep -q '^NoDisplay=true$' {SESSION_FILES['machine']}")
          lua = lua_path(machine)

      def verify_config(m, lua):
          # --verify-config only parses, but Hyprland still insists on a
          # runtime dir for its log before getting there.
          m.succeed(
              "su - tester -c 'XDG_RUNTIME_DIR=$(mktemp -d) "
              f"Hyprland --verify-config --config {lua}'"
          )


      with subtest("uwsm: the real Hyprland parser accepts the generated config"):
          verify_config(machine, lua)

      with subtest("uwsm: config carries the finalize hook, not HM's dbus/target exec-once"):
          machine.succeed(
              f"grep -q 'uwsm finalize DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP' {lua}"
          )
          machine.fail(f"grep -q 'dbus-update-activation-environment' {lua}")
          machine.fail("test -e /etc/systemd/user/hyprland-session.target")

      with subtest("defaultApps locals, stylix colors and cursor land in the config"):
          machine.succeed(f"grep -q 'local terminal = \"ghostty\"' {lua}")
          machine.succeed(f"grep -q 'col.active_border.*rgb(${colors.base0D})' {lua}")
          machine.succeed(f"grep -q 'rgba(${colors.base00}99)' {lua}")
          machine.succeed(f'grep -q \'hl.env("XCURSOR_SIZE", "${toString cursorSize}")\' {lua}')
          machine.succeed(f"grep -q 'compose:caps' {lua}")
          machine.succeed(f"grep -q '1920x1080@60' {lua}")

      with subtest("hyprpaper wraps the stylix wallpaper and binds to the session target"):
          paper = machine.succeed("readlink -f /run/current-system/sw/bin/hyprpaper").strip()
          conf = machine.succeed(
              f"grep -aoE '/nix/store/[a-z0-9]{{32}}-hyprpaper.conf' {paper} | head -n1"
          ).strip()
          machine.succeed(f"grep -q 'path=${wallpaper}' {conf}")
          machine.succeed(f"grep -q 'splash=false' {conf}")
          unit = machine.succeed("cat /etc/systemd/user/hyprpaper.service")
          assert f"After={UWSM_TARGET}" in unit, f"hyprpaper misses After:\n{unit}"
          assert f"PartOf={UWSM_TARGET}" in unit, f"hyprpaper misses PartOf:\n{unit}"
          machine.succeed(
              f"test -L /etc/systemd/user/{UWSM_TARGET}.wants/hyprpaper.service"
          )

      with subtest("fallback: bare session entry stays visible, config still injected"):
          fallback.fail(f"grep -q '^NoDisplay=' {SESSION_FILES['fallback']}")
          fallback_lua = lua_path(fallback)

      with subtest("fallback: config recreates HM's dbus/target start hook"):
          fallback.succeed(f"grep -q 'dbus-update-activation-environment --systemd' {fallback_lua}")
          fallback.succeed(
              f"grep -q 'systemctl --user start hyprland-session.target' {fallback_lua}"
          )
          fallback.fail(f"grep -q 'uwsm finalize' {fallback_lua}")
          verify_config(fallback, fallback_lua)

      with subtest("fallback: hyprland-session.target exists and the units follow it"):
          target = fallback.succeed("cat /etc/systemd/user/hyprland-session.target")
          assert "BindsTo=graphical-session.target" in target, f"bad target:\n{target}"
          assert FALLBACK_TARGET == "hyprland-session.target", FALLBACK_TARGET
          fallback.succeed(
              f"test -L /etc/systemd/user/{FALLBACK_TARGET}.wants/hyprpaper.service"
          )
    '';
  }
