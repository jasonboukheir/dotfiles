{config, ...}: {
  age.secrets."cloudflare/token" = {
    file = ../secrets/cloudflare/token.age;
    owner = "nginx";
    group = "nginx";
  };
  sunnycareboo.enable = true;
}
