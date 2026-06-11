# Standalone-HM host: no system /etc/ssh layer, so the shared client config
# (modules/ssh/client-config.nix) is seeded as a real ~/.ssh/config file.
# home.file only registers the path; the activation hook below materializes it
# with the mode ssh's safe_path check demands (issue #46; the full
# managed-files story for standalone hosts is issue #39).
{
  config,
  lib,
  ...
}: {
  home.file.".ssh/config".text = import ../../../modules/ssh/client-config.nix {
    inherit lib;
    identityAgent = "~/.1password/agent.sock";
  };

  # Fedora's OpenSSH rejects ~/.ssh/config when it resolves into /nix/store
  # (group-writable store dir trips safe_path). Materialize it as a real
  # 0600 file owned by the user after home-manager links its tree.
  # TODO: drop once https://github.com/nix-community/home-manager/issues/322 lands a fix.
  home.activation.sshConfigCopy = lib.hm.dag.entryAfter ["linkGeneration"] ''
    src="${config.home.homeDirectory}/.ssh/config"
    if [ -L "$src" ]; then
      real=$(readlink -f "$src")
      rm "$src"
      install -m 600 "$real" "$src"
    fi
  '';
}
