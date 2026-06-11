{
  lib,
  pkgs,
}: let
  jsonFormat = pkgs.formats.json {};

  systemModule = {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        example = "SNES";
        description = "Display name; becomes the parser title and Steam category.";
      };

      type = lib.mkOption {
        type = lib.types.enum ["retroarch" "standalone"];
        description = "Whether the parser launches retroarch with a core or a standalone emulator.";
      };

      core = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "snes9x";
        description = "libretro core name (pkgs.libretro attribute); unused here but carried so gaming.systems entries pass through verbatim.";
      };

      coreSo = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "snes9x_libretro.so";
        description = "Core filename under retroarchPackage's lib/retroarch/cores, passed to retroarch via -L.";
      };

      pkg = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "dolphin-emu";
        description = "nixpkgs attribute of the standalone emulator.";
      };

      bin = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "dolphin-emu";
        description = "Binary name under the standalone emulator's bin/.";
      };

      dir = lib.mkOption {
        type = lib.types.str;
        example = "snes";
        description = "ROM subdirectory under romDir.";
      };

      ext = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        example = ["sfc" "smc" "zip"];
        description = "ROM file extensions matched by the parser glob.";
      };
    };
  };
in {
  name = "steam-rom-manager";
  defaultPackage = "steam-rom-manager";

  options = {
    romDir = lib.mkOption {
      type = lib.types.str;
      default = "/games/roms";
      description = "Base ROM directory; each system parses romDir/<system.dir>.";
    };

    retroarchPackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      example = lib.literalExpression "config.users.users.gamer.my.retroarch.finalPackage";
      description = ''
        retroarch wrapper whose bin/retroarch and lib/retroarch/cores back the
        retroarch-type parsers. Required when `systems` has retroarch entries.
      '';
    };

    systems = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule systemModule);
      default = [];
      description = ''
        Emulation systems rendered into SRM parser configurations
        (userConfigurations.json), one Glob parser per system. Shaped to accept
        `config.gaming.systems` entries verbatim.
      '';
    };
  };

  assertions = {cfg, ...}: [
    {
      assertion = cfg.retroarchPackage != null || lib.all (s: s.type != "retroarch") cfg.systems;
      message = "my.steam-rom-manager: `systems` has retroarch entries, so `retroarchPackage` must be set (e.g. to a my.retroarch finalPackage).";
    }
  ];

  build = {
    cfg,
    pkgs,
    lib,
    ...
  }: let
    retroarchPkg =
      assert lib.assertMsg (cfg.retroarchPackage != null)
      "my.steam-rom-manager: `systems` has retroarch entries, so `retroarchPackage` must be set (e.g. to a my.retroarch finalPackage).";
        cfg.retroarchPackage;

    mkGlobPattern = exts: "\${title}@(${lib.concatMapStringsSep "|" (e: ".${e}") exts})";

    mkParser = system: let
      isRetroarch = system.type == "retroarch";
      hasRequiredFields =
        if isRetroarch
        then
          lib.assertMsg (system.coreSo != null)
          "my.steam-rom-manager: retroarch system ${system.name} needs `coreSo`."
        else
          lib.assertMsg (system.pkg != null && system.bin != null)
          "my.steam-rom-manager: standalone system ${system.name} needs `pkg` and `bin`.";
      executablePath =
        if isRetroarch
        then "${retroarchPkg}/bin/retroarch"
        else "${pkgs.${system.pkg}}/bin/${system.bin}";
      cmdArgs =
        if isRetroarch
        then "-L ${retroarchPkg}/lib/retroarch/cores/${system.coreSo} \"\${filePath}\""
        else "\"\${filePath}\"";
    in
      assert hasRequiredFields; {
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

    seedFile = jsonFormat.generate "userConfigurations.json" (map mkParser cfg.systems);

    # SRM rewrites its own userData at runtime, so the generated parser config
    # is seed-and-accept: installed only when missing, then owned by SRM —
    # never an immutable store symlink it would fail to write back.
    seedUserConfigurations = ''
      srm_userdata="''${XDG_CONFIG_HOME:-$HOME/.config}/steam-rom-manager/userData"
      if [ ! -e "$srm_userdata/userConfigurations.json" ]; then
        mkdir -p "$srm_userdata"
        install -m 644 ${seedFile} "$srm_userdata/userConfigurations.json"
      fi
    '';
  in
    pkgs.mkWrapped {
      pkg = cfg.package;
      name = "steam-rom-manager";
      run = lib.optional (cfg.systems != []) seedUserConfigurations;
    };
}
