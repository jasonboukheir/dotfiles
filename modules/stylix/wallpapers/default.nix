{pkgs}: let
  shareToken = "uaQZueGUltCCVCp";
  base = "https://cloud.sunnycareboo.com/remote.php/dav/public-files/${shareToken}";
  wp = filename: hash:
    pkgs.fetchurl {
      url = "${base}/${filename}";
      name = filename;
      inherit hash;
    };
in {
  analog-dreams = wp "analog-dreams.jpeg" "sha256-+RSndkpdXNHgSVAZ+fmWr8+WphtDLdDJfcVoBjLG/bI=";
  nord = wp "nord.jpg" "sha256-1YcJBxa9m7D4oFp/pzXAshqOsNssUwLXjrgvTDeoZFY=";
  tree-of-life = wp "tree-of-life.jpg" "sha256-kNytAJoaqzUGhZ2ooGVyxx2+IYSWsIVl20qW5TnJjSE=";
  vaporwave-cocktail-square = wp "vaporwave-cocktail-square.jpg" "sha256-/CitSuUFlhaQySuS2jDK+5B1ZAXCkYQBtLGoqcGFyas=";
  vaporwave-dolphins = wp "vaporwave-dolphins.jpg" "sha256-9ql79OUI32BcyEOl09vk02AmXTH1GdKdg6bXariY+Kg=";
  vaporwave-neon-nightscape = wp "vaporwave-neon-nightscape.jpeg" "sha256-xrC0vHpSVEcBpA0uaeFt2vnSm7FV/b+g5w3r/sEJwNo=";
}
