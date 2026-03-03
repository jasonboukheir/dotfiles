{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.programs.brave.enable {
    programs.brave = {
      extensions = [];
    };
  };
}
