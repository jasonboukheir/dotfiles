{
  config,
  lib,
  ...
}: let
  dmCfg = config.thebeast;
  # Both DMs run their greeter as a dedicated system user and read the
  # KDE color scheme from that user's ~/.config/kdeglobals — SDDM's
  # breeze greeter from /var/lib/sddm (what sddm-kcm's "Apply Plasma
  # Settings" writes imperatively), plasma-login-manager's from
  # /var/lib/plasmalogin.
  greeterUser =
    if dmCfg.displayManager == "plasma-login-manager"
    then "plasmalogin"
    else "sddm";
  greeterHome = "/var/lib/${greeterUser}";

  gamerUser = config.gaming.user;
  # The tests/test-overrides.nix path clears home-manager.users entirely;
  # guarded access keeps the stylix integration evaluable in that case.
  gamerHm = config.home-manager.users.${gamerUser} or null;

  # stylix-kde-theme: lookandfeel package, color-scheme file, wallpaper
  # package. stylix-kde-config: the immutable kdeglobals / kcminputrc the
  # KDE HM target normally feeds into the user via xdg.systemDirs.config.
  # Both are runCommandLocal derivations with stable `name` attrs.
  themePackage =
    if gamerHm == null
    then null
    else lib.findFirst (p: (p.name or "") == "stylix-kde-theme") null gamerHm.home.packages;
  configPath =
    if gamerHm == null
    then null
    else lib.findFirst (p: lib.hasInfix "stylix-kde-config" (toString p)) null gamerHm.xdg.systemDirs.config;

  ready = themePackage != null && configPath != null;
in {
  config = lib.mkIf ready {
    # System-wide install puts the lookandfeel, color-scheme, and
    # wallpaper under /run/current-system/sw/share/, where the greeter
    # can resolve them via kpackage/XDG.
    environment.systemPackages = [themePackage];

    # Seed the greeter user's plasma config. The LookAndFeelPackage=stylix
    # entry in kdeglobals is what the KDE KCM's "Apply Plasma Settings"
    # button writes here imperatively — doing it via tmpfiles keeps it
    # declarative and lets new stylix outputs roll through with
    # `nixos-rebuild switch` instead of needing the GUI.
    # L+ replaces the symlink on each rebuild so closure bumps land.
    systemd.tmpfiles.settings."10-login-greeter-stylix" = {
      ${greeterHome}.d = {
        user = greeterUser;
        group = greeterUser;
        mode = "0750";
      };
      "${greeterHome}/.config".d = {
        user = greeterUser;
        group = greeterUser;
        mode = "0750";
      };
      "${greeterHome}/.config/kdeglobals"."L+" = {
        argument = "${configPath}/kdeglobals";
        user = greeterUser;
        group = greeterUser;
      };
      "${greeterHome}/.config/kcminputrc"."L+" = {
        argument = "${configPath}/kcminputrc";
        user = greeterUser;
        group = greeterUser;
      };
    };
  };
}
