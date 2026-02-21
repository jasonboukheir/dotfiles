{
  lib,
  osConfig,
  ...
}: let
  account = "personal";
  remoteArgs = {
    url = "https://radicale.internal.sunnycareboo.com";
    userName = "jasonbk@sunnycareboo.com";
    passwordCommand = ["cat" osConfig.age.secrets."radicale/jasonbk/password".path];
  };
  mkRemote = type:
    lib.mkMerge [
      {
        type = type;
      }
      remoteArgs
    ];
in {
  accounts.calendar.basePath = ".calendars";
  accounts.calendar.accounts."${account}" = {
    primary = true;
    primaryCollection = "def-calendar";
    remote = mkRemote "caldav";
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
  accounts.contact.accounts."${account}-contacts" = {
    remote = mkRemote "carddav";
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
