{...}: {
  systemd.tmpfiles.settings = {
    "10-media" = {
      "/mnt/media".d = {
        mode = "0775";
        user = "root";
        group = "media";
      };
      "/mnt/media/movies".d = {
        mode = "0775";
        user = "root";
        group = "media";
      };
      # Add more subdirs similarly
    };
  };
}
