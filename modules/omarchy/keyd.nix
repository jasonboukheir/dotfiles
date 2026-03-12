{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.omarchy;

  capsLockMapping = lib.optionalString cfg.macKeybindings.capsLockAsCmd ''
    capslock = leftmeta
  '';
in {
  config = lib.mkIf (cfg.enable && cfg.macKeybindings.enable) {
    services.keyd = {
      enable = true;
      keyboards.default = {
        ids = ["*"];
        settings.main = {
          leftalt = "layer(cmd)";
          rightalt = "layer(cmd)";
        };
        extraConfig = ''
          ${capsLockMapping}

          [cmd]
          a = C-a
          c = C-c
          v = C-v
          x = C-x
          z = C-z
          shift.z = C-S-z
          s = C-s
          f = C-f
          w = C-w
          t = C-t
          q = C-q
          n = C-n
          l = C-l
          r = C-r
          p = C-p
          b = C-b
          k = C-k
          left = home
          right = end
          shift.left = S-home
          shift.right = S-end
          up = C-home
          down = C-end
          backspace = C-backspace
        '';
      };
    };

    environment.etc."libinput/local-overrides.quirks".text = ''
      [Serial Keyboards]
      MatchUdevType=keyboard
      MatchName=keyd virtual keyboard
      AttrKeyboardIntegration=internal
    '';
  };
}
