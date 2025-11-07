{
  config,
  lib,
  ...
}: let
  ext = {
    "1password" = {
      id = "aeblfdkhhhdcdjpifhhbdiojplfjncoa";
    };
    simplelogin = {
      id = "dphilobhebphkdjbpfohgikllaljmgbn";
    };
    nord-theme = {
      id = "dhlnjfhjjbminbjbegeiijdakdkamjoi";
    };
  };
in {
  config = lib.mkIf config.programs.brave.enable {
    programs.brave = {
      extensions = [
        ext."1password"
        ext.simplelogin
        ext.nord-theme
      ];
    };
  };
}
