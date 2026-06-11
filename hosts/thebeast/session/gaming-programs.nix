# gamer's emulation stack as per-user my.* wrappers (#49), replacing the old
# home-manager programs.retroarch + xdg.configFile SRM config: retroarch is
# wrapped with the cores + settings below, and SRM's parser list is generated
# from gaming.systems and seeded on first launch (seed-and-accept — SRM owns
# its userData afterwards).
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.gaming;

  retroarchSystems = builtins.filter (s: s.type == "retroarch") cfg.systems;
  standalonePkgNames = lib.unique (map (s: s.pkg) (builtins.filter (s: s.type == "standalone") cfg.systems));
in {
  users.users.${cfg.user} = lib.mkIf (cfg.systems != []) {
    my.retroarch = {
      enable = true;
      cores = lib.unique (map (s: s.core) retroarchSystems);
      settings = {
        video_driver = "vulkan";
        config_save_on_exit = false;
      };
    };

    my.steam-rom-manager = {
      enable = true;
      romDir = cfg.romDir;
      systems = cfg.systems;
      retroarchPackage = config.users.users.${cfg.user}.my.retroarch.finalPackage;
    };

    # Standalone emulators on gamer's profile so they're launchable outside
    # the SRM-generated Steam shortcuts (which embed absolute store paths).
    packages = map (p: pkgs.${p}) standalonePkgNames;
  };
}
