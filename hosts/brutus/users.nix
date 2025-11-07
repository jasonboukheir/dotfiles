{
  pkgs,
  lib,
  config,
  ...
}: {
  options = {
    jasonbk.sshKey = lib.mkOption {
      type = lib.types.str;
      default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOBXQLA93+Bth7CcvuDjlu10Z03GmFg3CSLH4z+inadP";
      description = "SSH public key for user jasonbk";
    };
  };
  config = {
    # Define a user account. Don't forget to set a password with ‘passwd’.
    users = {
      users.jasonbk = {
        isNormalUser = true;
        description = "Jason Bou Kheir";
        extraGroups = ["networkmanager" "wheel" "podman"];
        openssh.authorizedKeys.keys = [
          config.jasonbk.sshKey
        ];
        shell = pkgs.fish;
      };
    };
  };
}
