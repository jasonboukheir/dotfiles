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
  };

  testScript = ''
    machine.wait_for_unit("display-manager.service")

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
  '';
}
