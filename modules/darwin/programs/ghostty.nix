{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.home-manager.users.jasonbk.programs.ghostty.enable {
    homebrew.casks = ["ghostty"];
  };
}
