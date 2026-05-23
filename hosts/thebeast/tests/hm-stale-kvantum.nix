{
  pkgs,
  inputs,
}:
pkgs.testers.nixosTest {
  name = "thebeast-hm-stale-kvantum";

  nodes.machine = {
    lib,
    pkgs,
    ...
  }: let
    wallpapers = import ../../../modules/stylix/wallpapers {inherit pkgs;};
  in {
    imports = [
      inputs.home-manager-nixos-unstable.nixosModules.home-manager
      inputs.stylix-nixos-unstable.nixosModules.stylix

      ../state-version.nix
    ];

    # The production-side workaround for the stale-Kvantum-symlink bug
    # lives at modules/home-manager/sharedModules/programs/kvantum.nix.
    # Wire it onto every test HM user so the fix is exercised here
    # exactly the way the real host gets it.
    home-manager.sharedModules = [
      ../../../modules/home-manager/sharedModules/programs/kvantum.nix
    ];

    nixpkgs.hostPlatform = "x86_64-linux";

    users.users.testuser = {
      isNormalUser = true;
      uid = 1010;
      group = "users";
      home = "/home/testuser";
    };

    # Stylix's HM qt target only kicks in when stylix is enabled and a
    # base16 scheme + image are pinned. Reuse the real fixtures from
    # modules/stylix so the test exercises the same theme generation
    # the production host does.
    stylix = {
      enable = true;
      image = wallpapers.analog-dreams;
      base16Scheme = ../../../modules/stylix/themes/digital-nightmares.yaml;
      polarity = "dark";
    };

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.users.testuser = {...}: {
      home.stateVersion = "25.11";
      # Mirrors the production stylix wiring — implicitly enables
      # stylix.targets.qt and the kvantum xdg.configFile entries that
      # blow up on a stale Base16Kvantum symlink.
      stylix.enable = lib.mkDefault true;
    };

    # The production failure happens at boot because hm-activate runs
    # automatically. Pin the test sequence by holding the unit until
    # we've seeded the stale state, then start it explicitly.
    systemd.services.home-manager-testuser.wantedBy = lib.mkForce [];
  };

  testScript = ''
    USER = "testuser"
    HOME_DIR = f"/home/{USER}"
    KVANTUM_DIR = f"{HOME_DIR}/.config/Kvantum"
    BASE16_LINK = f"{KVANTUM_DIR}/Base16Kvantum"
    # Any non-existent path will do — what matters is that the symlink
    # itself exists and its target does not, mimicking a GC'd previous
    # home-manager-files entry.
    STALE_TARGET = "/nix/store/000000000000000000000000000000aa-stale/.config/Kvantum/Base16Kvantum"

    machine.wait_for_unit("multi-user.target")

    with subtest("seed a dangling Base16Kvantum symlink in the user's home"):
        # `mkdir -p` creates intermediate dirs with caller's perms
        # (root); HM activation runs as the user and needs to mkdir
        # sibling .config children. Do the dir layout as the user so
        # the whole tree is owned correctly.
        machine.succeed(
            f"runuser -u {USER} -- mkdir -p "
            f"{KVANTUM_DIR} {HOME_DIR}/.config/dconf"
        )
        # ~/.config/dconf must exist before activation: in the HM
        # version pinned here `dconfSettings` runs ahead of
        # `linkGeneration` and bails on a missing dir, masking the
        # bug we want to surface.
        machine.succeed(f"chmod 0700 {HOME_DIR}/.config/dconf")
        machine.succeed(
            f"runuser -u {USER} -- ln -sfn {STALE_TARGET} {BASE16_LINK}"
        )
        # Confirm the symlink itself exists but its target does not —
        # this is exactly the state the production failure reported.
        machine.succeed(f"test -L {BASE16_LINK}")
        machine.fail(f"test -e {BASE16_LINK}")

    with subtest("home-manager activation must recover from the stale link"):
        # Pre-fix this fails with:
        #   mkdir: cannot create directory '.../Base16Kvantum': File exists
        #   ln: failed to create symbolic link '.../Base16Kvantum/Base16Kvantum.svg'
        #         : No such file or directory
        # Plain `systemctl start` already blocks on Type=oneshot's
        # ExecStart finishing; `--wait` here would hang because the
        # unit has RemainAfterExit=yes and never terminates after a
        # successful run.
        status, output = machine.execute(
            "systemctl start home-manager-testuser.service"
        )
        assert status == 0, (
            f"home-manager activation failed (status={status}):\n"
            f"{output}\n"
            f"--- journal ---\n"
            f"{machine.succeed('journalctl -u home-manager-testuser.service --no-pager')}"
        )
        result = machine.succeed(
            "systemctl show -p Result --value home-manager-testuser.service"
        ).strip()
        assert result == "success", \
            f"unit Result: {result!r}; journal:\n" + machine.succeed(
                "journalctl -u home-manager-testuser.service --no-pager"
            )

    with subtest("kvantum theme files are reachable after activation"):
        # The whole point of the fix is to leave a working theme
        # behind. Both files must resolve through whatever HM ended up
        # placing at Base16Kvantum (symlink or dir).
        for entry in ("Base16Kvantum.svg", "Base16Kvantum.kvconfig"):
            machine.succeed(f"test -r {BASE16_LINK}/{entry}")
        # kvantum.kvconfig is the General.theme = Base16Kvantum file —
        # if HM dropped it because of an earlier error path, kvantum
        # would silently fall back to its default theme.
        machine.succeed(
            f"grep -q '^theme=Base16Kvantum$' {KVANTUM_DIR}/kvantum.kvconfig"
        )
  '';
}
