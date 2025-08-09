{ pkgs, ... }:
{
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.jasonbk = {
    isNormalUser = true;
    description = "Jason Bou Kheir";
    extraGroups = [ "networkmanager" "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOBXQLA93+Bth7CcvuDjlu10Z03GmFg3CSLH4z+inadP"
    ];
    shell = pkgs.nushell;
  };
}
