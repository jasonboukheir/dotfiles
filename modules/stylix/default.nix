{
  config,
  options,
  lib,
  pkgs,
  ...
}: let
  cfg = config.stylix;
  wallpapers = import ./wallpapers {inherit pkgs;};
in {
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      stylix = {
        image = wallpapers.vaporwave-neon-nightscape;
        # base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
        base16Scheme = ./themes/digital-nightmares.yaml;
        polarity = "dark";
        opacity.terminal = 0.97;
        fonts = {
          monospace = {
            package = pkgs.nerd-fonts.fira-code;
            name = "FiraCode Nerd Font";
          };
        };
        targets = {
          nvf.plugin = "mini-base16";
        };
      };
    }

    # TODO: drop once stylix migrates its kmscon target off the removed
    # services.kmscon.{fonts,extraConfig} options. The target sets them
    # unconditionally, so nixos-unstable's mkRemovedOptionModule stubs fail
    # the build even though kmscon is never enabled. Guarded on the target
    # existing so darwin hosts (no kmscon service) still evaluate.
    # https://github.com/nix-community/stylix/issues/2334
    (lib.optionalAttrs (options.stylix.targets ? kmscon) {
      stylix.targets.kmscon.enable = false;
    })
  ]);
}
