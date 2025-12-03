{lib, ...}: {
  omarchy = {
    full_name = "Jason Elie Bou Kheir";
    email_address = "5115126+jasonboukheir@users.noreply.github.com";
    theme = "nord";
  };

  services.greetd.enable = lib.mkForce false;
}
