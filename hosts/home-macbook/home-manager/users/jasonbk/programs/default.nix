{pkgs-unstable, ...}: let
  # ssh signing values the old shared _1password home-manager module injected
  # (issue #46); git/jj still come from home-manager on this host, so the
  # wiring stays here. op-ssh-sign ships with the external /Applications app.
  signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBGEXFObvyFbGAgq3Lob/+2SPBXfFBmguTmJDLcJlysJ";
  opSshSign = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
in {
  home.packages = [
    pkgs-unstable.amp-cli
  ];
  programs = {
    brave.enable = true;
    fish.enable = true;
    nushell.enable = true;

    git.settings = {
      user.signingKey = signingKey;
      gpg.format = "ssh";
      commit.gpgsign = true;
      "gpg \"ssh\"".program = opSshSign;
    };

    jujutsu.settings.signing = {
      behavior = "own";
      backend = "ssh";
      key = signingKey;
    };
  };
}
