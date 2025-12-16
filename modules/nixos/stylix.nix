{pkgs, ...}: {
  cursor = {
    name = "Capitaine Cursors (Nord)";
    package = pkgs.capitaine-cursors-themed;
    size = 18;
  };
  icons = {
    enable = true;
    package = pkgs.nordzy-icon-theme;
    light = "Nordzy";
    dark = "Nordzy-dark";
  };
}
