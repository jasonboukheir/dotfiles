{config, ...}: {
  age.secrets."libation/AccountsSettings.json" = {
    file = ../secrets/libation/AccountsSettings.json.age;
    owner = config.services.libation.user;
    group = config.services.libation.group;
    mode = "0600";
  };

  # Uncomment if you have a custom Settings.json
  # age.secrets."libation/Settings.json" = {
  #   file = ../secrets/libation/Settings.json.age;
  #   owner = config.services.libation.user;
  #   group = config.services.libation.group;
  #   mode = "0600";
  # };

  services.libation = {
    enable = true;
    accountsSettingsFile = config.age.secrets."libation/AccountsSettings.json".path;
    # settingsFile = config.age.secrets."libation/Settings.json".path;
  };
}
