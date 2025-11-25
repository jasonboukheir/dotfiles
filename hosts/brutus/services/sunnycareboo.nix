{config, ...}: {
  age.secrets."acme/env" = {
    file = ../secrets/acme/env.age;
  };
  sunnycareboo.enable = true;
}
