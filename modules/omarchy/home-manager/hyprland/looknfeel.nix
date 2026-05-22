{...}: {
  wayland.windowManager.hyprland.settings = {
    config = {
      general = {
        gaps_in = 5;
        gaps_out = 10;

        border_size = 2;

        resize_on_border = false;

        allow_tearing = false;

        layout = "dwindle";
      };

      decoration = {
        rounding = 4;

        shadow = {
          enabled = false;
          range = 30;
          render_power = 3;
        };

        blur = {
          enabled = true;
          size = 5;
          passes = 2;

          vibrancy = 0.1696;
        };
      };

      animations = {
        enabled = true; # yes, please :)
      };

      dwindle = {
        preserve_split = true;
        force_split = 2;
      };

      master = {
        new_status = "master";
      };

      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
      };
    };

    curve = [
      {_args = ["easeOutQuint" {type = "bezier"; points = [[0.23 1] [0.32 1]];}];}
      {_args = ["easeInOutCubic" {type = "bezier"; points = [[0.65 0.05] [0.36 1]];}];}
      {_args = ["linear" {type = "bezier"; points = [[0 0] [1 1]];}];}
      {_args = ["almostLinear" {type = "bezier"; points = [[0.5 0.5] [0.75 1.0]];}];}
      {_args = ["quick" {type = "bezier"; points = [[0.15 0] [0.1 1]];}];}
    ];

    animation = [
      {leaf = "global"; enabled = true; speed = 10; curve = "default";}
      {leaf = "border"; enabled = true; speed = 5.39; curve = "easeOutQuint";}
      {leaf = "windows"; enabled = true; speed = 4.79; curve = "easeOutQuint";}
      {leaf = "windowsIn"; enabled = true; speed = 4.1; curve = "easeOutQuint"; style = "popin 87%";}
      {leaf = "windowsOut"; enabled = true; speed = 1.49; curve = "linear"; style = "popin 87%";}
      {leaf = "fadeIn"; enabled = true; speed = 1.73; curve = "almostLinear";}
      {leaf = "fadeOut"; enabled = true; speed = 1.46; curve = "almostLinear";}
      {leaf = "fade"; enabled = true; speed = 3.03; curve = "quick";}
      {leaf = "layers"; enabled = true; speed = 3.81; curve = "easeOutQuint";}
      {leaf = "layersIn"; enabled = true; speed = 4; curve = "easeOutQuint"; style = "fade";}
      {leaf = "layersOut"; enabled = true; speed = 1.5; curve = "linear"; style = "fade";}
      {leaf = "fadeLayersIn"; enabled = true; speed = 1.79; curve = "almostLinear";}
      {leaf = "fadeLayersOut"; enabled = true; speed = 1.39; curve = "almostLinear";}
      {leaf = "workspaces"; enabled = false; speed = 0; curve = "ease";}
    ];
  };
}
