{...}: {
  # ca-derivations + dynamic-derivations: brutus's vllm-xpu-nix input produces
  # content-addressed derivations, so any host running `nix flake check`
  # against the repo needs these features to evaluate brutus's toplevel.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
    "ca-derivations"
    "dynamic-derivations"
  ];
  nix.settings.trusted-users = ["jasonbk"];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  environment.variables.EDITOR = "nvim";
}
