{pkgs, ...}:
# Eval-only importability guard for the litus use case: a host imports the
# homelab settings layer (`modules/homelab`) purely to reference settings —
# domain, ports, the service registry and its computed domains — WITHOUT
# hosting anything and WITHOUT the service-provider flake inputs (ezmtls,
# nixarr, vllm-xpu-nix, ...) that the hosting host carries. The settings
# layer must therefore evaluate against plain nixpkgs alone: if an
# implementation module ever leaked back into it, evaluating the toplevel
# would reference an undeclared option (e.g. `services.ezmtls`) and the
# build below would fail at eval time.
#
# CLAUDE.md prefers VM tests for behavioural assumptions, but importability
# is a pure-evaluation property (nothing to observe at runtime), so an eval
# check is the right tool — it finishes in seconds instead of building and
# booting a VM.
let
  eval = import (pkgs.path + "/nixos/lib/eval-config.nix") {
    inherit pkgs;
    system = null;
    modules = [
      ../../../modules/homelab
      {
        # Minimal stubs so `toplevel` evaluates — we only care that the
        # module tree resolves, not that the result is bootable.
        boot.loader.grub.enable = false;
        fileSystems."/" = {
          device = "/dev/disk/by-label/nixos";
          fsType = "ext4";
        };
        system.stateVersion = "25.05";
      }
    ];
  };
in
  pkgs.runCommand "litus-homelab-import" {} ''
    # Forcing the toplevel drvPath string forces evaluation of the whole
    # settings-layer module tree; it only resolves if that tree evaluated
    # against bare nixpkgs with no service-provider inputs.
    echo ${eval.config.system.build.toplevel.drvPath} > $out
  ''
