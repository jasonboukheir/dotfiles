{
  config,
  lib,
  ...
}: let
  homelabCfg = config.homelab.services.git;
  domain = config.homelab.services.git.domain;
  rootUrl = "https://${domain}/";
  port = config.homelab.ports.values.forgejo;
  # Forgejo stores OAuth2 login sources as DB rows (not app.ini), so the
  # Pocket ID *source* is reconciled by the forgejo-oauth oneshot below via
  # the admin CLI. This name is both the source name and the idempotency
  # key. The first user to log in through it becomes the site admin (the
  # local admin in the epic).
  oauthSourceName = "pocket-id";
  cfg = config.services.forgejo;
  oidcCfg = config.services.pocket-id.ensureClients.forgejo;

  # Fetch the OIDC discovery document over Pocket ID's loopback listener
  # rather than its public URL. The endpoints and issuer in the document are
  # derived from Pocket ID's APP_URL, so browser redirects and ID-token
  # validation still use the public URL — only this one-time registration
  # fetch goes over loopback. That keeps forgejo-oauth from depending on the
  # nginx/ACME TLS stack being up at boot.
  discoveryUrl = "http://127.0.0.1:${toString config.homelab.ports.values.pocket-id}/.well-known/openid-configuration";
in {
  config = lib.mkMerge [
    {
      homelab.services.git = {
        proxyPass = "http://localhost:${toString port}";
        # git pushes and LFS uploads can be arbitrarily large; lift nginx's
        # default 1M body cap and give slow clones/pushes room before the
        # proxy times out.
        proxyReadTimeout = "3600s";
        extraConfig = ''
          client_max_body_size 0;
        '';
      };
    }
    (lib.mkIf homelabCfg.enable {
      homelab.ports.allocate.forgejo = 3000;

      services.forgejo = {
        enable = true;

        database = {
          type = "postgres";
          # Local peer/socket auth: db user == system user "forgejo", so no
          # password secret is needed (hosts/brutus/services/postgresql.nix).
          createDatabase = true;
        };

        lfs.enable = true;

        # SECRET_KEY/INTERNAL_TOKEN/JWT_SECRET/LFS_JWT_SECRET are generated
        # and persisted by the upstream forgejo-secrets.service, so nothing
        # sensitive lands in app.ini or the nix store. No agenix secret is
        # required for Phase 1 (peer auth covers the database).

        settings = {
          server = {
            HTTP_ADDR = "127.0.0.1";
            HTTP_PORT = port;
            DOMAIN = domain;
            ROOT_URL = rootUrl;
            # Reuse the host's OpenSSH for git-over-ssh instead of Forgejo's
            # built-in server; advertise the public host/port in clone URLs.
            START_SSH_SERVER = false;
            SSH_DOMAIN = domain;
            SSH_PORT = lib.head config.services.openssh.ports;
          };

          service = {
            # Accounts are provisioned via Pocket ID (OIDC), never the public
            # signup form. ALLOW_ONLY_EXTERNAL_REGISTRATION keeps OIDC
            # auto-registration working while the form stays closed.
            DISABLE_REGISTRATION = true;
            ALLOW_ONLY_EXTERNAL_REGISTRATION = true;
            SHOW_REGISTRATION_BUTTON = false;
          };

          session.COOKIE_SECURE = true;
        };
      };

      # Reconcile the Pocket ID OAuth2 login source into Forgejo's DB. The
      # admin CLI talks to postgres directly and fetches the discovery
      # document at registration time, so this needs the schema migrated
      # (forgejo.service) and Pocket ID serving the discovery endpoint
      # (pocket-id.service + the provisioner, which has already registered
      # the client and written its secret). dependentServices below makes
      # pocket-id-provisioner run before — and be required by — this unit.
      systemd.services.forgejo-oauth = {
        description = "Reconcile the Pocket ID OAuth2 login source in Forgejo";
        after = ["forgejo.service" "pocket-id.service"];
        requires = ["forgejo.service"];
        wants = ["pocket-id.service"];
        wantedBy = ["multi-user.target"];
        path = [cfg.package];

        environment = {
          USER = cfg.user;
          HOME = cfg.stateDir;
          FORGEJO_WORK_DIR = cfg.stateDir;
          FORGEJO_CUSTOM = cfg.customDir;
        };

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = cfg.user;
          Group = cfg.group;
          WorkingDirectory = cfg.stateDir;
          LoadCredential = ["oidc_secret:${oidcCfg.secretFile}"];
        };

        script = ''
          secret="$(cat "$CREDENTIALS_DIRECTORY/oidc_secret")"

          # `auth list` columns are: ID  Name  Type  Enabled. Re-running with
          # an existing source updates it in place (e.g. secret rotation),
          # otherwise add a new one. Either subcommand re-fetches discovery.
          source_id="$(forgejo admin auth list | awk -v name='${oauthSourceName}' '$2 == name { print $1 }')"
          if [ -n "$source_id" ]; then
            set -- update-oauth --id "$source_id"
          else
            set -- add-oauth --name '${oauthSourceName}'
          fi

          # add/update-oauth fetches the discovery document and fails
          # atomically (nothing persisted) if Pocket ID isn't answering yet,
          # so retrying the whole call is safe. Covers the brief warm-up
          # window after the provisioner returns rather than failing boot.
          for attempt in $(seq 1 12); do
            if forgejo admin auth "$@" \
              --provider openidConnect \
              --key '${oidcCfg.settings.id}' \
              --secret "$secret" \
              --auto-discover-url '${discoveryUrl}' \
              --scopes openid --scopes email --scopes profile; then
              exit 0
            fi
            echo "forgejo-oauth: attempt $attempt failed, retrying in 5s" >&2
            sleep 5
          done
          echo "forgejo-oauth: gave up after repeated discovery failures" >&2
          exit 1
        '';
      };

      services.pocket-id.ensureClients.forgejo = {
        logo = ./forgejo.svg;
        # Gate forgejo-oauth on the client existing in Pocket ID and its
        # secret file being written (the provisioner runs before and is
        # required by every dependent service).
        dependentServices = [config.systemd.services.forgejo-oauth.name];
        settings = {
          name = "Forgejo";
          launchURL = rootUrl;
          callbackURLs = [
            "${rootUrl}user/oauth2/${oauthSourceName}/callback"
          ];
        };
      };
    })
  ];
}
