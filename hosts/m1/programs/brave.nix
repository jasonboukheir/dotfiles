{ ... }:
let
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
in
{
  home-manager.users.jasonbk = {
    programs.brave = {
      enable = true;
      extensions = [
        ext."1password"
        ext.simplelogin
        ext.nord-theme
      ];
    };
  };
}
