{pkgs, ...}: {
  stylix = {
    base16Scheme = "${pkgs.base16-schemes}/share/themes/nord.yaml";
    # image = ./judgement.jpg;
    # base16Scheme = ./orthodox-dark.yaml;
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.fira-code;
        name = "FiraCode Nerd Font";
      };
    };
  };
}
