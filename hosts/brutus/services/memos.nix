{
  config,
  lib,
  pkgs-unstable,
  ...
}: let
  cfg = config.services.memos;
in {
  services.memos = {
    enable = true;
    package = pkgs-unstable.memos;
  };

  sunnycareboo.services.memos = lib.mkIf cfg.enable {
    enable = true;
    proxyPass = "http://localhost:${cfg.settings.MEMOS_PORT}";
  };
}
