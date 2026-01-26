{lib}: {
  # 1. Option Generator: Creates the `credentials` option
  mkCredentialsOption = {
    description ? null,
    default ? {},
  }:
    lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      inherit default;
      description =
        if description != null
        then description
        else ''
          Environment variables which are loaded from the contents of the specified file paths.
          This can be used to securely store tokens and secrets outside of the world-readable Nix store.
        '';
    };

  # 2. Implementation Helpers: Generates the systemd config values
  # usage: inherit (mkCredentialsHelpers { inherit pkgs cfg; }) loadList exportScript;
  mkCredentialsHelpers = {
    cfg,
    pkgs,
  }: {
    # Returns the list for serviceConfig.LoadCredential
    loadList = lib.mapAttrsToList (n: v: "${n}_FILE:${v}") cfg.credentials;

    # Returns the shell script snippet to export variables
    exportScript = let
      exportCmd = n: _: ''export ${n}="$(${lib.getBin pkgs.systemd}/bin/systemd-creds cat ${n}_FILE)"'';
    in
      lib.concatStringsSep "\n" (lib.mapAttrsToList exportCmd cfg.credentials);
  };
}
