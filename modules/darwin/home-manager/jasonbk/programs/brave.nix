{
  config,
  lib,
  ...
}: let
  ext = {
    nord-theme = {
      id = "dhlnjfhjjbminbjbegeiijdakdkamjoi";
    };
  };
in {
  config = lib.mkIf config.programs.brave.enable {
    programs.brave = {
      extensions = [
        ext."1password"
      ];
    };
  };
}
