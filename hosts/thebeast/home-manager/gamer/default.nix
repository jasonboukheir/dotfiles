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
in {
  home.stateVersion = "25.11";

  stylix.cursor = {
    inherit (osConfig.stylix.cursor) name package;
    size = 12;
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
