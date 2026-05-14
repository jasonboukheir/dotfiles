{
  pkgs,
  lib,
  osConfig,
  config,
  ...
}: let
  cfg = osConfig.gaming;

  retroarchSystems = builtins.filter (s: s.type == "retroarch") cfg.systems;
  standaloneSystems = builtins.filter (s: s.type == "standalone") cfg.systems;

  # Deduplicate standalone packages by name
  uniqueStandalonePkgNames = lib.unique (map (s: s.pkg) standaloneSystems);

  retroarchPkg = config.programs.retroarch.finalPackage;

  # SRM parser generation
  mkGlobPattern = exts: "\${title}@(${lib.concatMapStringsSep "|" (e: ".${e}") exts})";

  mkParser = system: let
    isRetroarch = system.type == "retroarch";
    executablePath =
      if isRetroarch
      then "${retroarchPkg}/bin/retroarch"
      else "${pkgs.${system.pkg}}/bin/${system.bin}";
    cmdArgs =
      if isRetroarch
      then "-L ${retroarchPkg}/lib/retroarch/cores/${system.coreSo} \"\${filePath}\""
      else "\"\${filePath}\"";
  in {
    parserType = "Glob";
    configTitle = system.name;
    steamCategory = system.name;
    romDirectory = "${cfg.romDir}/${system.dir}";
    steamDirectory = "\${steamdirglobal}";
    startInDirectory = "";
    executable = {
      path = executablePath;
      shortcutPassthrough = false;
      appendArgsToExecutable = true;
    };
    commandLineArguments = cmdArgs;
    parserInputs = {
      glob = mkGlobPattern system.ext;
    };
    titleModifier = "\${fuzzyTitle}";
    onlineImageQueries = "\${title}";
    imageProviders = ["sgdb"];
    imageProviderAPIs = {
      sgdb = {
        nsfw = false;
        humor = false;
        styles = [];
        stylesHero = [];
        stylesLogo = [];
        stylesIcon = [];
        imageMotionTypes = ["static"];
      };
    };
    userAccounts = {
      specifiedAccounts = "";
    };
    disabled = false;
    drmProtect = false;
    imagePool = "\${fuzzyTitle}";
  };

  parsers = map mkParser cfg.systems;

  maliitDesktop = "${pkgs.maliit-keyboard}/share/applications/com.github.maliit.keyboard.desktop";
in {
  home.stateVersion = "25.11";

  # Force the virtual keyboard to pop on every text-input focus event, ignoring
  # KWin's "real keyboard plugged in" heuristic — without this the OSK stays
  # hidden whenever a USB keyboard is attached to the dock.
  home.sessionVariables.KWIN_IM_SHOW_ALWAYS = "1";

  # Pre-seed kwinrc so maliit is the active virtual keyboard from first login.
  # kwriteconfig6 merges into any existing file, so this is safe to re-run.
  home.activation.plasmaVirtualKeyboard = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
      --file kwinrc --group Wayland \
      --key InputMethod "${maliitDesktop}"
    run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
      --file kwinrc --group Wayland --type bool \
      --key VirtualKeyboardEnabled true
  '';

  # Auto-start Steam so Steam Input's Desktop Layout maps the paired controller
  # to mouse + keyboard — the same trick SteamOS Desktop Mode relies on.
  xdg.configFile."autostart/steam.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Steam
    Exec=steam -silent
    Icon=steam
    Terminal=false
    X-GNOME-Autostart-enabled=true
  '';

  # System-wide menu entry (auto-trusted by Plasma because it's in
  # XDG_DATA_DIRS) plus a clickable Desktop tile for one-click access.
  # steamosctl writes /etc/sddm.conf.d/zzt-steamos-temp-login.conf and stops
  # graphical-session.target; SDDM autoLogin re-fires into gamescope-wayland.
  xdg.dataFile."applications/return-to-gaming-mode.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Return to Gaming Mode
    Comment=Drop Plasma and relaunch Steam in Gaming Mode
    Exec=steamosctl switch-to-game-mode
    Icon=steam
    Terminal=false
    Categories=System;
  '';

  home.file."Desktop/return-to-gaming-mode.desktop" = {
    executable = true;
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Return to Gaming Mode
      Exec=steamosctl switch-to-game-mode
      Icon=steam
      Terminal=false
    '';
  };

  programs.retroarch = lib.mkIf (retroarchSystems != []) {
    enable = true;
    cores = lib.listToAttrs (map (s: lib.nameValuePair s.core {enable = true;}) retroarchSystems);
    settings = {
      video_driver = "vulkan";
      config_save_on_exit = "false";
    };
  };

  home.packages = lib.mkIf (cfg.systems != []) (
    (map (p: pkgs.${p}) uniqueStandalonePkgNames)
    ++ [pkgs.steam-rom-manager]
  );

  xdg.configFile."steam-rom-manager/userData/userConfigurations.json" = lib.mkIf (cfg.systems != []) {
    text = builtins.toJSON parsers;
  };
}
