{...}: {
  services.litellm = {
    enable = false; # need to enable postgresql later
    port = 3200;
  };
}
