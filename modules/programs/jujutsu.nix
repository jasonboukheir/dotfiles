{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.jujutsu;
  tomlFormat = pkgs.formats.toml {};
  configFile = tomlFormat.generate "jj-config.toml" cfg.settings;
in {
  options.programs.jujutsu = {
    enable = lib.mkEnableOption "jujutsu (hand-rolled wrapper)";

    package = lib.mkPackageOption pkgs "jujutsu" {};

    settings = lib.mkOption {
      type = tomlFormat.type;
      default = {};
      example = {ui.editor = "nvim";};
      description = "Settings baked into the wrapper's JJ_CONFIG.";
    };

    wrappedPackage = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = pkgs.mkWrapped {
        pkg = cfg.package;
        name = "jj";
        env.JJ_CONFIG = configFile;
      };
      description = "The configured jj wrapper, for environment.systemPackages or `nix profile install`.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.jujutsu.settings = {
      user = {
        name = lib.mkDefault "Jason Elie Bou Kheir";
        email = lib.mkDefault "5115126+jasonboukheir@users.noreply.github.com";
      };
      ui = {
        editor = lib.mkDefault "nvim";
        merge-editor = lib.mkDefault "nvim";
        pager = lib.mkDefault "less -FRX";
        default-command = lib.mkDefault "log";
      };
      git = {
        colocate = lib.mkDefault true;
        private-commits = lib.mkDefault "description(glob:'wip:*')";
      };
    };

    environment.systemPackages = [cfg.wrappedPackage];
  };
}
