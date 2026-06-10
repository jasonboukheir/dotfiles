# Per-user launcher plumbing: my.wofi.{settings,style} + stylix colors ->
# baked --conf/--style, verified end-to-end under a headless weston compositor.
{
  pkgs,
  inputs ? null,
}: let
  promptSentinel = "my-wofi-prompt-7e31";
  styleSentinel = "my-wofi-style-7e31";
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

  runtimeDir = "/tmp/wl-runtime";
  westonEnv = "XDG_RUNTIME_DIR=${runtimeDir}";
  wofiEnv = "${westonEnv} WAYLAND_DISPLAY=wl-test GDK_BACKEND=wayland";
in
  pkgs.testers.nixosTest {
    name = "my-wofi-wrapper";

    nodes.machine = {
      nixpkgs.pkgs = pkgsWrapped;
      imports = [
        ../nixos.nix
        ../../stylix/users/options.nix
      ];

      virtualisation.memorySize = 2048;
      environment.systemPackages = [pkgs.weston];
      fonts.packages = [pkgs.dejavu_fonts];

      users.users.tester = {
        isNormalUser = true;
        stylix = {
          enable = true;
          inherit colors;
        };
        my.stylix.enable = true;
        my.wofi = {
          enable = true;
          settings.prompt = promptSentinel;
          style = ''
            /* ${styleSentinel} */
            window {
              border-radius: 7px;
            }
          '';
        };
      };
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      wofi = machine.succeed("su -l tester -c 'readlink -f $(command -v wofi)'").strip()

      with subtest("the wrapper bakes --conf and --style"):
          machine.succeed(f"grep -aq -- '--conf' {wofi}")
          machine.succeed(f"grep -aq -- '--style' {wofi}")

      conf = machine.succeed(
          f"grep -aoE '/nix/store/[a-z0-9]{{32}}-wofi-config' {wofi} | head -n1"
      ).strip()
      style = machine.succeed(
          f"grep -aoE '/nix/store/[a-z0-9]{{32}}-wofi-style.css' {wofi} | head -n1"
      ).strip()
      assert conf and style, "no baked wofi config/style paths found in the wrapper"

      with subtest("settings render in wofi's key=value format"):
          machine.succeed(f"grep -axq 'prompt=${promptSentinel}' {conf}")

      with subtest("the stylesheet prepends stylix base16 CSS before user style"):
          css = machine.succeed(f"cat {style}")
          assert "#${colors.base00}" in css, "themed background colour missing from stylesheet"
          assert "#${colors.base0A}" in css, "themed focus border colour missing from stylesheet"
          assert "${styleSentinel}" in css, "user style lines missing from stylesheet"
          assert css.index("#${colors.base00}") < css.index("${styleSentinel}"), \
              "user style does not come after (i.e. cannot override) the themed CSS"

      machine.succeed("install -d -m 700 -o tester -g users ${runtimeDir}")
      machine.succeed(
          "su -l tester -c '${westonEnv} weston --backend=headless --socket=wl-test"
          " --idle-time=0 >/tmp/weston.log 2>&1 &'"
      )
      machine.wait_until_succeeds("test -S ${runtimeDir}/wl-test")

      with subtest("wofi --show drun starts under the headless compositor"):
          machine.succeed(
              "su -l tester -c '${wofiEnv} wofi --show drun"
              " >/tmp/wofi.out 2>/tmp/wofi.err &'"
          )
          machine.wait_until_succeeds(f"pgrep -u tester -f {conf}")
          machine.sleep(5)
          machine.succeed(f"pgrep -u tester -f {conf}")

      with subtest("the baked config and stylesheet parse cleanly"):
          stderr = machine.succeed("cat /tmp/wofi.err")
          assert "Theme parsing error" not in stderr, f"GTK rejected the baked CSS: {stderr!r}"
          assert "Invalid" not in stderr, f"wofi rejected the baked config: {stderr!r}"
    '';
  }
