{ ... }:
{
  security.acme.acceptTerms = true;
  security.acme.defaults.email = "admin+acme@example.com";
  security.acme.certs."sunnycareboo.com" = {
    domain = "*.sunnycareboo.com";
    dnsProvider = "cloudflare";
    environmentFile = "/var/lib/secrets/certs.secret";
  };
}
