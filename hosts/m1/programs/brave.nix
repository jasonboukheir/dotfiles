{ pkgs, ... }:
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
    home.packages = [ pkgs.brave ];
    # home.file = {
    #   ".config/BraveSoftware" = {
    #     source = "./brave";
    #     recursive = true;
    #   };
    # };
    programs.chromium = {
      enable = true;
      package = pkgs.brave;
      extensions = [
        ext."1password"
        ext.simplelogin
        ext.nord-theme
      ];
    };
  };
}

# { ... }:
# {
#   homebrew.casks = [ "brave-browser" ];
# }
