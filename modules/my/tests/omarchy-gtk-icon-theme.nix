# The omarchy gtk module's load-bearing assumption (issue #48): GTK merges
# settings.ini per-key across XDG_CONFIG_DIRS then XDG_CONFIG_HOME, so the
# /etc/xdg icon-theme fallback reaches GTK apps even when something else
# (HM-stylix today, Plasma's GTK Settings Sync for gamer) owns a user-level
# settings.ini that doesn't carry the icon key — while the user file still
# wins on the keys it does set.
{
  pkgs,
  inputs ? null,
}: let
  userThemeSentinel = "user-gtk-theme-7e31";

  runtimeDir = "/tmp/wl-runtime";
  westonEnv = "XDG_RUNTIME_DIR=${runtimeDir}";
  gtkEnv = "${westonEnv} WAYLAND_DISPLAY=wl-test GDK_BACKEND=wayland";
in
  pkgs.testers.nixosTest {
    name = "omarchy-gtk-icon-theme";

    nodes.machine = {
      imports = [
        ../../omarchy/config.nix
        ../../omarchy/gtk.nix
      ];

      omarchy.enable = true;

      virtualisation.memorySize = 2048;
      environment.systemPackages = [
        pkgs.weston
        pkgs.gtk3.dev # gtk-query-settings
        pkgs.gtk4.dev # gtk4-query-settings
      ];
      fonts.packages = [pkgs.dejavu_fonts];

      users.users.tester.isNormalUser = true;
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      with subtest("the configured icon theme is resolvable from the system profile"):
          machine.succeed("test -f /run/current-system/sw/share/icons/breeze-dark/index.theme")

      # A user-level settings.ini that sets a theme but no icon theme — the
      # shape HM-stylix and Plasma's GTK Settings Sync leave behind.
      for ver in ["3.0", "4.0"]:
          machine.succeed(
              f"su -l tester -c 'mkdir -p ~/.config/gtk-{ver} &&"
              f" printf \"[Settings]\\ngtk-theme-name=${userThemeSentinel}\\n\""
              f" > ~/.config/gtk-{ver}/settings.ini'"
          )

      machine.succeed("install -d -m 700 -o tester -g users ${runtimeDir}")
      machine.succeed(
          "su -l tester -c '${westonEnv} weston --backend=headless --socket=wl-test"
          " --idle-time=0 >/tmp/weston.log 2>&1 &'"
      )
      machine.wait_until_succeeds("test -S ${runtimeDir}/wl-test")

      for query, label in [("gtk-query-settings", "GTK3"), ("gtk4-query-settings", "GTK4")]:
          with subtest(f"{label}: icon theme falls back per-key to /etc/xdg"):
              out = machine.succeed(
                  f"su -l tester -c '${gtkEnv} {query} gtk-icon-theme-name'"
              )
              assert "breeze-dark" in out, f"{label} icon theme not from /etc/xdg: {out!r}"

          with subtest(f"{label}: the user settings.ini still wins on its own keys"):
              out = machine.succeed(
                  f"su -l tester -c '${gtkEnv} {query} gtk-theme-name'"
              )
              assert "${userThemeSentinel}" in out, f"{label} theme not from user file: {out!r}"
    '';
  }
