{
  pkgs,
  inputs,
}:
pkgs.testers.nixosTest {
  name = "thebeast-dm-recovery";

  nodes.machine = {
    config,
    lib,
    pkgs,
    ...
  }: let
    # Stand-in for a real wayland session: logs that it ran, then waits
    # for an exit marker so the test controls when the session ends.
    # Exits 0 so sddm takes its normal Display::stop ->
    # Seat::createDisplay recycle path (a non-zero helper exit lands on
    # the HELPER_AUTH_ERROR special case instead — see the hyprexit
    # subtest below).
    sessionScript = pkgs.writeShellScript "stub-session" ''
      echo "user=$(id -un)" >> /tmp/stub-session-log
      until [ -e /tmp/exit-stub ]; do sleep 1; done
    '';
    stubSession =
      pkgs.runCommand "stub-session" {
        passthru.providedSessions = ["stub"];
        desktopEntry = ''
          [Desktop Entry]
          Name=stub
          Exec=${sessionScript}
          Type=Application
        '';
        passAsFile = ["desktopEntry"];
      } ''
        install -Dm444 "$desktopEntryPath" \
          "$out/share/wayland-sessions/stub.desktop"
      '';
  in {
    _module.args.inputs = inputs;
    imports = [
      inputs.agenix.nixosModules.default
      inputs.stylix-nixos-unstable.nixosModules.stylix
      inputs.jovian.nixosModules.default

      ../system
      ../session
      ./test-overrides.nix
    ];

    virtualisation = {
      memorySize = 2048;
      cores = 2;
    };

    # Keep jovian's gamer autologin, but retarget it from gamescope
    # (which can't run headlessly — the user session times out about a
    # second in and masks everything) to the controllable stub session.
    # gaming.exitToGreeter (production default) leaves Relogin off, so
    # the stub session's exit takes the greeter-spawn branch — the exact
    # session-exit → greeter flow thebeast relies on for getting out of
    # Steam and into the Hyprland dev session (and the lifecycle behind
    # the sddm + wayland greeter black-screen-after-logout reports:
    # https://discourse.nixos.org/t/66777).
    services.displayManager.sessionPackages = [stubSession];
    services.displayManager.defaultSession = lib.mkForce "stub";
    # The greeter preselects this session (hyprland-uwsm on the host,
    # via omarchy.nix); point it at the stub so the empty-password login
    # subtest lands back in the controllable session instead of trying
    # to launch hyprland.
    thebeast.greeterDefaultSession = lib.mkForce "stub";

    # Late-NIC fixture for the network-gating subtest: the host's wired
    # NIC (igc) is only probed ~6s after NetworkManager starts, so the
    # profile's wait-device-timeout is what keeps wait-online (and the
    # display-manager ordering behind it) from passing vacuously.
    # Reproduce that shape deterministically: point the wired profile at
    # a veth that a timer only creates 15s into boot, with dnsmasq
    # answering DHCP on the peer end so activation completes for real.
    thebeast.network.wiredInterface = "lateif0";
    systemd.timers.late-nic = {
      wantedBy = ["timers.target"];
      timerConfig.OnActiveSec = "15s";
    };
    systemd.services.late-nic = {
      path = [pkgs.iproute2 pkgs.dnsmasq];
      serviceConfig = {
        Type = "oneshot";
        # dnsmasq daemonises out of the script; keep the unit (and its
        # cgroup) alive so the DHCP server survives the oneshot exit.
        RemainAfterExit = true;
      };
      script = ''
        ip link add lateif0 type veth peer name lateif0p
        ip addr add 10.123.0.1/24 dev lateif0p
        ip link set lateif0p up
        # port=0 disables DNS; empty options 3/6 keep dnsmasq from
        # pushing a default route or resolver that would shadow eth0.
        dnsmasq --interface=lateif0p --bind-interfaces --except-interface=lo \
          --port=0 --dhcp-range=10.123.0.10,10.123.0.50,12h \
          --dhcp-option=3 --dhcp-option=6
      '';
    };
    # NM ships 85-nm-unmanaged.rules marking veth peers unmanaged; the
    # fixture needs lateif0 treated like the host's real wired NIC.
    services.udev.extraRules = ''
      SUBSYSTEM=="net", KERNEL=="lateif0", ENV{NM_UNMANAGED}="0"
    '';
    # The host firewall drops the DHCPDISCOVER before dnsmasq sees it,
    # failing the lateif0 activation the gating subtest depends on.
    networking.firewall.interfaces.lateif0p.allowedUDPPorts = [67];
  };

  testScript = ''
    import time

    machine.wait_for_unit("display-manager.service")

    def monotonic_us(unit, prop):
        value = machine.succeed(
            f"systemctl show -p {prop} --value {unit}"
        ).strip()
        # systemd reports 0 for a timestamp that never happened; treating
        # it as a real instant would make the ordering asserts below
        # trivially true in exactly the broken case.
        assert value not in ("", "0"), f"{unit} has no {prop} — did it ever run?"
        return int(value)

    with subtest("display-manager waits for the late NIC, not a vacuous wait-online"):
        # wait_for_unit(display-manager) above returns as soon as sddm is
        # up — in the broken (vacuous wait-online) case that's *before*
        # the late-nic timer has fired, so pin the fixture first.
        machine.wait_for_unit("late-nic.service")
        # The regression this gates: NM declares "startup complete" the
        # moment it has no profile waiting on a device, so with only
        # auto-generated profiles NetworkManager-wait-online finished
        # before the host's igc NIC had even been probed and Steam came
        # up offline (gens 299-301, Jun 2026). The wired profile's
        # wait-device-timeout is what makes the chain real. Here the NIC
        # only appears when late-nic.service creates it 15s into boot,
        # so a vacuous wait-online is unambiguously distinguishable from
        # a gating one.
        nic_created = monotonic_us(
            "late-nic.service", "ExecMainStartTimestampMonotonic"
        )
        wait_online_done = monotonic_us(
            "NetworkManager-wait-online.service",
            "ExecMainExitTimestampMonotonic",
        )
        dm_started = monotonic_us(
            "display-manager.service", "InactiveExitTimestampMonotonic"
        )
        assert wait_online_done > nic_created, (
            "NetworkManager-wait-online finished before the wired NIC "
            "existed — the wait-device-timeout profile is not gating NM "
            f"startup (wait-online done at {wait_online_done}us, NIC "
            f"created at {nic_created}us)"
        )
        assert dm_started > nic_created, (
            "display-manager started before the wired NIC existed — the "
            "network-online ordering is not holding the session back "
            f"(dm at {dm_started}us, NIC at {nic_created}us)"
        )
        # The profile must have actually activated (real DHCP from the
        # fixture's dnsmasq), not failed into a timed-out startup.
        machine.wait_until_succeeds(
            "ip -4 addr show lateif0 | grep -q 'inet 10.123.0.'", timeout=60
        )

    with subtest("sddm boots straight into the one-shot autologin session"):
        # daemonApp->first makes the initial autologin run even with
        # Relogin=false (Display.cpp displayServerStarted), so the boot
        # path must land in the stub session, not a greeter.
        dm_cat = machine.succeed("systemctl cat display-manager.service")
        assert "sddm" in dm_cat, (
            "display-manager.service should exec sddm:\n" + dm_cat
        )
        machine.wait_until_succeeds(
            "grep -q 'user=gamer' /tmp/stub-session-log", timeout=120
        )

    with subtest("a clean session exit recycles to a greeter (spike (b))"):
        # The regression this gates: sddm's Display::stop ->
        # Seat::createDisplay chain failing to bring up the next display
        # after a wayland session ends, leaving a black framebuffer with
        # display-manager.service still nominally healthy. Ending the
        # session must produce a live greeter process under the sddm
        # user without the unit restarting (an in-process recycle, not a
        # crash-loop recovery).
        machine.succeed("touch /tmp/exit-stub")
        machine.wait_until_succeeds(
            "journalctl -u display-manager.service "
            "| grep -q 'Greeter session started successfully'",
            timeout=120,
        )
        machine.wait_until_succeeds(
            "pgrep -u sddm -f sddm-greeter >/dev/null", timeout=60
        )
        machine.succeed("systemctl is-active display-manager.service")
        n_restarts = machine.succeed(
            "systemctl show -p NRestarts --value display-manager.service"
        ).strip()
        assert n_restarts == "0", (
            "greeter recycle must happen inside the running sddm daemon; "
            f"display-manager.service restarted {n_restarts} time(s)"
        )

    with subtest("the recycled greeter stays alive — started is not survived"):
        # On the host, "Greeter session started successfully" was logged
        # one second before the greeter's display server aborted
        # (weston 15.0, drm-formats.c:451 duplicate-modifier assert on
        # the amdgpu pair — the gen-299 Switch-to-Desktop black screen),
        # so the previous subtest's start marker alone proves nothing.
        # Nobody logs in during this test, so any greeter teardown —
        # "Greeter stopped", a compositor CrashExit, or the
        # sddm-greeter process disappearing — is a crash.
        time.sleep(10)
        machine.succeed("pgrep -u sddm -f sddm-greeter >/dev/null")
        machine.succeed("systemctl is-active display-manager.service")
        dm_journal = machine.succeed("journalctl -u display-manager.service")
        assert "CrashExit" not in dm_journal, (
            "the greeter display server crashed after starting:\n"
            + dm_journal
        )
        assert "Greeter stopped" not in dm_journal, (
            "sddm tore the greeter back down without a login:\n"
            + dm_journal
        )

    with subtest("the greeter renders the configured theme, not the embedded fallback"):
        # When the theme's QML imports drop out of the closure (the
        # breeze theme lost its KDE modules when plasma6 was removed),
        # sddm logs the failure and falls back to its embedded theme —
        # visually obvious on the host, invisible to a unit-level check
        # because the greeter logs under its user session, not under
        # display-manager.service.
        greeter_journal = machine.succeed("journalctl -t sddm-greeter-qt6")
        for marker in ("Fallback to embedded theme", "is not installed"):
            assert marker not in greeter_journal, (
                f"greeter theme failed to load ({marker!r}):\n"
                + greeter_journal
            )

    with subtest("hyprexit dispatches a compositor exit, not loginctl terminate-user"):
        # Regression guard for the black-framebuffer-after-hyprexit bug.
        #
        # sddm's Auth/Display lifecycle special-cases the helper's exit
        # code (plasma-login-manager inherited this verbatim):
        #
        #   void Display::slotHelperFinished(Auth::HelperExitStatus s) {
        #       if (s != Auth::HELPER_AUTH_ERROR) stop();
        #   }
        #
        # i.e. Display::stop() (and therefore Seat::createDisplay() of the
        # next greeter) is skipped when the helper exits with status
        # HELPER_AUTH_ERROR (= 1). When `loginctl terminate-user` SIGTERMs
        # the user's processes, the helper — which lives inside the user's
        # session scope as the session leader — is killed too. The
        # SignalHandler converts SIGTERM into QCoreApplication::exit(-1),
        # which (after exit-code wrap) the daemon reads as 1, the value
        # of HELPER_AUTH_ERROR. So terminate-user lands on the one
        # internal branch that explicitly does NOT bring the greeter
        # back, leaving the framebuffer black with no path forward.
        #
        # The cure is to make hyprland exit through its own dispatcher so
        # the wayland-session process exits with code 0, the helper
        # propagates HELPER_SUCCESS, and the Display::stop -> Seat::
        # createDisplay path runs normally — the same path the subtest
        # above exercises end-to-end with the stub session.
        script = machine.succeed("cat $(command -v hyprexit)")
        machine.log(script)
        assert "loginctl terminate-user" not in script, (
            "hyprexit must not call `loginctl terminate-user` — that "
            "SIGTERMs the sddm helper and trips the HELPER_AUTH_ERROR "
            "branch in Display::slotHelperFinished, leaving the "
            "display stuck without a greeter. Got:\n" + script
        )
        # Pin the Lua-mode dispatcher spelling. Under
        # `configType = "lua"` the legacy `hyprctl dispatch exit`
        # lowers to `hl.dispatch(exit)`, where `exit` is a bare Lua
        # identifier (= nil), and hl.dispatch rejects it — the
        # compositor stays alive and sddm never gets a greeter back.
        # Refs: hyprwm/Hyprland#14255, hyprwm/Hyprland#14282.
        assert "hyprctl dispatch 'hl.dsp.exit()'" in script, (
            "hyprexit must dispatch a clean hyprland exit so the "
            "wayland-session process exits with code 0, propagating "
            "HELPER_SUCCESS up to sddm and triggering the "
            "Display::stop -> Seat::createDisplay greeter-recycle path. "
            "Got:\n" + script
        )

    with subtest("plain Enter on the empty password field logs gamer in"):
        # The theme's Enter handler drops empty submissions unless
        # passwordAllowEmpty is set (Main.qml: `if (text != "" || ...)`),
        # which forced typing a throwaway character to log into the
        # passwordless gamer account. The recycled greeter focuses the
        # password field and preselects the last user (gamer), so a bare
        # Enter is an empty-password submit; it must authenticate
        # (empty hash + nullok) and start the preselected stub session a
        # second time.
        machine.succeed("rm -f /tmp/exit-stub")
        machine.send_key("ret")
        machine.wait_until_succeeds(
            "test \"$(grep -c 'user=gamer' /tmp/stub-session-log)\" -eq 2",
            timeout=120,
        )
  '';
}
