{...}: {
  age.secrets."radicale/jasonbk/password" = {
    file = ./radicale/jasonbk/password.age;
    owner = "jasonbk";
    mode = "0400";
  };
}
