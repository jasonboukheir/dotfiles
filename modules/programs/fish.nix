{
  config,
  lib,
  pkgs,
  ...
}: {
  # Shared by the NixOS and darwin system configs (both expose the same
  # programs.fish interface — interactiveShellInit + vendor loading). Yields to
  # my.fish when the my.* wrapper owns the system fish (modules/my/nixos.nix):
  # that wrapper bakes its own plugins + interactiveShellInit, so re-emitting
  # them here would double-load. mkDefault so per-host `programs.fish.enable =
  # true` (the macs) doesn't conflict.
  config = lib.mkIf (!(config.my.fish.enable or false)) {
    programs.fish = {
      enable = lib.mkDefault true;
      # HM used to auto-emit these on home.shell.enable*Integration. With HM gone
      # the hooks are hand-concatenated here; direnv's fish hook is emitted by the
      # native programs.direnv module. starship is a per-user wrapper, so guard on
      # it being on PATH (absent for users without the wrapper).
      interactiveShellInit = ''
        if command -q starship
          starship init fish | source
        end
      '';
    };

    # plugin-git installs into share/fish/vendor_{functions,conf}.d, which the
    # default programs.fish.vendor.* loads from the system profile.
    environment.systemPackages = [pkgs.fishPlugins.plugin-git];
  };
}
