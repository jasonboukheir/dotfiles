{ ... }:
{
  home.file = {
    ".config/zed" = {
      source = ./zed;
      recursive = true;
    };
  };
}
