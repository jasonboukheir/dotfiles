{
  pkgs,
  inputs,
}:
pkgs.testers.nixosTest {
  name = "thebeast-steamos-autologin";

  # Two nodes, identical except for sddm.autoLogin.relogin. The spike this
  # answers (#48): does steamos-manager's zzt-steamos-temp-login.conf carry
  # Session= only or also User= (gamer-vs-jasonbk routing), and does
  # relogin=false suppress the one-shot autologin (Switch-to-Desktop lands
  # on the greeter instead of the desktop session)?
  #
  # jovian.steam.enable is deliberately left off — it drags in the full
  # Steam/gamescope closure, none of which can run headless. Instead the
  # node wires the same steamos-manager contract jovian's
  # modules/steam/{steam,autostart}.nix wire:
  # https://github.com/Jovian-Experiments/Jovian-NixOS/blob/255a9642/modules/steam/autostart.nix
  nodes = let
    mkNode = relogin: {
      config,
      pkgs,
      ...
    }: let
      sessionScript = pkgs.writeShellScript "fake-session" ''
        echo "user=$(id -un) session=$1" >> /tmp/session-log
        until [ -e "/tmp/exit-$1" ]; do sleep 1; done
      '';
      mkSession = name:
        pkgs.runCommand "${name}-session" {
          passthru.providedSessions = [name];
          desktopEntry = ''
            [Desktop Entry]
            Name=${name}
            Exec=${sessionScript} ${name}
            Type=Application
          '';
          passAsFile = ["desktopEntry"];
        } ''
          install -Dm444 "$desktopEntryPath" \
            "$out/share/wayland-sessions/${name}.desktop"
        '';
    in {
      imports = [inputs.jovian.nixosModules.default];

      virtualisation = {
        memorySize = 2048;
        cores = 2;
      };

      users.users.gamer = {
        isNormalUser = true;
        extraGroups = ["uinput"];
      };
      users.users.jasonbk.isNormalUser = true;

      # steamos-manager's user daemon opens /dev/uinput for the screen-reader
      # chord device (screenreader.rs OrcaManager::new, existence check
      # removed by jovian's hardcode-paths.patch); a Permission denied there
      # cancels the whole daemon (lib.rs Service::start token.cancel). The
      # real host gets this through jovian's `KERNEL=="uinput" ...
      # TAG+="uaccess"` rule in modules/steam/steam.nix; a group grant is
      # the deterministic equivalent for the test.
      hardware.uinput.enable = true;

      environment.systemPackages = [pkgs.steamos-manager];
      systemd.packages = [pkgs.steamos-manager];
      services.dbus.packages = [pkgs.steamos-manager];

      # steamos-manager validates desktop sessions against its own XDG data
      # dirs (session.rs valid_desktop_sessions), which the systemd user
      # manager does not populate with the DM's session directory.
      systemd.user.services.steamos-manager = {
        overrideStrategy = "asDropin";
        environment.XDG_DATA_DIRS = "${config.services.displayManager.sessionData.desktops}/share";
      };

      # is_session_managed() marker steamos-manager probes before exposing
      # the SessionManagement1 interface (session.rs SESSION_CHECK_PATH).
      environment.etc."sddm.conf.d/steamos.conf".text = "";

      services.xserver.enable = true;

      services.displayManager = {
        sessionPackages = [
          (mkSession "fake-game")
          (mkSession "fake-desktop")
        ];
        defaultSession = "fake-game";
        autoLogin = {
          enable = true;
          user = "gamer";
        };
        sddm = {
          enable = true;
          wayland.enable = true;
          autoLogin = {inherit relogin;};
        };
      };
    };
  in {
    relogin = mkNode true;
    norelogin = mkNode false;
  };

  testScript = ''
    import time

    TEMP_CONF = "/etc/sddm.conf.d/zzt-steamos-temp-login.conf"

    def gamer_cmd(cmd):
        return (
            "su - gamer -c 'XDG_RUNTIME_DIR=/run/user/$(id -u) "
            "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus "
            + cmd
            + "'"
        )

    def as_gamer(machine, cmd):
        return machine.succeed(gamer_cmd(cmd))

    def drive_switch_to_desktop(machine):
        machine.wait_for_unit("display-manager.service")
        machine.wait_until_succeeds(
            "grep -q 'user=gamer session=fake-game' /tmp/session-log",
            timeout=120,
        )

        # The first call dbus-activates both steamos-manager daemons
        # (SystemdService=steamos-manager.service); the bus name is owned
        # before all interfaces are registered, so retry across that window.
        shipped_default = machine.wait_until_succeeds(
            gamer_cmd("steamosctl get-default-desktop-session"),
            timeout=60,
        ).strip()
        print(f"{machine.name}: shipped default desktop session: {shipped_default}")

        as_gamer(machine, "steamosctl set-default-desktop-session fake-desktop.desktop")
        configured = as_gamer(
            machine, "steamosctl get-default-desktop-session"
        ).strip()
        assert configured == "fake-desktop.desktop", \
            f"set-default-desktop-session did not stick: {configured!r}"

        as_gamer(machine, "steamosctl switch-to-desktop-mode")

        temp_conf = machine.succeed(f"cat {TEMP_CONF}")
        print(f"{machine.name}: {TEMP_CONF}:\n{temp_conf}")
        static_conf = machine.succeed(
            "grep -A4 '\\[Autologin\\]' /etc/sddm.conf.d/00-nixos.conf"
        )
        print(f"{machine.name}: 00-nixos.conf [Autologin]:\n{static_conf}")

        # Spike question 1: the temp conf overrides Session= only. User=
        # stays whatever the static autologin config says (gamer), so
        # Switch-to-Desktop can never route to another user's session.
        assert "Session=fake-desktop.desktop" in temp_conf, \
            f"temp-login conf should pin the desktop session:\n{temp_conf}"
        assert "User=" not in temp_conf, \
            f"temp-login conf unexpectedly carries a User= key:\n{temp_conf}"
        assert "User=gamer" in static_conf, \
            f"static autologin config should pin the gaming user:\n{static_conf}"

        # End the fake gaming session cleanly (exit 0) so sddm takes its
        # normal Display::stop -> Seat::createDisplay relogin-decision path.
        machine.succeed("touch /tmp/exit-fake-game")

    start_all()

    with subtest("relogin=true: temp conf routes the one-shot autologin"):
        drive_switch_to_desktop(relogin)
        relogin.wait_until_succeeds(
            "grep -q 'user=gamer session=fake-desktop' /tmp/session-log",
            timeout=120,
        )
        session_log = relogin.succeed("cat /tmp/session-log")
        print(f"relogin: session log:\n{session_log}")
        assert "user=jasonbk" not in session_log, \
            f"desktop session must stay on the autologin user:\n{session_log}"

    with subtest("relogin=true: clean-temporary-sessions removes the temp conf"):
        as_gamer(relogin, "steamosctl clean-temporary-sessions")
        relogin.fail(f"test -e {TEMP_CONF}")

    with subtest("relogin=false: one-shot autologin is suppressed"):
        drive_switch_to_desktop(norelogin)
        # sddm only re-runs autologin when daemonApp->first (initial boot)
        # or Autologin.Relogin is set (Display.cpp displayServerStarted),
        # so the session exit must bring up a greeter, not fake-desktop.
        norelogin.wait_until_succeeds(
            "journalctl -u display-manager.service "
            "| grep -q 'Greeter session started successfully'",
            timeout=120,
        )
        time.sleep(15)
        session_log = norelogin.succeed("cat /tmp/session-log")
        print(f"norelogin: session log:\n{session_log}")
        assert "session=fake-desktop" not in session_log, (
            "relogin=false should suppress the one-shot autologin; "
            f"a desktop session still appeared:\n{session_log}"
        )
        norelogin.succeed(f"test -e {TEMP_CONF}")
        print("norelogin: temp conf still present, login routed to the greeter")
  '';
}
