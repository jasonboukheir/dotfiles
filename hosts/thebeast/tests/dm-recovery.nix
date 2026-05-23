{
  pkgs,
  inputs,
}:
pkgs.testers.nixosTest {
  name = "thebeast-dm-recovery";

  nodes.machine = {
    lib,
    pkgs,
    ...
  }: {
    imports = [
      inputs.agenix.nixosModules.default
      inputs.home-manager-nixos-unstable.nixosModules.home-manager
      inputs.stylix-nixos-unstable.nixosModules.stylix
      inputs.jovian.nixosModules.default

      ../software.nix
      ../session.nix
      ./test-overrides.nix
    ];

    virtualisation = {
      memorySize = 2048;
      cores = 2;
    };

    # Skip jovian's gamescope autologin in the VM — gamescope can't run
    # headlessly and the user-session times out about a second in, which
    # masks the regression we actually care about with unrelated noise.
    # The full host-level autologin contract is asserted in session.nix.
    services.displayManager.autoLogin.enable = lib.mkForce false;
  };

  testScript = ''
    machine.wait_for_unit("plasmalogin.service")

    with subtest("plasmalogin runs and reaches a greeter"):
        # PLM with no autologin must roll straight to a greeter display.
        # If the daemon dies during boot (e.g. some unit ordering issue
        # introduced by an override), the whole session-recovery story is
        # moot — assert the baseline first.
        machine.wait_until_succeeds(
            "pgrep -u plasmalogin -f plasma-login-greeter", timeout=60
        )
        # And the service itself must be the canonical display-manager.
        dm_cat = machine.succeed("systemctl cat display-manager.service")
        assert "plasmalogin" in dm_cat, (
            "display-manager.service should run plasmalogin:\n" + dm_cat
        )

    with subtest("hyprexit dispatches a compositor exit, not loginctl terminate-user"):
        # Regression guard for the black-framebuffer-after-hyprexit bug.
        #
        # plasma-login-manager 6.6's Auth/Display lifecycle special-cases
        # the helper's exit code:
        #
        #   void Display::slotHelperFinished(Auth::HelperExitStatus s) {
        #       if (s != Auth::HELPER_AUTH_ERROR) stop();
        #   }
        #
        # i.e. Display::stop() (and therefore Seat::createDisplay() of the
        # next greeter) is skipped when the helper exits with status
        # HELPER_AUTH_ERROR (= 1). When `loginctl terminate-user` SIGTERMs
        # the user's processes, the helper — which lives inside the user's
        # session scope as the session leader — is killed too. PLM's
        # SignalHandler converts SIGTERM into QCoreApplication::exit(-1),
        # which (after exit-code wrap) plasmalogin reads as 1, the value
        # of HELPER_AUTH_ERROR. So terminate-user lands on the one
        # PLM-internal branch that explicitly does NOT bring the greeter
        # back, leaving the framebuffer black with no path forward.
        #
        # The cure is to make hyprland exit through its own dispatcher so
        # the wayland-session process exits with code 0, the helper
        # propagates HELPER_SUCCESS, and PLM's Display::stop -> Seat::
        # createDisplay path runs normally.
        script = machine.succeed("cat $(command -v hyprexit)")
        machine.log(script)
        assert "loginctl terminate-user" not in script, (
            "hyprexit must not call `loginctl terminate-user` — that "
            "SIGTERMs plasmalogin-helper and trips the HELPER_AUTH_ERROR "
            "branch in PLM's Display::slotHelperFinished, leaving the "
            "display stuck without a greeter. Got:\n" + script
        )
        # Pin the Lua-mode dispatcher spelling. Under
        # `configType = "lua"` the legacy `hyprctl dispatch exit`
        # lowers to `hl.dispatch(exit)`, where `exit` is a bare Lua
        # identifier (= nil), and hl.dispatch rejects it — the
        # compositor stays alive and PLM never gets a greeter back.
        # Refs: hyprwm/Hyprland#14255, hyprwm/Hyprland#14282.
        assert "hyprctl dispatch 'hl.dsp.exit()'" in script, (
            "hyprexit must dispatch a clean hyprland exit so the "
            "wayland-session process exits with code 0, propagating "
            "HELPER_SUCCESS up to plasmalogin and triggering the "
            "Display::stop -> Seat::createDisplay greeter-recycle path. "
            "Got:\n" + script
        )
  '';
}
