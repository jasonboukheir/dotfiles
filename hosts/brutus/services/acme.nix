{config, ...}: {
  age.secrets."acme/env" = {
    file = ../secrets/acme/env.age;
  };

  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "postmaster@sunnycareboo.com";
      dnsProvider = "cloudflare";
      environmentFile = config.age.secrets."acme/env".path;
    };
  };
}
