# { pkgs, ... }:
# let
#   ext = {
#     "1password" = {
#       id = "aeblfdkhhhdcdjpifhhbdiojplfjncoa";
#     };
#   };
# in
# {
#   home-manager.users.jasonbk = {
#     home.packages = [ pkgs.brave ];
#     # home.file = {
#     #   ".config/BraveSoftware" = {
#     #     source = "./brave";
#     #     recursive = true;
#     #   };
#     # };
#     programs.chromium = {
#       enable = true;
#       package = pkgs.brave;
#       extensions = [
#         ext."1password"
#       ];
#     };
#   };
# }
