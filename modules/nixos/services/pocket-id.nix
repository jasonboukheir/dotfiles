# backport of unstable credentials files to 25.11
{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit
    (lib)
    getExe
    mkIf
    mkOption
    ;
  inherit
    (lib.types)
    attrsOf
    path
    ;
  cfg = config.services.pocket-id;

  exportCredentials = n: _: ''export ${n}="$(${pkgs.systemd}/bin/systemd-creds cat ${n}_FILE)"'';
  exportAllCredentials = vars: lib.concatStringsSep "\n" (lib.mapAttrsToList exportCredentials vars);
  getLoadCredentialList = lib.mapAttrsToList (n: v: "${n}_FILE:${v}") cfg.credentials;
in {
  options.services.pocket-id = {
    credentials = mkOption {
      type = attrsOf path;
      default = {};
      example = {
        ENCRYPTION_KEY = "/run/secrets/pocket-id/encryption-key";
      };
      description = ''
        Environment variables which are loaded from the contents of the specified file paths.
        This can be used to securely store tokens and secrets outside of the world-readable Nix store.

        See [PocketID environment variables](https://pocket-id.org/docs/configuration/environment-variables).

        Alternatively you can use `services.pocket-id.environmentFile` to define all the variables in a single file.
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.services = {
      pocket-id.serviceConfig = {
        ExecStart = lib.mkForce (pkgs.writeShellScript "pocket-id-start" ''
          ${exportAllCredentials cfg.credentials}
          ${getExe cfg.package}
        '');
        LoadCredential = getLoadCredentialList;
      };
    };
  };
}
