{
  pkgs,
  nixgl,
  config,
  lib,
  inputs,
  ...
}: let
  nixGLWrap = pkg: let
    wrapped = config.lib.nixGL.wrap pkg;
    # TODO(home-manager#8395): drop once nix-community/home-manager#8396 is
    # backported to release-25.11. The upstream `lib.nixGL.wrap` only rewrites
    # `share/applications/*.desktop`. GTK apps with `DBusActivatable=true`
    # (Ghostty, Helium) are launched by GNOME via their systemd user unit, which
    # still points at the unwrapped binary — so the app starts without
    # nixGL's GL/EGL env and fails to find an OpenGL context. Patch the
    # systemd + d-bus service files too, mirroring upstream PR #8396.
    rewriteDirs = ["share/dbus-1/services" "share/systemd/user"];
  in
    pkgs.symlinkJoin {
      name = "${pkg.pname or pkg.name}-nixgl-desktop";
      paths = [wrapped];
      meta = (pkg.meta or {}) // {mainProgram = pkg.meta.mainProgram or pkg.pname or pkg.name;};
      # Keep .override propagating through the wrapper — modules that pass
      # tunables via cfg.package.override (e.g. oxcl's programs.helium.flags)
      # otherwise hit "attribute 'override' missing" on the symlinkJoin.
      passthru = (pkg.passthru or {}) // {override = args: nixGLWrap (pkg.override args);};
      postBuild = ''
        if [ -d ${pkg}/share/applications ]; then
          rm -rf $out/share/applications
          mkdir -p $out/share/applications
          for f in ${pkg}/share/applications/*.desktop; do
            substitute "$f" "$out/share/applications/$(basename "$f")" \
              --replace-fail "${pkg}/bin" "${wrapped}/bin"
          done
        fi
        for d in ${lib.escapeShellArgs rewriteDirs}; do
          if [ -d "${pkg}/$d" ]; then
            rm -rf "$out/$d"
            mkdir -p "$out/$d"
            for f in "${pkg}/$d"/*; do
              [ -e "$f" ] || continue
              substitute "$f" "$out/$d/$(basename "$f")" \
                --replace-quiet "${pkg}/bin" "${wrapped}/bin"
            done
          fi
        done
      '';
    };
in {
  imports = [
    ../../modules/home-manager/sharedModules/programs
    ../../modules/home-manager/jasonbk/programs
    ../../modules/stylix
    ./programs
    inputs.helium-flake.homeModules.default
  ];

  stylix.enable = true;

  fonts.fontconfig.enable = true;

  targets.genericLinux.enable = true;
  targets.genericLinux.nixGL.packages = nixgl;

  programs.ghostty.package = nixGLWrap pkgs.ghostty;
  programs.helium.package = nixGLWrap pkgs.helium;
  programs._1password.package = config.lib.nixGL.wrap pkgs._1password-gui;

  xdg.systemDirs.config = ["/etc/xdg"];

  home = {
    username = "jasonbk";
    homeDirectory = "/home/jasonbk";
    stateVersion = "25.11";
    packages = with pkgs; [
      fd
      ripgrep
      ripgrep-all
    ];
    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };
}
