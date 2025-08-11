{ options, ... }:
{
  services.nginx = {
    enable = true;
    virtualHosts."sunnycareboo.com" = {
      addSsl = true;
      enableAcme = true;
    };
  };
  security.acme.acceptTerms = true;
  security.acme.defaults.email = "cloudflare.8un28@simplelogin.com";
  security.acme.certs."sunnycareboo.com" = {
    domain = "*.sunnycareboo.com";
    dnsProvider = "cloudflare";
    environmentFile = "/var/lib/secrets/certs.secret";
  };
}
