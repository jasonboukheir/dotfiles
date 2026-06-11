{
  config,
  osConfig,
  ...
}: {
  home.stateVersion = "25.11";
  imports = [
    ./programs
  ];

  home.file.".cache/huggingface/token".source =
    config.lib.file.mkOutOfStoreSymlink osConfig.age.secrets."hf/token".path;
}
