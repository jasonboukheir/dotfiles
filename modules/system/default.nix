{ inputs, pkgs, ... }:
{
  imports = [ ./home-manager.nix ];

  environment.systemPackages = with pkgs; [
    nixd
    nixfmt-rfc-style
  ];

  services.nix-daemon.enable = true;
  nix.settings.experimental-features = "nix-command flakes";
  programs.zsh.enable = true;
  nixpkgs.config.allowUnfree = true;

  users.users.jasonbk = {
    home = "/Users/jasonbk";
    shell = pkgs.zsh;
  };

  system = {
    stateVersion = 4;
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
  };
}
