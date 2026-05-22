{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.thebeast;

  # Per-user → semicolon-separated session basenames. Empty list ==
  # "show all sessions" — Main.qml's rebuildFilter() reads this key
  # via SDDM's `config` QML object (theme.conf).
  renderSessionLine = user: sessions: "sessions_${user}=${lib.concatStringsSep ";" sessions}";

  themeConf = pkgs.writeText "thebeast-sddm-theme.conf" ''
    [General]
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList renderSessionLine cfg.sessionsByUser)}
  '';

  themePkg = pkgs.runCommandLocal "sddm-theme-thebeast" {
    passthru.themeName = "thebeast";
  } ''
    install -Dm0644 ${./sddm-theme/Main.qml}          $out/share/sddm/themes/thebeast/Main.qml
    install -Dm0644 ${./sddm-theme/metadata.desktop}  $out/share/sddm/themes/thebeast/metadata.desktop
    install -Dm0644 ${themeConf}                      $out/share/sddm/themes/thebeast/theme.conf
  '';
in {
  config = lib.mkIf (cfg.displayManager == "sddm") {
    # Theme name must be reachable from SDDM's theme search path
    # (/run/current-system/sw/share/sddm/themes/<name>). NixOS' sddm
    # module composes that path from extraPackages; environment.systemPackages
    # mirrors it for consistency with the wiki recipe.
    services.displayManager.sddm.theme = themePkg.themeName;
    services.displayManager.sddm.extraPackages = [themePkg];
    environment.systemPackages = [themePkg];
  };
}
