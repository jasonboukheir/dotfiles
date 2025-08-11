{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.programs.starship.enable {
    programs.starship = {
      settings = {
        add_newline = false;
        character = {
          success_symbol = "[›](bold green)";
          error_symbol = "[›](bold red)";
        };
      };
    };
  };
}
