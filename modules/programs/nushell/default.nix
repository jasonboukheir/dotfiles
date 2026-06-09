{
  lib,
  pkgs,
  ...
}: let
  perUser = {config, ...}: let
    cfg = config.programs.nushell;

    starshipEnvHook = ''
      if (which starship | is-not-empty) {
        mkdir ($nu.data-dir | path join "vendor/autoload")
        ^starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")
      }
    '';

    vividEnvHook = ''
      $env.LS_COLORS = (^vivid generate ${lib.escapeShellArg cfg.vivid.theme})
    '';

    configText =
      builtins.readFile cfg.configFile
      + lib.optionalString (cfg.extraConfig != "") "\n${cfg.extraConfig}\n";

    envText =
      lib.optionalString (cfg.vivid.enable && cfg.vivid.theme != "") vividEnvHook
      + lib.optionalString cfg.starship.enable starshipEnvHook;

    configFile = pkgs.writeText "config.nu" configText;
    envFile = pkgs.writeText "env.nu" envText;
  in {
    options.programs.nushell = {
      enable = lib.mkEnableOption "nushell (hand-rolled wrapper) in this user's environment";

      package = lib.mkPackageOption pkgs "nushell" {};

      configFile = lib.mkOption {
        type = lib.types.path;
        default = ./config.nu;
        description = "Base config.nu baked into the wrapper and loaded via --config.";
      };

      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Extra nushell config appended to the baked config.nu.";
      };

      carapace.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Put carapace on the wrapper PATH; the baked config.nu external completer calls it.";
      };

      vivid = {
        enable = lib.mkEnableOption "the vivid LS_COLORS hook in the baked env.nu";
        package = lib.mkPackageOption pkgs "vivid" {};
        theme = lib.mkOption {
          type = lib.types.str;
          default = "ansi";
          example = "gruvbox-dark";
          description = ''
            vivid theme baked into env.nu as $env.LS_COLORS. Defaults to the
            `ansi` theme, which renders file types through the terminal's 16
            ANSI slots — stylix themes those from base16 (the same mapping the
            ghostty target uses), so LS_COLORS tracks the scheme without pinning
            a vivid colour theme.
          '';
        };
      };

      starship.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Emit `starship init nu` into the baked env.nu (writes to nushell's
          vendor autoload dir, guarded on starship being on PATH). The starship
          wrapper itself comes from modules/programs/starship.nix.
        '';
      };
    };

    config = lib.mkIf cfg.enable {
      packages = [
        (pkgs.mkWrapped {
          pkg = cfg.package;
          name = "nu";
          flags = ["--config" "${configFile}" "--env-config" "${envFile}"];
          extraPaths =
            lib.optional cfg.carapace.enable pkgs.carapace
            ++ lib.optional cfg.vivid.enable cfg.vivid.package;
        })
      ];
    };
  };
in {
  options.users.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule perUser);
  };
}
