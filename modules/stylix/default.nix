{pkgs, ...}: {
  stylix = {
    image = ./wallpapers/nord.jpg;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/nord.yaml";
    cursor = {
      name = "Capitaine Cursors (Nord)";
      package = pkgs.capitaine-cursors-themed;
      size = 18;
    };
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.fira-code;
        name = "FiraCode Nerd Font";
      };
    };
  };
}
