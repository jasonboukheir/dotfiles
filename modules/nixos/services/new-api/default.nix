{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.new-api;
  credsLib = import ../../lib/credentials.nix {inherit lib;};
  credHelpers = credsLib.mkCredentialsHelpers {inherit cfg pkgs;};

  version = "0.12.8";

  src = pkgs.fetchFromGitHub {
    owner = "QuantumNous";
    repo = "new-api";
    tag = "v${version}";
    hash = "sha256-JXxnnAJ9tVkKAJ1tLK7OOYwgyqEna1zIfELVmP+Gc6M=";
  };

  webDist = pkgs.stdenv.mkDerivation {
    pname = "new-api-web";
    inherit version src;

    nativeBuildInputs = with pkgs; [bun nodejs cacert];

    buildPhase = ''
      cd web
      bun install --frozen-lockfile
      patchShebangs node_modules
      DISABLE_ESLINT_PLUGIN=true bun run build
    '';

    installPhase = ''
      cp -r dist $out
    '';

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "sha256-e/O0qjx87NFbGrcAeOv8xAAuiepUYdBdICMDFnApgv8=";
  };

  new-api = pkgs.buildGoModule {
    pname = "new-api";
    inherit version src;

    vendorHash = "sha256-NXaMB7dKpQJ707Yu5a4WCOugVWVZpbjYLKVJZYmepsc=";

    doCheck = false;

    preBuild = ''
      cp -r ${webDist} web/dist
    '';

    ldflags = ["-s" "-w"];

    meta = {
      description = "OpenAI API management & distribution system";
      homepage = "https://github.com/QuantumNous/new-api";
      mainProgram = "new-api";
    };
  };
in {
  options.services.new-api = {
    enable = lib.mkEnableOption "new-api LLM gateway";

    package = lib.mkOption {
      type = lib.types.package;
      default = new-api;
      description = "The new-api package to use.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3200;
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/new-api";
      readOnly = true;
    };

    credentials = credsLib.mkCredentialsOption {};

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
    };
  };

  config = lib.mkIf cfg.enable {
    ephemeral-secrets.new-api-session = {};

    services.new-api.credentials = {
      SESSION_SECRET = config.ephemeral-secrets.new-api-session.path;
    };

    systemd.services.new-api = {
      description = "new-api LLM gateway";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      environment = cfg.environment;

      serviceConfig = {
        ExecStartPre = pkgs.writeShellScript "new-api-gen-secrets" ''
          if [ ! -f ${cfg.stateDir}/crypto-secret ]; then
            ${lib.getExe' pkgs.openssl "openssl"} rand -base64 32 > ${cfg.stateDir}/crypto-secret
            chmod 600 ${cfg.stateDir}/crypto-secret
          fi
        '';
        LoadCredential = credHelpers.loadList;
        ExecStart = pkgs.writeShellScript "new-api-start" ''
          ${credHelpers.exportScript}
          export CRYPTO_SECRET="$(cat ${cfg.stateDir}/crypto-secret)"
          exec ${lib.getExe cfg.package} --port ${toString cfg.port} --log-dir ${cfg.stateDir}/logs
        '';
        WorkingDirectory = cfg.stateDir;
        StateDirectory = "new-api";
        DynamicUser = true;
      };
    };
  };
}
