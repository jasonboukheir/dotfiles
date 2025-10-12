{...}: {
  services.nextcloud = {
    enable = true;
    hostName = "cloud.sunnycareboo.com";
    https = true;
    database = {
      createLocally = true;
    };
    config = {
      adminpassFile = "/var/lib/secrets/nextcloud-admin-pass";
      dbtype = "pgsql";
    };
  };
}
