{...}: {
  services.openssh = {
    enable = true;
    ports = [22];
    settings = {
      UseDns = true;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}
