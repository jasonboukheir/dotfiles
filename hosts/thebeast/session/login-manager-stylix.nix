{
  config,
  lib,
  ...
}: let
  dmCfg = config.thebeast;
  usePlm = dmCfg.displayManager == "plasma-login-manager";

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

  ready = usePlm && themePackage != null && configPath != null;
in {
  config = lib.mkIf ready {
    # System-wide install puts the lookandfeel, color-scheme, and
    # wallpaper under /run/current-system/sw/share/, where the greeter's
    # plasma session can resolve them via kpackage/XDG.
    environment.systemPackages = [themePackage];

    # Seed the plasmalogin greeter user's plasma config. The
    # LookAndFeelPackage=stylix entry in kdeglobals is what the KDE KCM's
    # "Apply Plasma Settings" button writes here imperatively — doing it
    # via tmpfiles keeps it declarative and lets new stylix outputs roll
    # through with `nixos-rebuild switch` instead of needing the GUI.
    # L+ replaces the symlink on each rebuild so closure bumps land.
    systemd.tmpfiles.settings."10-plasmalogin-stylix" = {
      "/var/lib/plasmalogin".d = {
        user = "plasmalogin";
        group = "plasmalogin";
        mode = "0750";
      };
      "/var/lib/plasmalogin/.config".d = {
        user = "plasmalogin";
        group = "plasmalogin";
        mode = "0750";
      };
      "/var/lib/plasmalogin/.config/kdeglobals"."L+" = {
        argument = "${configPath}/kdeglobals";
        user = "plasmalogin";
        group = "plasmalogin";
      };
      "/var/lib/plasmalogin/.config/kcminputrc"."L+" = {
        argument = "${configPath}/kcminputrc";
        user = "plasmalogin";
        group = "plasmalogin";
      };
    };
  };
}
