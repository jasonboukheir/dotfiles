{
  config,
  lib,
  ...
}: let
  cfg = config.services.blocky;
in {
  services.blocky = {
    enable = true;
    settings = {
      ports = {
        dns = 53;
        http = 1501;
      };
      upstreams.groups.default = [
        "https://one.one.one.one/dns-query"
      ];
      bootstrapDns = {
        upstream = "https://one.one.one.one/dns-query";
        ips = ["1.1.1.1" "1.0.0.1"];
      };
      blocking = {
        blackLists = {
          ads = [
            "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
            "https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/hosts/pro.txt"
          ];
          adult = ["https://blocklistproject.github.io/Lists/porn.txt"];
        };
        clientGroupsBlock = {
          default = ["ads" "adult"];
        };
      };
    };
  };

  sunnycareboo.services.blocky = lib.mkIf cfg.enable {
    enable = true;
    proxyPass = "http://localhost:${toString cfg.settings.ports.http}";
  };
}
