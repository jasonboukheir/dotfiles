{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.nixarr;

  services = lib.filterAttrs (n: _: cfg.${n}.enable) {
    sonarr = cfg.sonarr.port;
    radarr = cfg.radarr.port;
    lidarr = cfg.lidarr.port;
    prowlarr = cfg.prowlarr.port;
  };

  keyPath = svc: "/var/lib/nixarr/.state/nixarr/api-keys/${svc}.key";

  mkWrapper = svc: port:
    pkgs.writeShellApplication {
      name = "${svc}-api";
      runtimeInputs = with pkgs; [coreutils curl];
      text = ''
        if [ $# -lt 1 ]; then
          echo "usage: ${svc}-api <path> [curl-args...]" >&2
          echo "  example: ${svc}-api /api/v3/system/status" >&2
          exit 64
        fi
        path="$1"
        shift
        key=$(cat ${keyPath svc})
        exec curl -sS --fail-with-body \
          -H "X-Api-Key: $key" \
          -H 'Accept: application/json' \
          "$@" \
          "http://127.0.0.1:${toString port}$path"
      '';
    };
in {
  environment.systemPackages = lib.mapAttrsToList mkWrapper services;

  users.users.jasonbk.extraGroups =
    lib.mapAttrsToList (svc: _: "${svc}-api") services;
}
