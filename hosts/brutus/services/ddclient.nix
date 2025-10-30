{...}: {
  services.ddclient = {
    enable = true;
    domains = ["vpn.sunnycareboo.com"];
    protocol = "cloudflare";
    zone = "sunnycareboo.com";

    username = "token"; # This gets mapped to login option: https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/networking/ddclient.nix#L20
    passwordFile = "/var/lib/secrets/ddclient-token";

    # Other options (defaults are fine for basic setup)
    ssl = true; # Use HTTPS (required for Cloudflare API)
    quiet = true; # Set to true to suppress non-update logs
    verbose = false; # Set to true for debug logs
    interval = "10min"; # How often to check/update (systemd.time format)

    # Optional: Extra config lines (appended verbatim to ddclient.conf)
    # extraConfig = ''
    #   ttl=300  # Set custom TTL for the A record (in seconds)
    # '';
  };
}
