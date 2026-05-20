{lib, ...}: {
  imports = [
    # Homelab module tree — settings + ports + the services framework that
    # every homelab service module piggybacks on for nginx/ACME/mtls/port
    # allocation. wellKnown rounds it out for services that publish
    # .well-known endpoints (matrix, opencloud, ...).
    ../../../modules/homelab/settings.nix
    ../../../modules/homelab/ports.nix
    ../../../modules/homelab/services.nix
    ../../../modules/homelab/wellKnown.nix

    # pocket-id provides the `services.pocket-id.ensureClients` option type
    # most homelab services reference at module-eval time for OIDC client
    # config. Importing pocket-id alone (not enabling it) keeps the option
    # lookup well-typed without booting the provisioner — which would
    # otherwise hit the real pocket-id API and never deliver the secret
    # files we stub below.
    ../../../modules/nixos/services/pocket-id
    ../../../modules/nixos/ephemeral-secrets.nix

    # Brutus's real postgres config (enable + identMap + authentication),
    # standalone with no agenix or hardware deps. Several homelab services
    # (matrix, immich, mealie, lldap, ...) connect over the local unix
    # socket; exercising the host's actual identMap catches regressions
    # that would silently break service-to-postgres peer auth.
    ../services/postgresql.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  # testers.nixosTest injects `nixpkgs.pkgs` externally and rejects further
  # config knobs; clear modules/nixpkgs's allowUnfreePredicate for tests.
  nixpkgs.config = lib.mkForce {};
  system.stateVersion = "25.05";

  homelab.enable = true;
  homelab.domain = "test.local";
  # secretsDir is a path option; most service modules read it only inside
  # `mkIf .enable` for agenix lookups. Any in-tree directory satisfies
  # the type — agenix isn't wired up in this test path.
  homelab.secretsDir = ./.;
  # smtp options are mandatory (no defaults). Stub values satisfy the
  # types; tests that exercise email-sending codepaths should override.
  homelab.smtp = {
    host = "smtp.invalid";
    from = "stub@test.local";
    username = "stub";
    passwordFile = "/dev/null";
  };
  # Several service modules read `homelab.services.id.domain` to build
  # their OIDC issuer URL. Declaring an empty submodule entry makes the
  # option resolvable without enabling pocket-id (which would need
  # agenix-backed secrets we don't carry in the test path). Tests that
  # actually exercise pocket-id can override with `enable = true;`.
  homelab.services.id = {};

  # nginx + ACME are out of scope for service-startup smoke tests (no
  # DNS-01, no certs) and the homelab service framework forces both on.
  # mkForce drops them cleanly; services that listen on 127.0.0.1 can be
  # poked directly via curl from the test driver.
  services.nginx.enable = lib.mkForce false;
  security.acme.certs = lib.mkForce {};
  # With nginx disabled the upstream module doesn't fill in nginx's
  # user/group defaults but the homelab service framework still pokes
  # `users.users.nginx.extraGroups = ["acme"]`. Provide the missing bits
  # so assertions pass — the user is otherwise unused.
  users.users.nginx = {
    isSystemUser = true;
    group = "nginx";
  };
  users.groups.nginx = {};

  # Parent directory for stubbed pocket-id client secrets. Per-service
  # tests add their own `f /run/pocket-id-secrets/<client_id>` rule to
  # stand in for what pocket-id-provisioner.service would normally write.
  systemd.tmpfiles.rules = [
    "d /run/pocket-id-secrets 0755 root root -"
  ];
}
