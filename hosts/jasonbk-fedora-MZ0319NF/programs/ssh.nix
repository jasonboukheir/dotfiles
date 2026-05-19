{
  config,
  lib,
  ...
}: {
  programs.ssh.enable = true;

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
