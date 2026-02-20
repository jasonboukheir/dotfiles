{osConfig, ...}: let
  url = "https://radicale.internal.sunnycareboo.com";
  user = "jasonbk@sunnycareboo.com";
  account = "personal";
  passwordCommand = ["cat" osConfig.age.secrets."radicale/jasonbk/password".path];
in {
  accounts.calendar.basePath = ".calendars";
  accounts.calendar.accounts."${account}" = {
    primary = true;
    remote = {
      type = "caldav";
      url = url;
      userName = user;
      passwordCommand = passwordCommand;
    };
    khal = {
      enable = true;
      type = "discover";
    };
    pimsync = {
      enable = true;
      extraPairDirectives = [
        {
          name = "collections";
          params = [
            "all"
          ];
        }
      ];
    };
  };
  accounts.contact.basePath = ".contacts";
  accounts.contact.accounts."${account}" = {
    remote = {
      type = "carddav";
      url = url;
      userName = user;
      passwordCommand = passwordCommand;
    };
    khal.enable = true;
    khard = {
      type = "discover";
      enable = true;
    };
    pimsync = {
      enable = true;
      extraPairDirectives = [
        {
          name = "collections";
          params = [
            "all"
          ];
        }
      ];
    };
  };
}
