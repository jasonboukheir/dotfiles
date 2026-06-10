# Wrapper plumbing for the lock stack: my.hyprlock/my.hypridle bake hyprlang
# configs behind --config, stylix colors land in hyprlock's (with explicit
# settings winning), and the wrapped hypridle actually parses its config and
# fires listeners under a headless wlroots compositor.
{
  pkgs,
  inputs ? null,
}: let
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

  explicitFontColor = "rgb(fedcba)";

  # Content is irrelevant — hyprlock only ever sees the path; the test
  # asserts the theme payload routes it into background.path.
  wallpaper = pkgs.writeText "test-wallpaper.png" "stub";
in
  pkgs.testers.nixosTest {
    name = "my-hypridle-hyprlock";

    nodes.machine = {
      nixpkgs.pkgs = pkgsWrapped;
      imports = [
        ../nixos.nix
        ../../stylix/users/options.nix
      ];

      my.hypridle = {
        enable = true;
        settings = {
          general.lock_cmd = "touch /tmp/lock-invoked";
          listener = [
            {
              timeout = 2;
              on-timeout = "touch /tmp/idle-fired-2s";
            }
            {
              timeout = 4;
              on-timeout = "touch /tmp/idle-fired-4s";
            }
          ];
        };
      };

      users.users.tester = {
        isNormalUser = true;
        stylix = {
          enable = true;
          inherit colors;
          image = wallpaper;
        };
        my.stylix.enable = true;
        my.hyprlock = {
          enable = true;
          settings = {
            general = {
              hide_cursor = true;
              grace = 7;
            };
            input-field.font_color = explicitFontColor;
          };
        };
      };

      environment.systemPackages = [pkgs.sway pkgs.dbus];
      environment.etc."sway-headless-test.conf".text = ''
        exec "hypridle --verbose > /tmp/hypridle.log 2>&1"
      '';
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      hyprlock = machine.succeed("su -l tester -c 'readlink -f $(command -v hyprlock)'").strip()
      hypridle = machine.succeed("readlink -f $(command -v hypridle)").strip()

      with subtest("both wrappers bake a --config flag"):
          machine.succeed(f"grep -aq -- '--config' {hyprlock}")
          machine.succeed(f"grep -aq -- '--config' {hypridle}")

      lock_conf = machine.succeed(
          f"grep -aoE '/nix/store/[a-z0-9]{{32}}-hyprlock.conf' {hyprlock} | head -n1"
      ).strip()
      idle_conf = machine.succeed(
          f"grep -aoE '/nix/store/[a-z0-9]{{32}}-hypridle.conf' {hypridle} | head -n1"
      ).strip()
      assert lock_conf and idle_conf, "baked config paths missing from the wrappers"

      with subtest("hyprlock config renders hyprlang sections with the explicit settings"):
          machine.succeed(f"grep -aq 'general {{' {lock_conf}")
          machine.succeed(f"grep -aq 'hide_cursor=true' {lock_conf}")
          machine.succeed(f"grep -aq 'grace=7' {lock_conf}")

      with subtest("stylix colors land in hyprlock's config, explicit settings beat them"):
          machine.succeed(f"grep -aq 'color=rgb(${colors.base00})' {lock_conf}")
          machine.succeed(f"grep -aq 'outer_color=rgb(${colors.base03})' {lock_conf}")
          machine.succeed(f"grep -aq 'font_color=${explicitFontColor}' {lock_conf}")
          machine.fail(f"grep -aq 'font_color=rgb(${colors.base05})' {lock_conf}")

      with subtest("the stylix wallpaper lands as the lock screen background"):
          machine.succeed(f"grep -aq 'path=${wallpaper}' {lock_conf}")

      with subtest("the wrapped hyprlock runs (config-parse level; no session/PAM headless)"):
          machine.succeed("su -l tester -c 'hyprlock --help'")

      with subtest("hypridle config renders repeated listener blocks"):
          listeners = machine.succeed(f"grep -ac 'listener {{' {idle_conf}").strip()
          assert listeners == "2", f"expected 2 listener blocks, got {listeners}"
          machine.succeed(f"grep -aq 'on-timeout=touch /tmp/idle-fired-2s' {idle_conf}")

      with subtest("wrapped hypridle parses the baked config (fails on the missing compositor, not the config)"):
          status, out = machine.execute("hypridle --verbose 2>&1")
          assert status != 0, "hypridle should fail without a wayland session"
          assert "Registered timeout rule for 2s" in out, f"baked config not parsed: {out!r}"
          assert "wayland" in out.lower(), f"expected the compositor connect error, got: {out!r}"

      with subtest("wrapped hypridle parses its config and fires listeners under headless sway"):
          machine.succeed("mkdir -p -m 700 /tmp/xdg")
          machine.execute(
              "XDG_RUNTIME_DIR=/tmp/xdg WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 "
              "WLR_RENDERER=pixman dbus-run-session -- "
              "sway -c /etc/sway-headless-test.conf >/tmp/sway.log 2>&1 &"
          )
          try:
              machine.wait_for_file("/tmp/idle-fired-2s", timeout=60)
              machine.wait_for_file("/tmp/idle-fired-4s", timeout=60)
          except Exception:
              print("sway.log:", machine.execute("tail -n 60 /tmp/sway.log")[1])
              print("hypridle.log:", machine.execute("cat /tmp/hypridle.log")[1])
              raise
    '';
  }
