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

    # Both scenarios run the same stylix-driven HM config; only the
    # pre-seeded Base16Kvantum state differs (see testScript).
    hmUser = {...}: {
      home.stateVersion = "25.11";
      # Mirrors the production stylix wiring — implicitly enables
      # stylix.targets.qt and the kvantum xdg.configFile entries that
      # blow up on a stale Base16Kvantum symlink.
      stylix.enable = lib.mkDefault true;
    };
  in {
    imports = [
      inputs.home-manager-nixos-unstable.nixosModules.home-manager
      inputs.stylix-nixos-unstable.nixosModules.stylix

      ../configuration.nix
    ];

    # The production-side workaround for the stale-Kvantum-symlink bug
    # lives at modules/home-manager/sharedModules/programs/kvantum.nix.
    # Wire it onto every test HM user so the fix is exercised here
    # exactly the way the real host gets it.
    home-manager.sharedModules = [
      ../../../modules/home-manager/sharedModules/programs/kvantum.nix
    ];

    nixpkgs.hostPlatform = "x86_64-linux";

    # Two users exercise the two flavors of the bug in one boot:
    #   dangling  — symlink whose target was GC'd (old guard caught this)
    #   validlink — symlink into a still-present read-only store dir
    #               (old guard skipped this; the production failure)
    users.users.dangling = {
      isNormalUser = true;
      uid = 1010;
      group = "users";
      home = "/home/dangling";
    };
    users.users.validlink = {
      isNormalUser = true;
      uid = 1011;
      group = "users";
      home = "/home/validlink";
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
    home-manager.users.dangling = hmUser;
    home-manager.users.validlink = hmUser;

    # The production failure happens at boot because hm-activate runs
    # automatically. Pin the test sequence by holding the units until
    # we've seeded the stale state, then start them explicitly.
    systemd.services.home-manager-dangling.wantedBy = lib.mkForce [];
    systemd.services.home-manager-validlink.wantedBy = lib.mkForce [];
  };

  testScript = ''
    def kvantum_dir(user):
        return f"/home/{user}/.config/Kvantum"

    def base16_link(user):
        return f"{kvantum_dir(user)}/Base16Kvantum"

    def seed_common(user):
        # `mkdir -p` creates intermediate dirs with caller's perms
        # (root); HM activation runs as the user and needs to mkdir
        # sibling .config children. Do the dir layout as the user so
        # the whole tree is owned correctly.
        machine.succeed(
            f"runuser -u {user} -- mkdir -p "
            f"{kvantum_dir(user)} /home/{user}/.config/dconf"
        )
        # ~/.config/dconf must exist before activation: in the HM
        # version pinned here `dconfSettings` runs ahead of
        # `linkGeneration` and bails on a missing dir, masking the
        # bug we want to surface.
        machine.succeed(f"chmod 0700 /home/{user}/.config/dconf")

    def activate(user):
        # Plain `systemctl start` already blocks on Type=oneshot's
        # ExecStart finishing; `--wait` here would hang because the
        # unit has RemainAfterExit=yes and never terminates after a
        # successful run.
        unit = f"home-manager-{user}.service"
        status, output = machine.execute(f"systemctl start {unit}")
        journal = machine.succeed(f"journalctl -u {unit} --no-pager")
        assert status == 0, (
            f"home-manager activation failed for {user} (status={status}):\n"
            f"{output}\n--- journal ---\n{journal}"
        )
        result = machine.succeed(
            f"systemctl show -p Result --value {unit}"
        ).strip()
        assert result == "success", (
            f"{unit} Result: {result!r}; journal:\n{journal}"
        )

    def assert_theme_reachable(user):
        # The whole point of the fix is to leave a working theme
        # behind. Both files must resolve through whatever HM ended up
        # placing at Base16Kvantum, and kvantum.kvconfig must still
        # select it (otherwise kvantum silently uses its default).
        for entry in ("Base16Kvantum.svg", "Base16Kvantum.kvconfig"):
            machine.succeed(f"test -r {base16_link(user)}/{entry}")
        machine.succeed(
            f"grep -q '^theme=Base16Kvantum$' {kvantum_dir(user)}/kvantum.kvconfig"
        )

    machine.wait_for_unit("multi-user.target")

    with subtest("dangling Base16Kvantum symlink is recovered"):
        user = "dangling"
        seed_common(user)
        # Any non-existent path will do — what matters is that the
        # symlink itself exists and its target does not, mimicking a
        # GC'd previous home-manager-files entry.
        stale_target = (
            "/nix/store/000000000000000000000000000000aa-stale"
            "/.config/Kvantum/Base16Kvantum"
        )
        machine.succeed(
            f"runuser -u {user} -- ln -sfn {stale_target} {base16_link(user)}"
        )
        # Confirm the symlink exists but its target does not — exactly
        # the state the original production failure reported.
        machine.succeed(f"test -L {base16_link(user)}")
        machine.fail(f"test -e {base16_link(user)}")

        # Pre-fix this failed with:
        #   mkdir: cannot create directory '.../Base16Kvantum': File exists
        #   ln: failed to create symbolic link '.../Base16Kvantum.svg'
        #         : No such file or directory
        activate(user)
        machine.fail(f"test -L {base16_link(user)}")
        machine.succeed(f"test -d {base16_link(user)}")
        assert_theme_reachable(user)

    with subtest("valid Base16Kvantum symlink into read-only store is recovered"):
        user = "validlink"
        seed_common(user)
        # Mimic an older generation's hm-files: a real, read-only
        # directory the single symlink still resolves to. HM's backup
        # step tries to `mv` files into a `.hm-backup` sibling *inside*
        # this directory, which fails on the read-only mount just like
        # the production /nix/store path did.
        oldgen = "/var/oldgen-kvantum/Base16Kvantum"
        machine.succeed(f"mkdir -p {oldgen}")
        # Sentinel content proves whether activation kept the stale
        # theme (bug) or replaced it with the current generation (fix).
        machine.succeed(
            f"echo STALE_KVANTUM_SENTINEL > {oldgen}/Base16Kvantum.kvconfig"
        )
        machine.succeed(f"echo '<svg/>' > {oldgen}/Base16Kvantum.svg")
        machine.succeed("chmod -R a-w /var/oldgen-kvantum")
        machine.succeed(
            f"runuser -u {user} -- ln -sfn {oldgen} {base16_link(user)}"
        )
        # The case the old `! -e` guard skipped: a *valid* symlink.
        machine.succeed(f"test -L {base16_link(user)}")
        machine.succeed(f"test -e {base16_link(user)}")

        # Pre-fix the guard skipped this link, HM's backup `mv` failed
        # on the read-only target, and the stale symlink (and its old
        # theme) survived. Post-fix the link is dropped and rebuilt as
        # a directory of current-generation symlinks.
        activate(user)
        machine.fail(f"test -L {base16_link(user)}")
        machine.succeed(f"test -d {base16_link(user)}")
        assert_theme_reachable(user)
        # Confirm the recovered theme is the live one, not the seeded
        # read-only copy left over from the "old generation".
        machine.fail(
            f"grep -q STALE_KVANTUM_SENTINEL "
            f"{base16_link(user)}/Base16Kvantum.kvconfig"
        )
  '';
}
