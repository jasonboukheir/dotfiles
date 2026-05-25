{
  config,
  lib,
  pkgs,
  ...
}: let
  yamlFormat = pkgs.formats.yaml {};
  # TODO: drop the sed once pkgs.formats.yaml emits integer YAML keys for
  # numeric-named Nix attrs. It currently round-trips through JSON, which
  # stringifies every key, and LACT's BTreeMap<i32, f32> fan curve rejects
  # quoted keys. See pkgs/pkgs-lib/formats.nix in nixpkgs (yaml_1_1).
  lactConfig = pkgs.runCommand "lact-config.yaml" {} ''
    sed -E "s/'([0-9]+)':/\1:/g" ${yamlFormat.generate "lact-config-raw.yaml" config.services.lact.settings} > $out
  '';
in {
  hardware.amdgpu.initrd.enable = true;
  hardware.amdgpu.overdrive.enable = true;

  services.lact = {
    enable = true;
    settings = {
      # pin schema version to skip startup migration; the config file is a
      # read-only /nix/store symlink, so a migration save would fail with EROFS.
      # bump in lockstep with lact's CURRENT_VERSION on package upgrades.
      version = 5;
      daemon = {
        log_level = "info";
        # socket is chowned to this group; without it the daemon falls back to
        # its own gid (root) and non-root users get EACCES connecting.
        admin_group = "wheel";
      };
      gpus."1002:7550-1DA2:E490-0000:03:00.0" = {
        power_cap = 304.0;
        voltage_offset = -20;
        fan_control_enabled = true;
        fan_control_settings = {
          mode = "curve";
          temperature_key = "edge";
          interval_ms = 500;
          curve = {
            "30" = 0.30;
            "40" = 0.50;
            "55" = 0.70;
            "65" = 0.90;
            "75" = 1.00;
          };
        };
      };
    };
  };

  environment.etc."lact/config.yaml".source = lib.mkForce lactConfig;
  systemd.services.lactd.restartTriggers = lib.mkForce [lactConfig];

  services.xserver = {
    enable = true;
    videoDrivers = ["amdgpu" "modesetting"];
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
