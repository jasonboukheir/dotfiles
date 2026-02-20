{...}: let
  url = "https://radicale.internal.sunnycareboo.com";
  user = "jasonbk";
  account = "personal";
  passwordCommand = ["op" "item" "get" "tbzwwt5biofc66lx27pmcvunuq" "--reveal" "--fields" "password"];
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
    vdirsyncer = {
      conflictResolution = "remote wins";
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
    vdirsyncer = {
      conflictResolution = "remote wins";
    };
  };
  programs.todoman.enable = true;
}
