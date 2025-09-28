{pkgs, ...}: {
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users = {
    users.jasonbk = {
      isNormalUser = true;
      description = "Jason Bou Kheir";
      extraGroups = ["wheel"];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEfZvYFG59uHZI+qyuVEyeL6A7GWanxbRbQkQG7q9SWy"
      ];
      shell = pkgs.fish;
    };
  };
}
