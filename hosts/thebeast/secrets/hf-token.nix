{config, ...}: let
  home = config.users.users.jasonbk.home;
in {
  age.secrets."hf/token" = {
    file = ./hf/token.age;
    owner = "jasonbk";
    mode = "0400";
  };

  # huggingface CLIs expect a plain token file at ~/.cache/huggingface/token;
  # point it at the agenix-decrypted secret (out of home-manager, #50). ':' =
  # apply mode/owner only on creation, leaving existing user dirs untouched.
  systemd.tmpfiles.rules = [
    "d '${home}/.cache' :0700 :jasonbk :users -"
    "d '${home}/.cache/huggingface' :0700 :jasonbk :users -"
    "L+ '${home}/.cache/huggingface/token' - - - - ${config.age.secrets."hf/token".path}"
  ];
}
