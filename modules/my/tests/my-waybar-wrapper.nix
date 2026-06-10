# my.waybar.settings/style -> baked -c/-s -> waybar renders the sentinel
# module under a headless wlroots compositor (sway).
{
  pkgs,
  inputs ? null,
}: let
  sentinel = "my-waybar-wrapper-7e1f";
  pkgsWrapped = pkgs.extend (import ../../nixpkgs/overlays/mkWrapped.nix);
in
  pkgs.testers.nixosTest {
    name = "my-waybar-wrapper";

    nodes.machine = {
      nixpkgs.pkgs = pkgsWrapped;
      imports = [../nixos.nix];

      fonts.packages = [pkgs.dejavu_fonts];
      environment.systemPackages = [pkgs.sway];

      users.users.tester = {
        isNormalUser = true;
        my.waybar = {
          enable = true;
          settings = [
            {
              layer = "top";
              position = "top";
              height = 26;
              modules-center = ["custom/sentinel"];
              "custom/sentinel" = {
                exec = "echo ${sentinel} | tee /tmp/waybar-sentinel";
                interval = "once";
                format = "{}";
              };
            }
          ];
          style = ''
            * {
              font-family: monospace;
            }
          '';
        };
      };
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      machine.succeed("loginctl enable-linger tester")
      machine.wait_until_succeeds("test -d /run/user/$(id -u tester)")

      with subtest("a headless wlroots compositor comes up for tester"):
          machine.succeed(
              "su -l tester -c 'env XDG_RUNTIME_DIR=/run/user/$(id -u)"
              " WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1"
              " sway -c /dev/null >/tmp/sway.log 2>&1 &'"
          )
          display = machine.wait_until_succeeds(
              "ls /run/user/$(id -u tester) | grep -m1 -oE '^wayland-[0-9]+$'"
          ).strip()

      with subtest("the wrapped waybar starts against it"):
          machine.succeed(
              "su -l tester -c 'env XDG_RUNTIME_DIR=/run/user/$(id -u)"
              f" WAYLAND_DISPLAY={display}"
              " waybar -l debug >/tmp/waybar.log 2>&1 &'"
          )
          machine.wait_until_succeeds("pgrep -u tester waybar")

      with subtest("waybar loads the baked config and stylesheet"):
          machine.wait_until_succeeds("grep -q 'waybar-config.json' /tmp/waybar.log")
          machine.wait_until_succeeds("grep -q 'waybar-style.css' /tmp/waybar.log")

      with subtest("the sentinel custom module from the baked config executes"):
          got = machine.wait_until_succeeds("cat /tmp/waybar-sentinel").strip()
          assert got == "${sentinel}", f"sentinel module did not run from baked config: {got!r}"

      with subtest("waybar keeps running (no config/style parse crash)"):
          machine.sleep(5)
          machine.succeed("pgrep -u tester waybar")
          machine.fail("grep -iq 'terminating\\|fatal' /tmp/waybar.log")
    '';
  }
