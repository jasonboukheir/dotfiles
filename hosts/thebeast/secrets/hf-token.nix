{...}: {
  age.secrets."hf/token" = {
    file = ./hf/token.age;
    owner = "jasonbk";
    mode = "0400";
  };
}
