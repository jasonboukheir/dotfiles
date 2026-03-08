{pkgs, ...}: {
  stylix = {
    cursor = {
      name = "Capitaine Cursors";
      package = pkgs.capitaine-cursors-themed;
      size = 18;
    };
  };
}
