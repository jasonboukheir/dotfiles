{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.bifrost;
  credsLib = import ../../lib/credentials.nix {inherit lib;};
  credHelpers = credsLib.mkCredentialsHelpers {inherit cfg pkgs;};

  version = "1.4.22";

  src = pkgs.fetchFromGitHub {
    owner = "maximhq";
    repo = "bifrost";
    tag = "transports/v${version}";
    hash = "sha256-QTjKUDU5/f66aHKzkb/Z6N4wmLtXIWvIgeHDR9HW8Uo=";
  };

  bifrost-ui = pkgs.buildNpmPackage {
    pname = "bifrost-ui";
    inherit version src;
    sourceRoot = "source/ui";

    npmDepsHash = "sha256-aOYAxgZwCfbCrTAbYFaeNtLoKnkqXGrR1KcwWGYrBC0=";

    postPatch = ''
      cat > app/layout.tsx <<'EOF'
      import "./globals.css"

      export default function RootLayout({ children }: { children: React.ReactNode }) {
      	return (
      		<html lang="en" suppressHydrationWarning>
      			<head>
      				<link rel="dns-prefetch" href="https://getbifrost.ai" />
      				<link rel="preconnect" href="https://getbifrost.ai" />
      			</head>
      			<body className="font-sans antialiased">{children}</body>
      		</html>
      	)
      }
      EOF
    '';

    npmBuildScript = "build-enterprise";
    env.NEXT_TELEMETRY_DISABLED = "1";
    env.NEXT_DISABLE_ESLINT = "1";

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/ui"
      cp -R --no-preserve=mode,ownership,timestamps out/. "$out/ui/"
      runHook postInstall
    '';
  };

  buildGoModule =
    pkgs.callPackage "${pkgs.path}/pkgs/build-support/go/module.nix"
    {go = pkgs.go_1_26 or pkgs.go;};

  patchGoVersion = ''
    find . -name go.mod -exec ${lib.getExe pkgs.gnused} -i 's/^go 1\.26\..*/go 1.26.1/' {} +
  '';

  transportsLocalReplaces = ''
    if [ -f transports/go.mod ]; then
      cat >> transports/go.mod <<'EOF'

    replace github.com/maximhq/bifrost/core => ../core
    replace github.com/maximhq/bifrost/framework => ../framework
    replace github.com/maximhq/bifrost/plugins/governance => ../plugins/governance
    replace github.com/maximhq/bifrost/plugins/jsonparser => ../plugins/jsonparser
    replace github.com/maximhq/bifrost/plugins/litellmcompat => ../plugins/litellmcompat
    replace github.com/maximhq/bifrost/plugins/logging => ../plugins/logging
    replace github.com/maximhq/bifrost/plugins/maxim => ../plugins/maxim
    replace github.com/maximhq/bifrost/plugins/mocker => ../plugins/mocker
    replace github.com/maximhq/bifrost/plugins/otel => ../plugins/otel
    replace github.com/maximhq/bifrost/plugins/semanticcache => ../plugins/semanticcache
    replace github.com/maximhq/bifrost/plugins/telemetry => ../plugins/telemetry
    EOF
    fi
  '';

  bifrost = buildGoModule {
    pname = "bifrost-http";
    inherit version src;

    modRoot = "transports";
    subPackages = ["bifrost-http"];
    vendorHash = "sha256-U63yO447GvkrhStItBo3GSCKmRIr0o3ZgE6jvN4/Ch8=";

    doCheck = false;

    overrideModAttrs = _final: prev: {
      postPatch = (prev.postPatch or "") + patchGoVersion + transportsLocalReplaces;
    };

    env.CGO_ENABLED = "1";

    nativeBuildInputs = with pkgs; [pkg-config gcc];
    buildInputs = [pkgs.sqlite];

    postPatch = patchGoVersion + transportsLocalReplaces;

    preBuild = ''
      rm -rf bifrost-http/ui
      mkdir -p bifrost-http/ui
      if [ -d "${bifrost-ui}/ui" ]; then
        cp -R --no-preserve=mode,ownership,timestamps "${bifrost-ui}/ui/." bifrost-http/ui/
      else
        printf '%s\n' '<!doctype html><meta charset="utf-8"><title>Bifrost</title>' > bifrost-http/ui/index.html
      fi
    '';

    ldflags = ["-s" "-w" "-X main.Version=${version}"];

    meta = {
      mainProgram = "bifrost-http";
      description = "Bifrost AI gateway";
      homepage = "https://github.com/maximhq/bifrost";
      license = lib.licenses.asl20;
    };
  };

  settingsFormat = pkgs.formats.json {};
in {
  options.services.bifrost = {
    enable = lib.mkEnableOption "bifrost AI gateway";

    package = lib.mkOption {
      type = lib.types.package;
      default = bifrost;
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/bifrost";
      readOnly = true;
    };

    logLevel = lib.mkOption {
      type = lib.types.enum ["debug" "info" "warn" "error"];
      default = "info";
    };

    logStyle = lib.mkOption {
      type = lib.types.enum ["json" "pretty"];
      default = "json";
    };

    settings = lib.mkOption {
      type = lib.types.nullOr settingsFormat.type;
      default = null;
    };

    credentials = credsLib.mkCredentialsOption {};

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.bifrost = let
      configFile =
        if cfg.settings == null
        then null
        else settingsFormat.generate "bifrost-config.json" cfg.settings;
    in {
      description = "Bifrost AI gateway";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      environment = cfg.environment;

      preStart = lib.optionalString (configFile != null) ''
        install -Dm600 "${configFile}" "${cfg.stateDir}/config.json"
      '';

      serviceConfig = {
        LoadCredential = credHelpers.loadList;
        ExecStart = pkgs.writeShellScript "bifrost-start" ''
          ${credHelpers.exportScript}
          exec ${lib.getExe cfg.package} \
            -host ${cfg.host} \
            -port ${toString cfg.port} \
            -app-dir ${cfg.stateDir} \
            -log-level ${cfg.logLevel} \
            -log-style ${cfg.logStyle} \
            ${lib.escapeShellArgs cfg.extraArgs}
        '';
        WorkingDirectory = cfg.stateDir;
        StateDirectory = "bifrost";
        DynamicUser = true;
        PrivateTmp = true;
        DevicePolicy = "closed";
        LockPersonality = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
        UMask = "0077";
        RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
        ProtectClock = true;
        ProtectProc = "invisible";
      };
    };
  };
}
