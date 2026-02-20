let
  root = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGH7Eh42LCt0Qe6oKJJgiY34nv/eG3F1hbsmkSOJPUL/";
  allKeys = [root];

  files = [
    "radicale/jasonbk/password.age"
  ];
in
  builtins.listToAttrs (map (file: {
      name = file;
      value = {
        armor = true;
        publicKeys = allKeys;
      };
    })
    files)
