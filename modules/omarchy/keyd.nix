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
          leftmeta = "layer(cmd)";
          rightmeta = "layer(cmd)";
        };
        extraConfig = ''
          ${capsLockMapping}

          [cmd]
          a = C-a
          c = C-c
          v = C-v
          x = C-x
          z = C-z
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
          1 = C-1
          2 = C-2
          3 = C-3
          4 = C-4
          5 = C-5
          6 = C-6
          7 = C-7
          8 = C-8
          9 = C-9
          left = home
          right = end
          up = C-home
          down = C-end
          backspace = C-backspace
          space = M-space

          [cmd+shift]
          4 = print
          5 = f13
          z = C-S-z
          c = C-S-c
          v = C-S-v
          left = S-home
          right = S-end
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
